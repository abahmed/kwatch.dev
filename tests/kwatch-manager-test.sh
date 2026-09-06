#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CAPTURE_DIR=$(mktemp -d)
trap 'rm -rf "$CAPTURE_DIR"' EXIT
export CAPTURE_DIR

# shellcheck source=../static/kwatch.sh
source "$ROOT/static/kwatch.sh"
CONFIG_MOUNT_PATH="$CAPTURE_DIR"

kubectl() {
  printf '%s\n' 'Warning: permission preflight emitted an informational message' yes
}
check_access get pods namespace

ask() { printf '%s' y; }

kubectl() {
  case "$*" in
    *"get kwatchconfig kwatch"*) printf '%s' v1; return 0 ;;
    *) return 1 ;;
  esac
}
managed_install_present || {
  echo "managed configuration was not detected" >&2
  exit 1
}
[ "$(resolve_action install)" = upgrade ] || {
  echo "existing configuration was not protected from reinstall" >&2
  exit 1
}
(
  confirm_action() { return 1; }
  if resolve_action install >/dev/null 2>&1; then
    echo "install-to-upgrade conversion ignored confirmation" >&2
    exit 1
  fi
)

feature_file="$CAPTURE_DIR/features.tsv"
printf '%s\n' \
  '# kwatch feature catalog v1' \
  'core.detection.pods|runtime|Detect pod failures|' >"$feature_file"
load_feature_catalog_file "$feature_file"
[ "${#FEATURE_CATALOG[@]}" -eq 1 ] || {
  echo "feature catalog format was rejected" >&2
  exit 1
}

config_file="$CAPTURE_DIR/config.tsv"
printf '%s\n' \
  '# kwatch config catalog v1' \
  'heartbeatMonitor.url|string|empty|Operations|heartbeat URL|secret|' \
  'healthCheck.diagnosticsToken|string|empty|Security|diagnostic bearer token|secret|' \
  >"$config_file"
load_catalog_file "$config_file"
[ "${#CATALOG[@]}" -eq 2 ] || {
  echo "configuration catalog format was rejected" >&2
  exit 1
}

provider_file="$CAPTURE_DIR/providers.tsv"
printf '%s\n' \
  '# kwatch provider catalog v1' \
  'telegram|Telegram|token|string|true|true|||Bot token' \
  'telegram|Telegram|chatId|string|true|false|signed-integer||Chat ID' \
  'slack|Slack|webhook|string|false|true|url||Slack webhook URL|authentication|choice:webhook' \
  'slack|Slack|token|string|false|true|||Bot token|authentication|choice:token' \
  'slack|Slack|channel|string|false|false|||Channel|required-if:authentication=token' \
  'ilert|iLert|priority|string|false|false|one-of:LOW,HIGH,CRITICAL|HIGH|Priority' \
  >"$provider_file"
load_provider_catalog_file "$provider_file"
provider_count=$(printf '%s\n' "${PROVIDER_CATALOG[@]}" |
  cut -d'|' -f1 | sort -u | wc -l | tr -d ' ')
[ "$provider_count" -eq 3 ] || {
  echo "provider catalog fixture was not loaded" >&2
  exit 1
}
(
  ask() { printf '%s' HIGH; }
  [ "$(prompt_provider_value priority string false \
    one-of:LOW,HIGH,CRITICAL HIGH Priority)" = HIGH ]
)

choose_provider() {
  PROVIDER=telegram
}

ask() {
  case "$1" in
    *"Release channel"*) printf '%s' "${RELEASE_CHOICE:-1}" ;;
    *"Use release candidate"*|*"Use RC"*) printf 'y' ;;
    *anonymous*) printf 'n' ;;
    *chat*|*Chat*) printf '%s' '-100123' ;;
    *) printf '%s' "${2:-}" ;;
  esac
}

latest_version() { printf '%s' v0.10.5; }
latest_release_candidate() { printf '%s' v0.11.0-rc.7; }
release_catalog_available() { return 0; }

selected_release=$(select_release_version)
[ "$selected_release" = v0.10.5 ] || {
  echo "stable release was not selected by default" >&2
  exit 1
}
release_catalog_available() { [ "$1" != v0.10.5 ]; }
selected_release=$(select_release_version)
[ "$selected_release" = v0.11.0-rc.7 ] || {
  echo "release candidate was not selected when stable catalogs were missing" >&2
  exit 1
}
release_catalog_available() { return 0; }
RELEASE_CHOICE=2
selected_release=$(select_release_version)
[ "$selected_release" = v0.11.0-rc.7 ] || {
  echo "release candidate was not selected interactively" >&2
  exit 1
}
unset RELEASE_CHOICE

saved_catalog=("${CATALOG[@]}")
saved_feature_catalog=("${FEATURE_CATALOG[@]}")
saved_provider_catalog=("${PROVIDER_CATALOG[@]}")
load_catalog_for_version() {
  [ "$1" = v0.11.0-rc.7 ] || return 1
  CATALOG=('rc-setting|string|default|Test|RC setting|runtime|')
  CATALOG_SOURCE="release:$1"
}
load_feature_catalog_for_version() {
  [ "$1" = v0.11.0-rc.7 ] || return 1
  FEATURE_CATALOG=('rc-feature|runtime|RC feature|')
  FEATURE_CATALOG_SOURCE="release:$1"
}
load_provider_catalog_for_version() {
  [ "$1" = v0.11.0-rc.7 ] || return 1
  PROVIDER_CATALOG=('rc|RC|webhook|string|true|true|url||RC webhook')
  PROVIDER_CATALOG_SOURCE="release:$1"
}
maybe_load_catalog v0.10.5
[ "$CATALOG_SOURCE" = release:v0.11.0-rc.7 ] || {
  echo "old release did not fall back to the RC catalog" >&2
  exit 1
}
CATALOG=("${saved_catalog[@]}")
FEATURE_CATALOG=("${saved_feature_catalog[@]}")
PROVIDER_CATALOG=("${saved_provider_catalog[@]}")

deployment_name() { printf '%s' kwatch; }
kubectl() {
  case "$*" in
    *spec.template.spec.containers*)
      printf '%s' 'ghcr.io/abahmed/kwatch:v0.10.5@sha256:deadbeef'
      ;;
    *) return 1 ;;
  esac
}
[ "$(installed_version)" = v0.10.5 ] || {
  echo "image digest prevented old version detection" >&2
  exit 1
}

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

existing_config="$CAPTURE_DIR/existing-config.yaml"
preserved_providers="$CAPTURE_DIR/preserved-providers.yaml"
printf '%s\n' \
  'alert:' \
  '  telegram:' \
  '    chatId: "-100123"' \
  '  legacyprovider:' \
  '    endpoint: "https://legacy.example.test"' \
  'telemetry:' \
  '  enabled: false' >"$existing_config"
OLD_CONFIG_PATH="$existing_config"
CONFIGURED_PROVIDERS='|telegram|'
: >"$preserved_providers"
preserve_existing_providers "$preserved_providers" "$CAPTURE_DIR" true
grep -Fq 'legacyprovider:' "$preserved_providers"
if grep -Fq 'telegram:' "$preserved_providers"; then
  echo "edited provider was duplicated while preserving existing providers" >&2
  exit 1
fi
[ "$(old_config_value telemetry.enabled)" = false ] || {
  echo "existing telemetry preference was not detected" >&2
  exit 1
}

plain_secret_config="$CAPTURE_DIR/plain-secret-config.yaml"
secured_provider="$CAPTURE_DIR/secured-provider.yaml"
printf '%s\n' \
  'alert:' \
  '  slack:' \
  '    token: "legacy-plain-token"' >"$plain_secret_config"
OLD_CONFIG_PATH="$plain_secret_config"
CONFIGURED_PROVIDERS='|'
SECRET_ARGS=()
: >"$secured_provider"
preserve_existing_providers "$secured_provider" "$CAPTURE_DIR"
grep -Fq "token: \"\${file:$CAPTURE_DIR/slack-token}\"" \
  "$secured_provider"
if grep -Fq 'legacy-plain-token' "$secured_provider"; then
  echo "legacy provider credential remained in plain configuration" >&2
  exit 1
fi
test "$(cat "$CAPTURE_DIR/slack-token")" = 'legacy-plain-token'

legacy_resource="$CAPTURE_DIR/legacy-resource.yaml"
kubectl() {
  case "$*" in
    *"get configmap kwatch"*)
      printf '%s\n' \
        'alert:' \
        '  slack:' \
        '    token: "legacy-token"' \
        'heartbeatMonitor:' \
        '  enabled: true' \
        '  url: "https://secret.example.test"' \
        'workers: 5'
      ;;
    *"apply -f "*)
      cp "${*: -1}" "$legacy_resource"
      ;;
    *) return 1 ;;
  esac
}
migrate_legacy_config_resource
grep -Fq '  workers: 5' "$legacy_resource"
grep -Fq '    enabled: true' "$legacy_resource"
if grep -Fq 'legacy-token' "$legacy_resource" ||
  grep -Fq 'secret.example.test' "$legacy_resource"; then
  echo "legacy credential entered KwatchConfig during migration" >&2
  exit 1
fi

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
