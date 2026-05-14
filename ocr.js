const fs = require("fs");
const path = require("path");
const https = require("https");

const API_KEY = process.env.ZHIPU_API_KEY || "";
const API_HOST = "open.bigmodel.cn";

const VISION_PROMPT =
  "请详细描述这张图片中的所有图表、数据可视化、插图、流程图的内容及含义。" +
  "包括：折线图的趋势变化、柱状图的数值对比、饼图的占比分布、散点图的相关性等。" +
  "不要重复提取文字和公式，只描述视觉元素。";

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

function usage() {
  console.error("用法: node ocr.js <文件路径>");
  process.exit(1);
}

function getMimeType(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const map = {
    ".pdf": "application/pdf",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".bmp": "image/bmp",
  };
  return map[ext] || "image/png";
}

function isImage(filePath) {
  return [".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp"].includes(
    path.extname(filePath).toLowerCase()
  );
}

function isPdf(filePath) {
  return path.extname(filePath).toLowerCase() === ".pdf";
}

function toDataUrl(filePath) {
  const buffer = fs.readFileSync(filePath);
  const mime = getMimeType(filePath);
  return `data:${mime};base64,${buffer.toString("base64")}`;
}

// ---------------------------------------------------------------------------
// HTTP
// ---------------------------------------------------------------------------

function httpsPost(apiPath, body) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(body);
    const req = https.request(
      {
        hostname: API_HOST,
        path: apiPath,
        method: "POST",
        headers: {
          Authorization: `Bearer ${API_KEY}`,
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(payload),
        },
      },
      (res) => {
        let chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => {
          try {
            resolve(JSON.parse(Buffer.concat(chunks).toString("utf-8")));
          } catch {
            resolve(null);
          }
        });
      }
    );
    req.on("error", (e) => reject(e));
    req.write(payload);
    req.end();
  });
}

async function callGlmOcr(dataUrl) {
  return httpsPost("/api/paas/v4/layout_parsing", {
    model: "glm-ocr",
    file: dataUrl,
  });
}

async function callGlmVision(dataUrl) {
  return httpsPost("/api/paas/v4/chat/completions", {
    model: "glm-4.6v",
    messages: [
      {
        role: "user",
        content: [
          { type: "image_url", image_url: { url: dataUrl } },
          { type: "text", text: VISION_PROMPT },
        ],
      },
    ],
  });
}

function extractOcrText(result) {
  if (result.md_results) return result.md_results;
  if (result.raw) return result.raw;
  return JSON.stringify(result, null, 2);
}

function extractVisionText(result) {
  if (result && result.choices && result.choices[0] && result.choices[0].message) {
    return result.choices[0].message.content;
  }
  return null;
}

function getPagesWithImages(ocrText) {
  const pages = new Set();
  for (const m of ocrText.matchAll(/!\[\]\(page=(\d+),bbox=\[/g)) {
    pages.add(parseInt(m[1]));
  }
  return pages;
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

async function main() {
  if (!API_KEY) {
    console.error("请设置环境变量 ZHIPU_API_KEY，获取地址: https://open.bigmodel.cn");
    process.exit(1);
  }

  const filePath = process.argv[2];
  if (!filePath) usage();

  const absPath = path.resolve(filePath);
  if (!fs.existsSync(absPath)) {
    console.error(`文件不存在: ${absPath}`);
    process.exit(1);
  }

  const stats = fs.statSync(absPath);
  const sizeMB = (stats.size / 1024 / 1024).toFixed(1);
  const filename = path.basename(absPath);

  console.error(`[ocr] 正在处理: ${filename} (${sizeMB} MB)`);
  console.error("[ocr] 引擎1 GLM-OCR: 提取文字/公式/表格...");

  // ---- Step 1: GLM-OCR ----
  const dataUrl = toDataUrl(absPath);
  const ocrResult = await callGlmOcr(dataUrl);
  const ocrText = extractOcrText(ocrResult);

  // ---- Step 2: Visual understanding ----
  let chartSection = "";

  if (isImage(absPath)) {
    console.error("[ocr] 引擎2 GLM-4.6V: 理解图表/插图...");
    try {
      const vis = await callGlmVision(dataUrl);
      const visText = extractVisionText(vis);
      if (visText) {
        chartSection = "\n---\n## 图表/插图说明\n" + visText;
      }
    } catch (e) {
      console.error(`[ocr] GLM-4.6V 调用失败: ${e.message}`);
    }
  } else if (isPdf(absPath)) {
    let pdfjsLib;
    try {
      pdfjsLib = await import("pdfjs-dist/legacy/build/pdf.mjs");
    } catch {
      console.error("[ocr] pdfjs-dist 未安装，跳过图表理解");
    }

    if (pdfjsLib) {
      try {
        const sharp = require("sharp");
        const pagesWithImages = getPagesWithImages(ocrText);

        if (pagesWithImages.size > 0) {
          console.error(
            `[ocr] 引擎2 GLM-4.6V: 检测到 ${pagesWithImages.size} 页含图表，提取中...`
          );

          const pdfData = new Uint8Array(fs.readFileSync(absPath));
          const doc = await pdfjsLib.getDocument({ data: pdfData }).promise;
          const descriptions = [];

          for (let i = 1; i <= doc.numPages; i++) {
            if (!pagesWithImages.has(i - 1)) continue;

            const page = await doc.getPage(i);
            const opList = await page.getOperatorList();

            const imgNames = [];
            for (let j = 0; j < opList.fnArray.length; j++) {
              if (opList.fnArray[j] === 85) {
                imgNames.push(opList.argsArray[j][0]);
              }
            }

            if (imgNames.length === 0) {
              console.error(`[ocr]   第 ${i} 页：无嵌入图片，跳过`);
              continue;
            }

            for (const name of imgNames) {
              try {
                const img = await page.objs.get(name);
                if (!img || !img.data || img.data.length < 1000) continue;

                const channels = img.kind === 3 ? 4 : img.kind === 1 ? 1 : 3;
                const pngBuf = await sharp(Buffer.from(img.data), {
                  raw: { width: img.width, height: img.height, channels },
                }).png().toBuffer();

                console.error(
                  `[ocr]   第 ${i} 页 / ${name}: ${img.width}x${img.height}, ${(pngBuf.length/1024).toFixed(0)}KB → 分析中...`
                );

                const imgDataUrl = `data:image/png;base64,${pngBuf.toString("base64")}`;

                try {
                  const vis = await callGlmVision(imgDataUrl);
                  const visText = extractVisionText(vis);
                  if (visText) {
                    const preview = visText.slice(0, 60).replace(/\n/g, " ");
                    console.error(`[ocr]     ✓ ${preview}...`);
                    descriptions.push(`**第 ${i} 页 (${name})：**\n${visText}`);
                  } else {
                    console.error(`[ocr]     ✗ 模型返回为空`);
                  }
                } catch (e2) {
                  console.error(`[ocr]     ✗ ${e2.message}`);
                  descriptions.push(`**第 ${i} 页 (${name})：**\n（描述失败: ${e2.message}）`);
                }
              } catch (e3) {
                console.error(`[ocr]   提取 ${name} 失败: ${e3.message}`);
              }
            }
          }

          if (descriptions.length > 0) {
            chartSection =
              "\n---\n## 图表/插图说明\n\n" + descriptions.join("\n\n");
          }
        } else {
          console.error("[ocr] 引擎2 GLM-4.6V: 未检测到图表，跳过");
        }
      } catch (e) {
        console.error(`[ocr] PDF 图表分析失败: ${e.message}，仅保留文字/公式结果`);
      }
    }
  }

  // ---- Step 3: Output ----
  console.log(ocrText);
  if (chartSection) console.log(chartSection);
}

main().catch((err) => {
  console.error(`[ocr] 错误: ${err.message}`);
  process.exit(1);
});
