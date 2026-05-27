#!/usr/bin/env bash
set -euo pipefail

PROVIDERS_FILE="$HOME/.claude/providers.json"
PROJECT_DIR="$(pwd)"
PROJECT_SETTINGS="$PROJECT_DIR/.claude/settings.json"
CCSWITCH_DB="$HOME/.cc-switch/cc-switch.db"

# --- 依赖检查 ---
for cmd in jq fzf claude; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Error: $cmd not found"; exit 1; }
done

# --- sync 命令 ---
if [[ "${1:-}" == "sync" ]]; then
  if [[ ! -f "$CCSWITCH_DB" ]]; then
    echo "Error: cc-switch database not found at $CCSWITCH_DB"
    exit 1
  fi

  echo "Syncing from cc-switch..."

  # 读取现有 providers.json（如果存在）
  existing_providers="{}"
  if [[ -f "$PROVIDERS_FILE" ]]; then
    existing_providers=$(jq -c '.providers // {}' "$PROVIDERS_FILE")
  fi

  # 从 cc-switch 读取所有 claude 供应商
  sqlite3 "$CCSWITCH_DB" "SELECT id, name, settings_config, icon FROM providers WHERE app_type='claude'" | while IFS='|' read -r id name config icon; do
    # 生成 provider key（使用 name 的小写版本）
    key=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    # 解析 settings_config
    if [[ -z "$config" ]]; then
      continue
    fi

    # 提取 env 和 model
    env_json=$(echo "$config" | jq -c '.env // {}' 2>/dev/null || echo "{}")
    model=$(echo "$config" | jq -r '.model // "opus[1m]"' 2>/dev/null || echo "opus[1m]")

    # 从 env 中提取 endpoint
    endpoint=$(echo "$config" | jq -r '.env.ANTHROPIC_BASE_URL // ""' 2>/dev/null || echo "")

    # 保留现有 icon（如果存在），否则使用默认
    existing_icon=$(echo "$existing_providers" | jq -r ".[\"$key\"].icon // empty" 2>/dev/null || echo "")
    if [[ -z "$existing_icon" ]]; then
      case "$name" in
        annto*) default_icon="🤖" ;;
        DeepSeek*) default_icon="🔍" ;;
        MiniMax*) default_icon="⚡" ;;
        Zhipu*) default_icon="🔮" ;;
        *) default_icon="🌐" ;;
      esac
      icon_to_use="$default_icon"
    else
      icon_to_use="$existing_icon"
    fi

    # 更新 providers.json
    if [[ -f "$PROVIDERS_FILE" ]]; then
      jq --arg key "$key" \
         --arg name "$name" \
         --argjson env "$env_json" \
         --arg model "$model" \
         --arg endpoint "$endpoint" \
         --arg icon "$icon_to_use" \
         '.providers[$key] = {name: $name, icon: $icon, env: $env, model: $model, endpoint: $endpoint}' \
         "$PROVIDERS_FILE" > "${PROVIDERS_FILE}.tmp" && mv "${PROVIDERS_FILE}.tmp" "$PROVIDERS_FILE"
    else
      # 如果文件不存在，创建初始结构
      jq -n --arg key "$key" \
            --arg name "$name" \
            --argjson env "$env_json" \
            --arg model "$model" \
            --arg endpoint "$endpoint" \
            --arg icon "$icon_to_use" \
            '{providers: {($key): {name: $name, icon: $icon, env: $env, model: $model, endpoint: $endpoint}}, lastSelection: {}}' \
            > "$PROVIDERS_FILE"
    fi

    echo "  Synced: $icon_to_use $name"
  done

  echo "Done. Providers synced from cc-switch."
  exit 0
fi

if [[ ! -f "$PROVIDERS_FILE" ]]; then
  echo "Error: $PROVIDERS_FILE not found."
  exit 1
fi

# --- 构建供应商列表 ---
last_key=$(jq -r '.lastSelection["'"$PROJECT_DIR"'"] // ""' "$PROVIDERS_FILE")

# 获取上次选择的供应商名称
last_name=""
if [[ -n "$last_key" ]]; then
  last_name=$(jq -r '.providers["'"$last_key"'"].name // ""' "$PROVIDERS_FILE" 2>/dev/null || echo "")
fi

# 添加"保持当前"选项，括号里显示上次选择
if [[ -n "$last_name" ]]; then
  keep_current_line="__KEEP_CURRENT__	*	Keep current [$last_name]	-"
else
  keep_current_line="__KEEP_CURRENT__	*	Keep current	-"
fi

# 格式: key\ticon\tname\tmodel
provider_list=$(jq -r '.providers | to_entries[] | "\(.key)\t\(.value.icon // "")\t\(.value.name)\t\(.value.model // "opus[1m]")"' "$PROVIDERS_FILE")

if [[ -z "$provider_list" ]]; then
  echo "Error: No providers configured."
  exit 1
fi

# 上次选择排首位
if [[ -n "$last_key" ]]; then
  first_line=$(echo "$provider_list" | grep "^${last_key}" | head -1 || true)
  rest_lines=$(echo "$provider_list" | grep -v "^${last_key}" || true)
  if [[ -n "$first_line" ]]; then
    provider_list="${first_line}"$'\n'"${rest_lines}"
  fi
fi

# 最后添加 keep current 选项在最前面
provider_list="${keep_current_line}"$'\n'"${provider_list}"

# --- TUI 选择 ---
selected_key=$(echo "$provider_list" | \
  fzf \
    --delimiter='\t' \
    --with-nth=2..4 \
    --accept-nth=1 \
    --no-multi \
    --height=~90% \
    --layout=reverse \
    --prompt='⚡ Provider> ' \
    --header=$'\n  Select model provider · Enter confirm · Esc cancel\n' \
    --border=double \
    --margin=1,2,1,2 \
    --color='border:#7C3AED,header:#A78BFA,prompt:#7C3AED,pointer:#7C3AED,marker:#7C3AED,fg+:#7C3AED,bg+:#1E1B4B' \
    --pointer='▶' \
    --marker='●' \
    --info='inline' \
    --preview='KEY={1}; if [ "$KEY" = "__KEEP_CURRENT__" ]; then LAST_KEY="'"$last_key"'"; if [ -n "$LAST_KEY" ]; then echo ""; echo "  * Keep current [$LAST_KEY]"; echo "  ─────────────────────"; echo "  Model Mappings:"; echo "  Opus:   $(jq -r ".providers[\"$LAST_KEY\"].env.ANTHROPIC_DEFAULT_OPUS_MODEL // \"default\"" "$HOME/.claude/providers.json")"; echo "  Sonnet: $(jq -r ".providers[\"$LAST_KEY\"].env.ANTHROPIC_DEFAULT_SONNET_MODEL // \"default\"" "$HOME/.claude/providers.json")"; echo "  Haiku:  $(jq -r ".providers[\"$LAST_KEY\"].env.ANTHROPIC_DEFAULT_HAIKU_MODEL // \"default\"" "$HOME/.claude/providers.json")"; else echo ""; echo "  * Keep current"; echo "  ─────────────────────"; echo "  No previous selection"; fi; else echo ""; echo "  Model Mappings:"; echo "  ─────────────────────"; echo "  Opus:   $(jq -r ".providers[\"$KEY\"].env.ANTHROPIC_DEFAULT_OPUS_MODEL // \"default\"" "$HOME/.claude/providers.json")"; echo "  Sonnet: $(jq -r ".providers[\"$KEY\"].env.ANTHROPIC_DEFAULT_SONNET_MODEL // \"default\"" "$HOME/.claude/providers.json")"; echo "  Haiku:  $(jq -r ".providers[\"$KEY\"].env.ANTHROPIC_DEFAULT_HAIKU_MODEL // \"default\"" "$HOME/.claude/providers.json")"; fi' \
    --preview-window='right:55%:wrap' \
  ) || { echo "Cancelled."; exit 0; }

if [[ -z "$selected_key" ]]; then
  echo "No provider selected."
  exit 0
fi

# --- 处理"保持当前"选项 ---
if [[ "$selected_key" == "__KEEP_CURRENT__" ]]; then
  echo "  ✅ Keeping current settings"
  exec claude --dangerously-skip-permissions --effort high "$@"
fi

# --- 提取供应商配置 ---
provider_env=$(jq -c '.providers["'"$selected_key"'"].env' "$PROVIDERS_FILE")
provider_model=$(jq -r '.providers["'"$selected_key"'"].model // "opus[1m]"' "$PROVIDERS_FILE")
provider_name=$(jq -r '.providers["'"$selected_key"'"].name' "$PROVIDERS_FILE")
provider_icon=$(jq -r '.providers["'"$selected_key"'"].icon // ""' "$PROVIDERS_FILE")

# 从 env 中提取实际模型名（优先 ANTHROPIC_DEFAULT_OPUS_MODEL，回退到 ANTHROPIC_MODEL）
actual_model=$(echo "$provider_env" | jq -r '.ANTHROPIC_DEFAULT_OPUS_MODEL // .ANTHROPIC_MODEL // empty')
if [[ -z "$actual_model" ]]; then
  actual_model="$provider_model"
fi

GLOBAL_SETTINGS="$HOME/.claude/settings.json"

# --- 同步到项目 settings.json ---
mkdir -p "$PROJECT_DIR/.claude"

# 以全局配置为基础，只替换 ANTHROPIC_* env 和 model，并强制 ANTHROPIC_MODEL 与实际模型一致
if [[ -f "$GLOBAL_SETTINGS" ]]; then
  jq --argjson new_env "$provider_env" --arg model "$actual_model" '
    .env //= {} |
    .env |= (with_entries(select(.key | startswith("ANTHROPIC_") | not)) * $new_env) |
    .env.ANTHROPIC_MODEL = $model |
    .model = $model
  ' "$GLOBAL_SETTINGS" > "${PROJECT_SETTINGS}.tmp" \
    && mv "${PROJECT_SETTINGS}.tmp" "$PROJECT_SETTINGS"
else
  jq -n --argjson new_env "$provider_env" --arg model "$actual_model" \
    '{env: ($new_env + {ANTHROPIC_MODEL: $model}), model: $model}' > "$PROJECT_SETTINGS"
fi

echo "  ${provider_icon} Switched to: ${provider_name} (${actual_model})"

# --- 记住选择 ---
jq --arg path "$PROJECT_DIR" --arg key "$selected_key" \
  '.lastSelection[$path] = $key' "$PROVIDERS_FILE" > "${PROVIDERS_FILE}.tmp" \
  && mv "${PROVIDERS_FILE}.tmp" "$PROVIDERS_FILE"

# --- 启动 claude ---
exec claude --dangerously-skip-permissions --effort high "$@"
