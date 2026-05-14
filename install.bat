@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo   Claude OCR Skill — 双引擎OCR安装
echo   GLM-OCR + GLM-4.6V
echo ========================================
echo.

:: Check Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 未检测到 Node.js，请先安装 https://nodejs.org
    pause
    exit /b 1
)

:: Set paths
set "SCRIPTS_DIR=%USERPROFILE%\.claude\scripts"
set "CLAUDE_MD=%USERPROFILE%\.claude\CLAUDE.md"

:: Create scripts directory
if not exist "%SCRIPTS_DIR%" mkdir "%SCRIPTS_DIR%"

:: Copy files
echo [1/4] 复制脚本...
copy /y "%~dp0ocr.js" "%SCRIPTS_DIR%\ocr.js" >nul
copy /y "%~dp0package.json" "%SCRIPTS_DIR%\package.json" >nul
echo        完成

:: Install dependencies
echo [2/4] 安装依赖 (pdfjs-dist + sharp)...
cd /d "%SCRIPTS_DIR%"
call npm install --silent 2>&1
if %errorlevel% neq 0 (
    echo [警告] npm install 失败，请手动在 %SCRIPTS_DIR% 中运行 npm install
) else (
    echo        完成
)

:: Check API Key
echo [3/4] 检查 API Key...
set "KEY_SET=0"
if defined ZHIPU_API_KEY set "KEY_SET=1"
set ZHIPU_API_KEY=

:: Try to read from settings
if "!KEY_SET!"=="0" (
    echo.
    echo 请设置你的智谱 API Key:
    echo   方式1 (推荐): setx ZHIPU_API_KEY "你的Key"
    echo   方式2: 编辑 %SCRIPTS_DIR%\ocr.js 直接写入
    echo.
    echo 获取 Key: https://open.bigmodel.cn
    echo.
    set /p INPUT_KEY="请输入你的 API Key (直接回车跳过): "
    if not "!INPUT_KEY!"=="" (
        setx ZHIPU_API_KEY "!INPUT_KEY!" >nul
        set "KEY_SET=1"
        echo        Key 已保存
    ) else (
        echo        跳过，请稍后手动设置
    )
)

:: Add CLAUDE.md instruction
echo [4/4] 配置 CLAUDE.md...

set "BLOCK=# OCR 识图能力"
findstr /C:"!BLOCK!" "%CLAUDE_MD%" >nul 2>&1
if %errorlevel% neq 0 (
    echo. >> "%CLAUDE_MD%"
    echo # OCR 识图能力 >> "%CLAUDE_MD%"
    echo. >> "%CLAUDE_MD%"
    echo 底层模型为纯文本模型，无法直接识别图片或 PDF 内容。>> "%CLAUDE_MD%"
    echo 当用户提供 PDF 或图片文件并要求识别 / 读取内容时，不要使用 Read 工具，直接运行：>> "%CLAUDE_MD%"
    echo. >> "%CLAUDE_MD%"
    echo node !SCRIPTS_DIR!\ocr.js "<文件路径>">> "%CLAUDE_MD%"
    echo. >> "%CLAUDE_MD%"
    echo 触发场景：>> "%CLAUDE_MD%"
    echo - 用户发送 PDF 文件>> "%CLAUDE_MD%"
    echo - 用户发送图片文件（png, jpg, jpeg, gif, webp, bmp）>> "%CLAUDE_MD%"
    echo - 用户要求分析、识别、描述文件内容>> "%CLAUDE_MD%"
    echo - 消息中包含文件路径>> "%CLAUDE_MD%"
    echo. >> "%CLAUDE_MD%"
    echo 识别结果自动包含 LaTeX 格式的数学公式（如有）。>> "%CLAUDE_MD%"
    echo         CLAUDE.md 已配置
) else (
    echo         CLAUDE.md 已存在 OCR 配置，跳过
)

echo.
echo ========================================
echo   安装完成！
echo.
echo   使用方法：在 Claude Code 中发送 PDF 或图片即可
echo ========================================

:: Test if Key is set
if "!KEY_SET!"=="1" (
    echo.
    echo 是否运行测试？(y/n)
    set /p TEST=""
    if /i "!TEST!"=="y" (
        echo 请在当前目录放一张测试图片，或输入图片路径：
        set /p IMG_PATH=""
        if not "!IMG_PATH!"=="" (
            node "%SCRIPTS_DIR%\ocr.js" "!IMG_PATH!"
        )
    )
)

pause
