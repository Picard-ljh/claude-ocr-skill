#!/bin/bash
set -e

echo "========================================"
echo "  Claude OCR Skill — 双引擎OCR安装"
echo "  GLM-OCR + GLM-4.6V"
echo "========================================"
echo

# Check Node.js
if ! command -v node &>/dev/null; then
    echo "[错误] 未检测到 Node.js，请先安装 https://nodejs.org"
    exit 1
fi

SCRIPTS_DIR="$HOME/.claude/scripts"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Create scripts directory
mkdir -p "$SCRIPTS_DIR"

# Copy files
echo "[1/4] 复制脚本..."
cp "$SCRIPT_DIR/ocr.js" "$SCRIPTS_DIR/ocr.js"
cp "$SCRIPT_DIR/package.json" "$SCRIPTS_DIR/package.json"
echo "       完成"

# Install dependencies
echo "[2/4] 安装依赖 (pdfjs-dist + sharp)..."
cd "$SCRIPTS_DIR"
npm install --silent 2>&1 || echo "[警告] npm install 失败，请手动在 $SCRIPTS_DIR 中运行 npm install"
echo "       完成"

# Check API Key
echo "[3/4] 检查 API Key..."
if [ -z "$ZHIPU_API_KEY" ]; then
    echo
    echo "请设置你的智谱 API Key:"
    echo "  export ZHIPU_API_KEY=\"你的Key\"  (临时)"
    echo "  或写入 ~/.bashrc / ~/.zshrc 永久生效"
    echo
    echo "获取 Key: https://open.bigmodel.cn"
    echo
    read -p "请输入你的 API Key (直接回车跳过): " INPUT_KEY
    if [ -n "$INPUT_KEY" ]; then
        export ZHIPU_API_KEY="$INPUT_KEY"
        # Append to shell profile
        if [ -f "$HOME/.bashrc" ]; then
            echo "export ZHIPU_API_KEY=\"$INPUT_KEY\"" >> "$HOME/.bashrc"
        fi
        if [ -f "$HOME/.zshrc" ]; then
            echo "export ZHIPU_API_KEY=\"$INPUT_KEY\"" >> "$HOME/.zshrc"
        fi
        echo "       Key 已保存到 ~/.bashrc / ~/.zshrc"
    else
        echo "       跳过，请稍后手动设置"
    fi
else
    echo "       已检测到 ZHIPU_API_KEY"
fi

# Add CLAUDE.md instruction
echo "[4/4] 配置 CLAUDE.md..."

BLOCK="# OCR 识图能力"
if ! grep -qF "$BLOCK" "$CLAUDE_MD" 2>/dev/null; then
    echo >> "$CLAUDE_MD"
    echo "# OCR 识图能力" >> "$CLAUDE_MD"
    echo >> "$CLAUDE_MD"
    echo "底层模型为纯文本模型，无法直接识别图片或 PDF 内容。" >> "$CLAUDE_MD"
    echo "当用户提供 PDF 或图片文件并要求识别 / 读取内容时，不要使用 Read 工具，直接运行：" >> "$CLAUDE_MD"
    echo >> "$CLAUDE_MD"
    echo "node ${SCRIPTS_DIR}/ocr.js \"<文件路径>\"" >> "$CLAUDE_MD"
    echo >> "$CLAUDE_MD"
    echo "触发场景：" >> "$CLAUDE_MD"
    echo "- 用户发送 PDF 文件" >> "$CLAUDE_MD"
    echo "- 用户发送图片文件（png, jpg, jpeg, gif, webp, bmp）" >> "$CLAUDE_MD"
    echo "- 用户要求分析、识别、描述文件内容" >> "$CLAUDE_MD"
    echo "- 消息中包含文件路径" >> "$CLAUDE_MD"
    echo >> "$CLAUDE_MD"
    echo "识别结果自动包含 LaTeX 格式的数学公式（如有）。" >> "$CLAUDE_MD"
    echo "       CLAUDE.md 已配置"
else
    echo "       CLAUDE.md 已存在 OCR 配置，跳过"
fi

echo
echo "========================================"
echo "  安装完成！"
echo
echo "  使用方法：在 Claude Code 中发送 PDF 或图片即可"
echo "========================================"

# Test
if [ -n "$ZHIPU_API_KEY" ]; then
    echo
    read -p "是否运行测试？(y/n) " TEST
    if [ "$TEST" = "y" ]; then
        read -p "请输入测试图片路径: " IMG_PATH
        if [ -n "$IMG_PATH" ]; then
            node "$SCRIPTS_DIR/ocr.js" "$IMG_PATH"
        fi
    fi
fi
