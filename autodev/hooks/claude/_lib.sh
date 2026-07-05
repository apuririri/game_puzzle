#!/usr/bin/env bash
# autodev/hooks/claude/_lib.sh
# 各 hook 共通ヘルパー（案8: jq 必須化 / 案2: hook 失敗ロギング）。
# 各 hook の冒頭で:
#   . "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
# のように source する。

# プロジェクトルートを解決（hooks/claude/ から3階層上）。
_hook_root() {
  echo "${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
}

# 失敗ログ ndjson に1行追記する（案2）。
# 引数: <hook名> <severity: error|warn> <メッセージ>
# 副作用なしで戻る（書き込み失敗は無視）。
hook_log_failure() {
  local hook="${1:-unknown}" severity="${2:-warn}" msg="${3:-}"
  local root file ts safe_msg
  root="$(_hook_root)"
  file="$root/autodev/state/hook_failures.ndjson"
  mkdir -p "$root/autodev/state" 2>/dev/null
  ts="$(date -Iseconds 2>/dev/null || date)"
  # 改行と二重引用符だけエスケープ（control char 含まない前提）
  safe_msg="$(printf '%s' "$msg" | tr '\n\r\t' '   ' | sed 's/\\/\\\\/g; s/"/\\"/g')"
  printf '{"ts":"%s","hook":"%s","severity":"%s","msg":"%s","resolved":false}\n' \
    "$ts" "$hook" "$severity" "$safe_msg" >> "$file" 2>/dev/null || true
}

# jq 必須化（案8）。
# 引数: <hook名>  失敗時に hook_log_failure へ記録し、return 1。
# 呼び出し側で exit code を決める（critical hook は exit 1、軽微 hook は exit 0 + 続行可）。
hook_require_jq() {
  local hook="${1:-unknown}"
  if command -v jq >/dev/null 2>&1; then return 0; fi
  {
    echo "ERROR: AutoDev Agent hook '$hook' は jq を要求しますが見つかりません。"
    echo "  対処: 'apt install jq' / 'brew install jq' / 'choco install jq' で導入してください。"
    echo "  緊急バイパス: AUTODEV_DISABLE_HOOKS=1 を設定（安全網が無効化されます / FR-5.15.5）"
  } >&2
  hook_log_failure "$hook" "error" "jq not found in PATH"
  return 1
}
