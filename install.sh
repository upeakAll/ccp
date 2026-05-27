#!/bin/bash
set -euo pipefail

echo "=== CCP (Claude Code Provider) 一键安装 ==="
echo ""

# 1. 检查并安装依赖
echo "1. 检查依赖..."
missing=()
for cmd in jq fzf claude; do
  if ! command -v "$cmd" &>/dev/null; then
    missing+=("$cmd")
    echo "   ❌ 缺少: $cmd"
  else
    echo "   ✅ $cmd 已安装"
  fi
done

if [ ${#missing[@]} -gt 0 ]; then
  echo ""
  echo "请先安装缺少的依赖:"
  for cmd in "${missing[@]}"; do
    case "$cmd" in
      jq)
        echo "   brew install jq"
        ;;
      fzf)
        echo "   brew install fzf"
        echo "   # 安装后运行: $(brew --prefix)/opt/fzf/install"
        ;;
      claude)
        echo "   npm install -g @anthropic-ai/claude-code"
        ;;
    esac
  done
  echo ""
  echo "安装完成后重新运行此脚本"
  exit 1
fi

# 2. 创建目录
echo ""
echo "2. 创建目录..."
mkdir -p ~/.claude
mkdir -p ~/.npm-global/bin
echo "   ✅ ~/.claude"
echo "   ✅ ~/.npm-global/bin"

# 3. 复制 ccp 脚本
echo ""
echo "3. 安装 ccp 脚本..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/ccp" ]]; then
  cp "$SCRIPT_DIR/ccp" ~/.npm-global/bin/ccp
  chmod +x ~/.npm-global/bin/ccp
  echo "   ✅ ccp 脚本已安装到 ~/.npm-global/bin/ccp"
else
  echo "   ❌ 找不到 ccp 脚本（当前目录: $SCRIPT_DIR）"
  exit 1
fi

# 4. 复制 providers.json（如果存在）
echo ""
echo "4. 复制配置文件..."
if [[ -f "$SCRIPT_DIR/providers.json" ]]; then
  cp "$SCRIPT_DIR/providers.json" ~/.claude/providers.json
  echo "   ✅ providers.json 已复制到 ~/.claude/providers.json"
else
  echo "   ⚠️  未找到 providers.json，跳过"
fi

# 5. 添加 alias 到 .zshrc
echo ""
echo "5. 配置 shell alias..."
if ! grep -q "alias ccp=" ~/.zshrc 2>/dev/null; then
  echo "" >> ~/.zshrc
  echo "# Claude Code Provider Switcher" >> ~/.zshrc
  echo 'alias ccp="~/.npm-global/bin/ccp"' >> ~/.zshrc
  echo "   ✅ 已添加 alias 到 ~/.zshrc"
else
  echo "   ℹ️  alias 已存在"
fi

# 6. 检查 PATH
echo ""
echo "6. 检查 PATH..."
if [[ "$PATH" == *"~/.npm-global/bin"* ]] || [[ "$PATH" == *"$HOME/.npm-global/bin"* ]]; then
  echo "   ✅ ~/.npm-global/bin 已在 PATH 中"
else
  echo "   ⚠️  ~/.npm-global/bin 不在 PATH 中"
  echo "   请添加以下行到 ~/.zshrc:"
  echo '   export PATH="$HOME/.npm-global/bin:$PATH"'
fi

echo ""
echo "=== 安装完成 ==="
echo ""
echo "使用方法:"
echo "  source ~/.zshrc"
echo "  ccp          # 启动 Claude Code 并选择供应商"
echo "  ccp sync     # 从 cc-switch 同步配置"
echo ""
echo "文件位置:"
echo "  脚本: ~/.npm-global/bin/ccp"
echo "  配置: ~/.claude/providers.json"
