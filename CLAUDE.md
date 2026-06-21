# CCP (Claude Code Provider) 安装指南

本文档供 Claude Code 读取并执行安装步骤。

## 项目概述

CCP 是 Claude Code 的 Provider 切换器，通过 fzf TUI 选择模型供应商，把模型相关的 `ANTHROPIC_*` 配置以**环境变量注入当前进程**（多窗口隔离、互不串改），同时把 `permissions` / `hooks` 等 window 通用配置同步到项目 `.claude/settings.json`，然后启动 Claude Code。

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
which sqlite3 && echo "✅ sqlite3 已安装（ccp sync 用）" || echo "⚠️ sqlite3 未安装（仅 ccp sync 需要，可跳过）"
```

## 使用方法

```bash
# 在任意项目目录运行 ccp
ccp

# 从 cc-switch 同步配置（需要 ~/.cc-switch/cc-switch.db，且本机已装 sqlite3）
ccp sync

# 透传额外参数给 claude
ccp --resume
```

### TUI 交互

- **选择供应商**：方向键移动，回车确认，Esc 取消。
- **Keep current**：列表首项「Keep current」保留上次选择（括号内显示上次供应商名），首次进入无上次选择时仅启动 claude。
- **预览面板**：右侧实时展示当前选中供应商的 Opus / Sonnet / Haiku 模型映射，方便对比。
- **记住选择**：选择会按项目目录记录到 `providers.json` 的 `lastSelection`，下次进入时该供应商排首位。

### 多窗口隔离

模型配置走环境变量注入，每个 `ccp` 启动的 claude 进程持有独立配置。同一项目目录下可同时开多个终端窗口、各自选不同模型，互不覆盖。共用配置（permissions/hooks 等）仍写入项目 `.claude/settings.json`，对所有窗口一致。

### 升级

更新 ccp 脚本后，重新执行步骤 1（复制到 `~/.npm-global/bin/ccp`）即可，无需改动 `providers.json`。旧版本若曾把 `ANTHROPIC_*`/`model` 写进项目 `.claude/settings.json`，下次运行新版 `ccp` 会自动剔除这些键。

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
4. **同步共用配置到项目 `.claude/settings.json`**：以 `~/.claude/settings.json` 为基础，保留 `permissions` / `hooks` / `enabledPlugins` / `extraKnownMarketplaces` / `statusLine` 等所有窗口通用的配置，但**剔除 `env` 中所有 `ANTHROPIC_*` 键和顶层 `model` 字段**
5. **通过环境变量注入模型配置到当前进程**：导出供应商的 `ANTHROPIC_*` 等环境变量，并强制 `ANTHROPIC_MODEL` 为实际模型名
6. 启动 `claude --dangerously-skip-permissions --effort high`

### 为什么模型配置用环境变量，而不是写 settings.json

Claude Code 的配置优先级中，**shell 环境变量高于 `.claude/settings.json` 的 `env`/`model` 字段**。因此把 provider 的模型配置注入到进程环境即可生效，无需写入共享的 `.claude/settings.json`。

这样每个 claude 进程持有独立的模型配置，互不覆盖：在同一个项目目录下可以同时开多个窗口、各自选择不同模型，而不会出现后开的窗口把先开的窗口"串改"或弄失效的问题（旧实现把 `ANTHROPIC_*`/`model` 也写进共享 settings.json，因 Claude Code 热重载 settings.json 而互相冲突）。

### 为什么共用配置仍写 settings.json

`permissions` / `hooks` / `plugins` / `statusLine` 等与 provider 无关，对所有窗口和模型都一致，写共享文件安全（内容一致，热重载无副作用），且它们没有对应的环境变量，只能通过 settings 文件加载。因此这部分继续同步到项目 `.claude/settings.json`。

## 故障排查

### 问题：模型显示不正确

**原因**：provider 的 `env` 中 `ANTHROPIC_DEFAULT_OPUS_MODEL` 或 `ANTHROPIC_MODEL` 配置有误。

**解决**：检查 `~/.claude/providers.json` 中对应供应商的 `env` 配置，确保 `ANTHROPIC_DEFAULT_OPUS_MODEL`（和 `ANTHROPIC_MODEL`）是实际模型名。

### 问题：同一目录下多个窗口使用了相同模型

**原因**：旧版本 ccp 会把配置写入共享的 `.claude/settings.json`，导致后开的窗口覆盖先开的。

**解决**：当前版本已改为环境变量注入（见「工作原理」），每个窗口独立。请确保使用最新版 ccp 脚本，并始终通过 `ccp`（而非直接 `claude`）启动。

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
