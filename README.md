# CCP - Claude Code Provider Switcher

一个轻量级的 Claude Code 模型供应商切换工具，通过 fzf 交互式界面快速切换不同的 AI 模型提供商。

## ✨ 功能特性

- 🎯 **一键切换** - 通过 fzf 模糊搜索快速选择供应商
- 🔄 **自动同步** - 支持从 cc-switch 数据库同步配置
- 💾 **记忆选择** - 记住每个项目上次使用的供应商
- 🎨 **美观界面** - 带颜色主题的 TUI 界面，实时预览模型映射
- 🚀 **零配置启动** - 无需手动编辑 settings.json，自动写入项目配置

## 📦 安装

### 前置要求

确保以下工具已安装：

```bash
# macOS
brew install jq fzf sqlite3

# Claude Code CLI
npm install -g @anthropic-ai/claude-code
```

### 一键安装

```bash
# 克隆或下载项目
cd ccp-migrate

# 运行安装脚本
bash install.sh

# 重新加载 shell 配置
source ~/.zshrc
```

安装脚本会自动：
1. 检查依赖（jq、fzf、claude）
2. 复制 `ccp` 到 `~/.npm-global/bin/`
3. 复制 `providers.json` 到 `~/.claude/`
4. 配置 shell alias

### 手动安装

```bash
# 1. 复制脚本
mkdir -p ~/.npm-global/bin
cp ccp ~/.npm-global/bin/ccp
chmod +x ~/.npm-global/bin/ccp

# 2. 配置 PATH（如果不在 PATH 中）
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.zshrc

# 3. 配置 alias
echo 'alias ccp="~/.npm-global/bin/ccp"' >> ~/.zshrc

# 4. 复制配置文件
mkdir -p ~/.claude
cp providers.json ~/.claude/providers.json

# 5. 重新加载
source ~/.zshrc
```

## 🚀 使用方法

### 基本使用

在任意项目目录运行：

```bash
ccp
```

会弹出 fzf 界面，选择供应商后按 Enter：
- 自动写入当前项目的 `.claude/settings.json`
- 启动 Claude Code（带 `--dangerously-skip-permissions --effort high`）

### 保持当前配置

选择 `* Keep current` 可保持现有配置不变，直接启动 Claude Code。

### 从 cc-switch 同步

如果你使用 cc-switch 管理配置：

```bash
ccp sync
```

会从 `~/.cc-switch/cc-switch.db` 同步所有 Claude 类型的供应商到 `~/.claude/providers.json`。

## ⚙️ 配置

### providers.json 结构

配置文件位于 `~/.claude/providers.json`：

```json
{
  "providers": {
    "provider-key": {
      "name": "Provider Display Name",
      "icon": "🤖",
      "env": {
        "ANTHROPIC_BASE_URL": "https://api.example.com",
        "ANTHROPIC_AUTH_TOKEN": "your-api-token",
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

### 关键字段说明

| 字段 | 说明 |
|------|------|
| `name` | 供应商显示名称 |
| `icon` | 供应商图标（emoji） |
| `env.ANTHROPIC_DEFAULT_OPUS_MODEL` | Opus 模型映射的实际模型名 |
| `env.ANTHROPIC_MODEL` | 默认模型（ccp 会强制设为实际模型名） |
| `model` | Claude Code 模型别名（如 `opus[1m]`） |

### 示例配置

```json
{
  "deepseek": {
    "name": "DeepSeek",
    "icon": "🔍",
    "env": {
      "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
      "ANTHROPIC_AUTH_TOKEN": "sk-xxx",
      "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-v4-pro[1M]",
      "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-v4-pro[1M]",
      "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-pro",
      "ANTHROPIC_MODEL": "deepseek-v4-pro"
    },
    "model": "opus[1m]",
    "endpoint": "https://api.deepseek.com/anthropic"
  }
}
```

## 🔧 工作原理

1. **读取配置** - 从 `~/.claude/providers.json` 加载所有供应商
2. **TUI 选择** - 通过 fzf 展示供应商列表，支持模糊搜索和实时预览
3. **提取模型** - 优先使用 `ANTHROPIC_DEFAULT_OPUS_MODEL`，回退到 `ANTHROPIC_MODEL`
4. **写入配置** - 更新当前项目的 `.claude/settings.json`：
   - 替换所有 `ANTHROPIC_*` 环境变量
   - 设置 `env.ANTHROPIC_MODEL` 为实际模型名
   - 设置 `model` 字段为实际模型名
5. **记忆选择** - 记录当前项目使用的供应商
6. **启动 Claude** - 执行 `claude --dangerously-skip-permissions --effort high`

## 📁 文件结构

```
ccp-migrate/
├── ccp                  # 主脚本（安装到 ~/.npm-global/bin/ccp）
├── install.sh          # 一键安装脚本
├── providers.json      # 供应商配置示例
├── README.md           # 本文档
└── CLAUDE.md          # Claude Code 安装指南
```

## 🎯 特性说明

### 模型映射逻辑

Claude Code 使用模型别名（如 `opus[1m]`），但不同供应商的实际模型名不同。CCP 会自动：

1. 从供应商配置中提取实际模型名
2. 强制设置 `env.ANTHROPIC_MODEL` 为实际模型名
3. 确保 Claude Code 启动时使用正确的模型

### 项目级配置

每个项目的供应商选择独立记忆，存储在 `lastSelection` 中：

```json
{
  "lastSelection": {
    "/Users/user/project1": "deepseek",
    "/Users/user/project2": "minimax"
  }
}
```

## 🐛 故障排查

### 问题：模型显示不正确

**原因**：项目 settings.json 中的 `model` 或 `env.ANTHROPIC_MODEL` 未正确设置。

**解决**：检查 `.claude/settings.json`，确保字段是实际模型名（不是别名）。

### 问题：ccp 命令未找到

**原因**：`~/.npm-global/bin` 不在 PATH 中。

**解决**：
```bash
export PATH="$HOME/.npm-global/bin:$PATH"
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.zshrc
```

### 问题：fzf 界面显示异常

**原因**：终端不支持 Unicode 或颜色配置。

**解决**：检查终端编码为 UTF-8，或调整 fzf 的 `--color` 参数。

### 问题：配置文件不存在

**原因**：未复制 `providers.json` 到正确位置。

**解决**：
```bash
mkdir -p ~/.claude
cp providers.json ~/.claude/providers.json
```

## 📝 更新日志

### v1.0.0
- 初始版本
- fzf TUI 界面
- 自动模型映射
- 项目级供应商记忆
- cc-switch 同步支持

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📧 联系方式

如有问题或建议，请提交 Issue。
