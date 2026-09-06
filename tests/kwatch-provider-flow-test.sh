#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CAPTURE_DIR=$(mktemp -d)
trap 'rm -rf "$CAPTURE_DIR"' EXIT

# shellcheck source=../static/kwatch.sh
source "$ROOT/static/kwatch.sh"
CONFIG_MOUNT_PATH="$CAPTURE_DIR"
NAMESPACE=kwatch
RELEASE=kwatch
CONFIG_SECRET_NAME=kwatch-config
CATALOG=('dummy|string|default|Test|Dummy setting|runtime|')
PROVIDER_CATALOG=(
  'slack|Slack|webhook|string|false|true|url||Slack webhook URL|authentication|choice:webhook'
  'slack|Slack|channel|string|false|false|||Override channel||required-if:authentication=token'
  'slack|Slack|title|string|false|false|||Custom title'
  'slack|Slack|token|string|false|true|||Bot token (xoxb-...)|authentication|choice:token'
  'telegram|Telegram|token|string|true|true|||Bot token'
  'telegram|Telegram|chatId|string|true|false|signed-integer||Chat ID'
)

SEARCH_MODE=false

FLOW=single
PROMPT_LOG="$CAPTURE_DIR/prompts.log"
PROVIDER_COUNT_FILE="$CAPTURE_DIR/provider-count"
ADD_COUNT_FILE="$CAPTURE_DIR/add-count"

ask() {
  local prompt="$1"
  if [ "$SEARCH_MODE" = true ]; then
    case "$prompt" in
      *Provider\ name*) printf 'slack-' ; return ;;
      *matching\ provider*) printf '2' ; return ;;
    esac
  fi
  printf '%s\n' "$prompt" >>"$PROMPT_LOG"
  case "$FLOW:$prompt" in
    *:*Configure\ notification\ providers*)
      [ "$FLOW" = none ] && printf 'n' || printf 'y' ;;
    *:*Provider\ name*)
      count=$(cat "$PROVIDER_COUNT_FILE" 2>/dev/null || printf '0')
      count=$((count + 1))
      printf '%s' "$count" >"$PROVIDER_COUNT_FILE"
      if [ "$count" -eq 1 ]; then
        printf 'slack'
      else
        printf 'telegram'
      fi
      ;;
    *:*authentication\ option*) printf '2' ;;
    *:*Override\ channel*) printf '#alerts' ;;
    *:*Chat\ ID*) printf '%s' '-100123' ;;
    *:*Add\ another\ notification\ provider*)
      count=$(cat "$ADD_COUNT_FILE" 2>/dev/null || printf '0')
      if [ "$FLOW" = multi ] && [ "$count" -eq 0 ]; then
        printf '1' >"$ADD_COUNT_FILE"
        printf 'y'
      else
        printf 'n'
      fi
      ;;
    *:*anonymous\ usage*) printf 'n' ;;
    *:*optional\ settings*) printf 'n' ;;
    *) printf '%s' "${2:-}" ;;
  esac
}

ask_secret() {
  printf '%s\n' "$1" >>"$PROMPT_LOG"
  printf 'secret-value'
}

kubectl() {
  local arg source
  if [[ " $* " == *" create secret generic "* ]]; then
    for arg in "$@"; do
      case "$arg" in
        --from-file=config.yaml=*)
          source="${arg#--from-file=config.yaml=}"
          cp "$source" "$CAPTURE_DIR/last-config.yaml"
          ;;
        --from-file=*)
          source="${arg#--from-file=*}"
          cp "${source#*=}" "$CAPTURE_DIR/${source%%=*}"
          ;;
      esac
    done
    printf '%s\n' apiVersion: v1 kind: Secret
    return 0
  fi
  if [[ " $* " == *" apply -f - "* ]]; then
    command cat >/dev/null
  fi
  return 0
}

PROVIDER_CATALOG+=(
  'slack-main|Slack Notifications|webhook|string|false|true|url||Primary Slack webhook'
  'slack-ops|Slack Operations|webhook|string|false|true|url||Operations Slack webhook'
)
CONFIGURED_PROVIDERS='|'
SEARCH_MODE=true
choose_provider
[ "$PROVIDER" = slack-ops ] || {
  echo "provider search did not use the short matching list" >&2
  exit 1
}
SEARCH_MODE=false
PROVIDER_CATALOG=("${PROVIDER_CATALOG[@]:0:6}")

write_config_secret
token_line=$(grep -n 'Bot token' "$PROMPT_LOG" | head -1 | cut -d: -f1)
channel_line=$(grep -n 'Override channel' "$PROMPT_LOG" | head -1 | cut -d: -f1)
optional_line=$(grep -n 'optional settings' "$PROMPT_LOG" | head -1 | cut -d: -f1)
telemetry_line=$(grep -n 'anonymous usage' "$PROMPT_LOG" | head -1 | cut -d: -f1)
[ "$token_line" -lt "$channel_line" ] &&
  [ "$channel_line" -lt "$telemetry_line" ] &&
  [ "$telemetry_line" -lt "$optional_line" ] || {
  echo "provider authentication was not prompted before optional settings" >&2
  exit 1
}
grep -Fq "token: \"\${file:$CAPTURE_DIR/slack-token}\"" \
  "$CAPTURE_DIR/last-config.yaml"
grep -Fq 'channel: "#alerts"' "$CAPTURE_DIR/last-config.yaml"

FLOW=none
write_config_secret
grep -Fq 'alert: {}' "$CAPTURE_DIR/last-config.yaml"

FLOW=multi
rm -f "$PROVIDER_COUNT_FILE" "$ADD_COUNT_FILE"
write_config_secret
grep -Eq '^  slack:' "$CAPTURE_DIR/last-config.yaml"
grep -Eq '^  telegram:' "$CAPTURE_DIR/last-config.yaml"

echo "kwatch provider flow test passed"
