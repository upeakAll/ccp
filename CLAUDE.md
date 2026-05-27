# CCP (Claude Code Provider) 安装指南

本文档供 Claude Code 读取并执行安装步骤。

## 项目概述

CCP 是 Claude Code 的 Provider 切换器，通过 fzf TUI 选择模型供应商，自动写入项目 settings.json，然后启动 Claude Code。

## 安装前提

在新 Mac 上执行以下步骤前，确保以下工具已安装：

1. **jq** - JSON 处理工具
2. **fzf** - 模糊搜索工具
3. **claude** - Claude Code CLI
4. **sqlite3** - 用于 cc-switch 同步功能（可选）

检查命令：
```bash
command -v jq && echo "jq OK" || echo "jq NOT FOUND"
command -v fzf && echo "fzf OK" || echo "fzf NOT FOUND"
command -v claude && echo "claude OK" || echo "claude NOT FOUND"
command -v sqlite3 && echo "sqlite3 OK" || echo "sqlite3 NOT FOUND"
```

## 安装步骤

### 步骤 1：复制 ccp 脚本到全局路径

```bash
# 创建目标目录
mkdir -p ~/.npm-global/bin

# 复制脚本并赋予执行权限
cp ccp ~/.npm-global/bin/ccp
chmod +x ~/.npm-global/bin/ccp
```

### 步骤 2：配置 PATH 环境变量

如果 `~/.npm-global/bin` 不在 PATH 中，需要添加到 shell 配置：

```bash
# 检查是否已在 PATH 中
if [[ ":$PATH:" != *":$HOME/.npm-global/bin:"* ]]; then
  echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.zshrc
  echo "已添加 PATH 到 ~/.zshrc，请执行: source ~/.zshrc"
fi
```

### 步骤 3：配置 providers.json

```bash
# 复制配置文件（如果存在）
if [[ -f providers.json ]]; then
  mkdir -p ~/.claude
  cp providers.json ~/.claude/providers.json
  echo "已复制 providers.json 到 ~/.claude/"
else
  echo "providers.json 不存在，请手动配置 ~/.claude/providers.json"
fi
```

### 步骤 4：配置 shell alias（可选但推荐）

```bash
# 添加 alias 到 .zshrc
if ! grep -q "alias ccp=" ~/.zshrc 2>/dev/null; then
  echo "" >> ~/.zshrc
  echo "# Claude Code Provider Switcher" >> ~/.zshrc
  echo 'alias ccp="~/.npm-global/bin/ccp"' >> ~/.zshrc
  echo "已添加 alias 到 ~/.zshrc，请执行: source ~/.zshrc"
fi
```

### 步骤 5：验证安装

```bash
# 重新加载 shell 配置
source ~/.zshrc 2>/dev/null || true

# 验证 ccp 可执行
which ccp && echo "✅ ccp 已安装" || echo "❌ ccp 未找到"

# 检查依赖
which jq && echo "✅ jq 已安装" || echo "❌ jq 未安装"
which fzf && echo "✅ fzf 已安装" || echo "❌ fzf 未安装"
which claude && echo "✅ claude 已安装" || echo "❌ claude 未安装"
```

## 使用方法

```bash
# 在任意项目目录运行 ccp
ccp

# 从 cc-switch 同步配置（需要 ~/.cc-switch/cc-switch.db）
ccp sync
```

## 配置文件说明

### ~/.claude/providers.json

```json
{
  "providers": {
    "provider-key": {
      "name": "Provider Name",
      "icon": "🤖",
      "env": {
        "ANTHROPIC_BASE_URL": "https://api.example.com",
        "ANTHROPIC_AUTH_TOKEN": "your-token",
        "ANTHROPIC_DEFAULT_OPUS_MODEL": "model-name",
        "ANTHROPIC_DEFAULT_SONNET_MODEL": "model-name",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL": "model-name",
        "ANTHROPIC_MODEL": "model-name"
      },
      "model": "opus[1m]",
      "endpoint": "https://api.example.com"
    }
  },
  "lastSelection": {}
}
```

**关键字段说明**：
- `env.ANTHROPIC_DEFAULT_OPUS_MODEL`: Opus 模型映射的实际模型名
- `env.ANTHROPIC_MODEL`: 默认模型（ccp 会强制设为 actual_model）
- `model`: Claude Code 的模型别名（如 opus[1m]）

## 工作原理

1. 运行 `ccp` 时，从 `~/.claude/providers.json` 读取所有供应商
2. 通过 fzf 选择供应商
3. 提取供应商的 env 配置和实际模型名（优先 `ANTHROPIC_DEFAULT_OPUS_MODEL`）
4. 写入当前项目的 `.claude/settings.json`：
   - 替换所有 `ANTHROPIC_*` 环境变量
   - 设置 `env.ANTHROPIC_MODEL` 为实际模型名
   - 设置 `model` 字段为实际模型名
5. 启动 `claude --dangerously-skip-permissions --effort high`

## 故障排查

### 问题：模型显示不正确

**原因**：项目 settings.json 中的 `model` 或 `env.ANTHROPIC_MODEL` 未正确设置。

**解决**：检查 `.claude/settings.json`，确保 `model` 和 `env.ANTHROPIC_MODEL` 都是实际模型名（不是别名）。

### 问题：ccp 命令未找到

**原因**：`~/.npm-global/bin` 不在 PATH 中。

**解决**：执行 `export PATH="$HOME/.npm-global/bin:$PATH"` 并添加到 `~/.zshrc`。

### 问题：fzf 界面显示异常

**原因**：终端不支持 Unicode 或颜色配置。

**解决**：检查终端编码为 UTF-8，或调整 fzf 的 `--color` 参数。

## 文件结构

```
ccp-migrate/
├── ccp                  # 主脚本（安装到 ~/.npm-global/bin/ccp）
├── install.sh          # 一键安装脚本（可选）
├── providers.json      # 供应商配置示例
└── CLAUDE.md          # 本文档
```

## 一键安装（可选）

如果不想手动执行上述步骤，可以运行 install.sh：

```bash
bash install.sh
```

该脚本会自动执行步骤 1-4。
