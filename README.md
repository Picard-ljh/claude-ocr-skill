# Claude OCR Skill

给 Claude Code 添加 OCR 识图能力。基于智谱 GLM-OCR + GLM-4.6V 双引擎：

- **引擎1 GLM-OCR**：精准提取文字、数学公式（自动转 LaTeX）、表格（自动转 HTML）
- **引擎2 GLM-4.6V**：理解图表/插图/数据可视化的含义

支持 PDF 和图片文件（PNG / JPG / GIF / WebP / BMP）。

---

## 安装（推荐 ⭐）

**只需把仓库链接发给 Claude Code，它会自动完成全部部署：**

> 帮我装这个：https://github.com/Picard-ljh/claude-ocr-skill

Claude Code 会自己 clone 仓库、安装依赖、配置 CLAUDE.md、问你要智谱 API Key、并跑测试验证。

你只需要提前准备好智谱 API Key（[免费注册获取](https://open.bigmodel.cn)，GLM-OCR 仅 ¥0.2/百万 tokens）。

---

## 手动安装

如果上面的方式不行，可以手动操作：

### Windows

1. 下载本仓库，双击 `install.bat`
2. 输入你的智谱 API Key
3. 完成

### Mac / Linux

```bash
cd claude-ocr-skill && bash install.sh
```

### 纯命令

```bash
mkdir -p ~/.claude/scripts
cp ocr.js package.json ~/.claude/scripts/
cd ~/.claude/scripts && npm install
export ZHIPU_API_KEY="你的智谱APIKey"

# 追加到 ~/.claude/CLAUDE.md（如未配置）
cat >> ~/.claude/CLAUDE.md << 'EOF'

# OCR 识图能力

底层模型为纯文本模型，无法直接识别图片或 PDF 内容。
当用户提供 PDF 或图片文件并要求识别 / 读取内容时，不要使用 Read 工具，直接运行：

node ~/.claude/scripts/ocr.js "<文件路径>"

触发场景：
- 用户发送 PDF 文件
- 用户发送图片文件（png, jpg, jpeg, gif, webp, bmp）
- 用户要求分析、识别、描述文件内容
- 消息中包含文件路径

识别结果自动包含 LaTeX 格式的数学公式（如有）。
EOF
```

---

## 使用

在 Claude Code 中，直接发送 PDF 或图片即可，AI 会自动调用 OCR 识别。

---

## 费用

| 引擎 | 模型 | 单价 | 单次约 |
|------|------|------|--------|
| 文字/公式/表格 | GLM-OCR | ¥0.2 / 百万 tokens | < ¥0.001 |
| 图表理解 | GLM-4.6V | ¥1 输入 / ¥3 输出 | < ¥0.01 |

识别一篇 20 页论文约 ¥0.13。

---

## 故障排除

| 问题 | 解决 |
|------|------|
| `ZHIPU_API_KEY` 未设置 | 设置环境变量或直接修改 ocr.js |
| `pdfjs-dist` 加载失败 | 确认 `npm install` 成功完成 |
| 图表识别结果为空 | 检查智谱账户余额；确认图片格式为 PNG/JPG |
| 公式识别不准 | 这是 GLM-OCR 的基准限制（~93%），目前智谱体系内已是最佳 |

---

## License

MIT
