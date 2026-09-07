#!/bin/bash
# dsh 一键安装器（macOS）
# 作用：检查/安装 Node.js -> 下载鲸鱼娘图标 -> 生成桌面 dsh.app -> 启动 dsh
# 如果双击被拦截：右键本文件 -> 打开；或先执行 chmod +x install-macos.command

set -u

# 鲸鱼娘图标地址（按顺序尝试；你也可以把第一个换成自己的图片直链）
# 图标许可证：CC BY-NC-SA 4.0（署名-非商业性使用-相同方式共享），仅限非商业使用
ICON_URLS=(
  "https://cdn.jsdelivr.net/gh/fornarwhal/deepseek-whale-girl-icon@main/improved-1.png"
  "https://raw.githubusercontent.com/fornarwhal/deepseek-whale-girl-icon/main/improved-1.png"
  "https://cdn.jsdelivr.net/gh/fornarwhal/deepseek-whale-girl-icon@main/improved-2.png"
  "https://raw.githubusercontent.com/fornarwhal/deepseek-whale-girl-icon/main/improved-2.png"
)

echo "=============================================="
echo "  dsh 一键安装器（macOS）"
echo "=============================================="
echo ""

# 1. 检查/安装 Node.js
if ! command -v node >/dev/null 2>&1; then
  for p in /opt/homebrew/bin /usr/local/bin /opt/local/bin; do
    if [ -x "$p/node" ]; then
      export PATH="$p:$PATH"
      break
    fi
  done
fi

if ! command -v node >/dev/null 2>&1; then
  echo "[1/4] 未检测到 Node.js。"
  if command -v brew >/dev/null 2>&1; then
    echo "      正在用 Homebrew 安装 Node.js（可能需要几分钟）..."
    brew install node
  else
    echo "      你的电脑没有 Homebrew，无法自动安装。"
    echo "      即将打开 Node.js 官网，请下载安装 LTS 版本后重新运行本脚本。"
    open "https://nodejs.org/zh-cn/download"
    read -r -p "按回车键退出..." _
    exit 1
  fi
fi
echo "[1/4] Node.js 已就绪：$(node -v)"

# 2. 下载鲸鱼娘图标（可选；失败不影响安装）
echo "[2/4] 正在准备桌面图标..."
TMP_DIR="$(mktemp -d)"
ICON_PNG="$TMP_DIR/icon.png"
ICON_OK=0
for url in "${ICON_URLS[@]}"; do
  if curl -fsSL --max-time 30 "$url" -o "$ICON_PNG" && [ -s "$ICON_PNG" ]; then
    echo "      图标下载成功：$url"
    ICON_OK=1
    break
  else
    echo "      尝试失败：$url"
  fi
done
if [ "$ICON_OK" -eq 0 ]; then
  echo "      （未下载到图标，dsh.app 将使用系统默认图标，不影响使用）"
fi

# 3. 生成桌面 dsh.app（双击它就会在终端里启动 dsh）
echo "[3/4] 正在创建桌面 dsh.app..."
APP="$HOME/Desktop/dsh.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>dsh-launch</string>
  <key>CFBundleIdentifier</key><string>com.github.dsh-oneclick.dsh</string>
  <key>CFBundleName</key><string>dsh</string>
  <key>CFBundleDisplayName</key><string>dsh</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>dsh.icns</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>10.13</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

cat > "$APP/Contents/MacOS/dsh-launch" <<'LAUNCH'
#!/bin/bash
# 补齐常见 Node.js 安装路径，保证从 Finder 启动时也能找到 npx
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
if ! command -v npx >/dev/null 2>&1; then
  osascript -e 'display dialog "找不到 Node.js（npx）。请先安装 Node.js LTS：https://nodejs.org/zh-cn/download" buttons {"好"} default button 1 with icon stop' >/dev/null 2>&1
  exit 1
fi
osascript -e 'tell application "Terminal" to do script "npx -y @deepseek-ai/dsh web"' >/dev/null 2>&1
LAUNCH
chmod +x "$APP/Contents/MacOS/dsh-launch"

# 生成 .icns 图标（把 PNG 切成 macOS 需要的各尺寸）
if [ "$ICON_OK" -eq 1 ]; then
  ICONSET="$TMP_DIR/dsh.iconset"
  mkdir -p "$ICONSET"
  sips -z 16   16   "$ICON_PNG" --out "$ICONSET/icon_16x16.png"       >/dev/null 2>&1
  sips -z 32   32   "$ICON_PNG" --out "$ICONSET/icon_16x16@2x.png"    >/dev/null 2>&1
  sips -z 32   32   "$ICON_PNG" --out "$ICONSET/icon_32x32.png"       >/dev/null 2>&1
  sips -z 64   64   "$ICON_PNG" --out "$ICONSET/icon_32x32@2x.png"    >/dev/null 2>&1
  sips -z 128  128  "$ICON_PNG" --out "$ICONSET/icon_128x128.png"     >/dev/null 2>&1
  sips -z 256  256  "$ICON_PNG" --out "$ICONSET/icon_128x128@2x.png"  >/dev/null 2>&1
  sips -z 256  256  "$ICON_PNG" --out "$ICONSET/icon_256x256.png"     >/dev/null 2>&1
  sips -z 512  512  "$ICON_PNG" --out "$ICONSET/icon_256x256@2x.png"  >/dev/null 2>&1
  sips -z 512  512  "$ICON_PNG" --out "$ICONSET/icon_512x512.png"     >/dev/null 2>&1
  sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET/icon_512x512@2x.png"  >/dev/null 2>&1
  if iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/dsh.icns" 2>/dev/null; then
    echo "      图标已生成。"
  else
    echo "      （图标生成失败，使用默认图标，不影响使用）"
  fi
fi

# 4. 启动 dsh
echo "[4/4] 正在启动 dsh（会自动打开浏览器）..."
open "$APP"
echo ""
echo "完成！以后想启动 dsh，双击桌面的 dsh 图标即可。"
