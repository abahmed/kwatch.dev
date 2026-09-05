#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CAPTURE_DIR=$(mktemp -d)
trap 'rm -rf "$CAPTURE_DIR"' EXIT
export CAPTURE_DIR

# shellcheck source=../static/kwatch.sh
source "$ROOT/static/kwatch.sh"
CONFIG_MOUNT_PATH="$CAPTURE_DIR"

feature_file="$CAPTURE_DIR/features.tsv"
printf '%s\n' \
  '# kwatch feature catalog v1' \
  'core.detection.pods|runtime|Detect pod failures|' >"$feature_file"
load_feature_catalog_file "$feature_file"
[ "${#FEATURE_CATALOG[@]}" -eq 1 ] || {
  echo "feature catalog format was rejected" >&2
  exit 1
}

provider_count=$(printf '%s\n' "${PROVIDER_CATALOG[@]}" |
  cut -d'|' -f1 | sort -u | wc -l | tr -d ' ')
[ "$provider_count" -eq 56 ] || {
  echo "expected all 56 providers in the guided catalog" >&2
  exit 1
}

choose_provider() {
  PROVIDER=telegram
}

ask() {
  case "$1" in
    *"Release channel"*) printf '%s' "${RELEASE_CHOICE:-1}" ;;
    *anonymous*) printf 'n' ;;
    *chat*|*Chat*) printf '%s' '-100123' ;;
    *) printf '%s' "${2:-}" ;;
  esac
}

latest_version() { printf '%s' v0.10.5; }
latest_release_candidate() { printf '%s' v0.11.0-rc.7; }

selected_release=$(select_release_version)
[ "$selected_release" = v0.10.5 ] || {
  echo "stable release was not selected by default" >&2
  exit 1
}
RELEASE_CHOICE=2
selected_release=$(select_release_version)
[ "$selected_release" = v0.11.0-rc.7 ] || {
  echo "release candidate was not selected interactively" >&2
  exit 1
}
unset RELEASE_CHOICE

ask_secret() {
  case "$1" in
    *heartbeat*) printf '%s' 'https://heartbeat.example.test/ping' ;;
    *diagnostic*|*Bearer*) printf '%s' 'diagnostic-token-that-must-not-enter-config' ;;
    *) printf '%s' 'bot-token-that-must-not-enter-config' ;;
  esac
}

kubectl() {
  local arg source target
  if [[ " $* " == *" create secret generic "* ]]; then
    for arg in "$@"; do
      case "$arg" in
        --from-file=*)
          source="${arg#--from-file=}"
          target="${source%%=*}"
          source="${source#*=}"
          cp "$source" "$CAPTURE_DIR/$target"
          ;;
      esac
    done
    printf '%s\n' 'apiVersion: v1' 'kind: Secret'
    return
  fi
  if [[ " $* " == *" apply -f - "* ]]; then
    command cat >/dev/null
    return
  fi
  return 0
}

write_config_secret

grep -Fq "token: \"\${file:$CAPTURE_DIR/telegram-token}\"" \
  "$CAPTURE_DIR/config.yaml"
grep -Fq 'chatId: "-100123"' "$CAPTURE_DIR/config.yaml"
if grep -Fq 'bot-token-that-must-not-enter-config' \
    "$CAPTURE_DIR/config.yaml"; then
  echo "credential leaked into config.yaml" >&2
  exit 1
fi
test "$(cat "$CAPTURE_DIR/telegram-token")" = \
  'bot-token-that-must-not-enter-config'
grep -Fq "url: \"\${file:$CAPTURE_DIR/kwatch-config-heartbeatMonitor-url}\"" \
  "$CAPTURE_DIR/config.yaml"
grep -Fq "diagnosticsToken: \"\${file:$CAPTURE_DIR/kwatch-config-healthCheck-diagnosticsToken}\"" \
  "$CAPTURE_DIR/config.yaml"
if grep -Fq 'diagnostic-token-that-must-not-enter-config' \
    "$CAPTURE_DIR/config.yaml"; then
  echo "global credential leaked into config.yaml" >&2
  exit 1
fi
test "$(cat "$CAPTURE_DIR/kwatch-config-heartbeatMonitor-url")" = \
  'https://heartbeat.example.test/ping'
test "$(cat "$CAPTURE_DIR/kwatch-config-healthCheck-diagnosticsToken")" = \
  'diagnostic-token-that-must-not-enter-config'

old_config="$CAPTURE_DIR/old-config.yaml"
preserved_config="$CAPTURE_DIR/preserved-config.yaml"
printf '%s\n' 'alert:' '  slack:' '    title: "existing title"' \
  '    retry:' '      maxAttempts: 3' >"$old_config"
OLD_CONFIG_PATH="$old_config"
WRITTEN_PROVIDER_SECTIONS="|"
: >"$preserved_config"
preserve_provider_optional "$preserved_config" slack title string \
  "$CAPTURE_DIR"
preserve_provider_optional "$preserved_config" slack retry.maxAttempts \
  integer "$CAPTURE_DIR"
grep -Fq 'title: "existing title"' "$preserved_config"
grep -Fq 'maxAttempts: 3' "$preserved_config"

nested_config="$CAPTURE_DIR/nested.yaml"
: >"$nested_config"
WRITTEN_PROVIDER_SECTIONS="|"
write_provider_value "$nested_config" retry.maxAttempts integer 3
write_provider_value "$nested_config" retry.delay string 5s
[ "$(grep -c '^    retry:$' "$nested_config")" -eq 1 ] || {
  echo "nested provider settings were duplicated" >&2
  exit 1
}
grep -Fq '      maxAttempts: 3' "$nested_config"
grep -Fq '      delay: "5s"' "$nested_config"

kubectl() {
  case "$*" in
    *"get namespace"*) printf '%s' restricted ;;
    *"runAsNonRoot"*) printf '%s' true ;;
    *"readOnlyRootFilesystem"*) printf '%s' true ;;
    *"allowPrivilegeEscalation"*) printf '%s' false ;;
    *"seccompProfile.type"*) printf '%s' RuntimeDefault ;;
    *"capabilities.drop"*) printf '%s' ALL ;;
    *"defaultMode"*) printf '%s' 256 ;;
    *) return 1 ;;
  esac
}

deployment_name() {
  printf '%s' kwatch
}

verify_operational_security

if grep -Eq 'kubectl apply -f|helm (install|upgrade|uninstall)' \
    "$ROOT/docs/installation.md"; then
  echo "installation docs expose an unsupported lifecycle" >&2
  exit 1
fi

if [ -n "${KWATCH_BIN:-}" ]; then
  CONFIG_FILE="$CAPTURE_DIR/config.yaml" "$KWATCH_BIN" lint --strict
fi

echo "kwatch manager secret test passed"
