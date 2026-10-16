#!/usr/bin/env bash
# License / Pro behaviour of static/kwatch.sh: key decoding and masking, the
# expired-key warning, the Secret and env wiring, the Community provider cap
# and what a backup includes.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CAPTURE_DIR=$(mktemp -d)
trap 'rm -rf "$CAPTURE_DIR"' EXIT
export NO_COLOR=1 KWATCH_PLAIN_UI=true

# shellcheck source=../static/kwatch.sh
source "$ROOT/static/kwatch.sh"
NAMESPACE=kwatch
RELEASE=kwatch

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "$3: expected '$2', got '$1'"; }
assert_contains() { grep -Fq -- "$2" <<<"$1" || fail "$3: missing '$2' in: $1"; }
assert_lacks() { ! grep -Fq -- "$2" <<<"$1" || fail "$3: unexpected '$2' in: $1"; }

# base64url without padding, as the key format uses.
b64url() { printf '%s' "$1" | base64 | tr -d '\n=' | tr '+/' '-_'; }
make_key() {
  local payload
  payload=$(printf '{"v":1,"kid":"k1","lid":"l-1","acc":"%s","plan":"%s","iat":1700000000,"exp":%s,"max":1}' \
    "${3:->>>???}" "$1" "$2")
  printf 'KW1-%s.%s' "$(b64url "$payload")" "$(b64url signature-bytes)"
}

NOW=1800000000
license_now() { printf '%s' "$NOW"; }
FUTURE=$((NOW + 30 * 86400 + 3600))
VALID_KEY=$(make_key pro "$FUTURE")
EXPIRED_KEY=$(make_key trial 1700000000)

# --- payload decode, with and without jq ------------------------------------
decode_checks() {
  local payload
  payload=$(license_payload_json "$VALID_KEY") || fail "valid key did not decode"
  assert_eq "$(license_json_field "$payload" plan)" pro "plan"
  assert_eq "$(license_json_field "$payload" exp)" "$FUTURE" "exp"
  assert_eq "$(license_json_field "$payload" max)" 1 "max"
  assert_eq "$(license_json_field "$payload" acc)" '>>>???' "acc"
  license_inspect "$VALID_KEY" || fail "valid key was rejected"
  assert_eq "$LICENSE_PLAN" pro "inspected plan"
  assert_eq "$LICENSE_DAYS_LEFT" 30 "days left"
}
decode_checks
if command -v jq >/dev/null 2>&1; then
  license_have_jq() { return 0; }
  decode_checks
fi
license_have_jq() { return 1; }
decode_checks

# The alphabet and padding repairs: this payload encodes with '-' and '_'.
case "$(b64url '>>>???')" in
  *-*|*_*) ;;
  *) fail "fixture no longer exercises the url-safe alphabet" ;;
esac
assert_eq "$(base64url_decode "$(b64url '>>>???')")" '>>>???' "url-safe decode"
for sample in a ab abc abcd abcde; do
  assert_eq "$(base64url_decode "$(b64url "$sample")")" "$sample" "padding for '$sample'"
done

# --- rejected keys ----------------------------------------------------------
for bad in "" "nonsense" "KW2-abc.def" "KW1-onlyonepart" "KW1-a.b.c" \
  "KW1-.sig" "KW1-payload." "KW1-!!!.sig" "KW1-$(b64url 'not json').sig"; do
  if license_payload_json "$bad" >/dev/null; then
    fail "accepted malformed key '$bad'"
  fi
  rc=0
  license_inspect "$bad" || rc=$?
  assert_eq "$rc" 1 "inspect of '$bad'"
done

# --- masking ----------------------------------------------------------------
masked=$(license_mask "$VALID_KEY")
assert_eq "$masked" "KW1-…${VALID_KEY: -6}" "mask"
assert_lacks "$masked" "${VALID_KEY:4:12}" "mask leaks the payload"
assert_eq "$(license_mask short)" 'KW1-…' "mask of a short value"

# --- expired key ------------------------------------------------------------
rc=0
warning=$(license_report_key "$EXPIRED_KEY" 2>&1) || rc=$?
assert_eq "$rc" 2 "expired status code"
assert_contains "$warning" "expired on $(license_date 1700000000)" "expired warning"
assert_contains "$warning" 2023-11-14 "expiry date"
rc=0
ok=$(license_report_key "$VALID_KEY" 2>&1) || rc=$?
assert_eq "$rc" 0 "valid status code"
assert_contains "$ok" "30 days left" "days left message"
assert_lacks "$ok" "$VALID_KEY" "full key was printed"

# --- Secret and env wiring --------------------------------------------------
KUBECTL_LOG="$CAPTURE_DIR/kubectl.log"
: >"$KUBECTL_LOG"
LICENSE_SECRET_PRESENT=false
kubectl() {
  local arg
  printf '%s\n' "$*" >>"$KUBECTL_LOG"
  case "$*" in
    *"create secret generic"*)
      for arg in "$@"; do
        case "$arg" in
          --from-file=license-key=*)
            cp "${arg#--from-file=license-key=}" "$CAPTURE_DIR/stored-key" ;;
        esac
      done
      printf '%s\n' 'apiVersion: v1' 'kind: Secret'
      ;;
    *"create configmap"*) printf '%s\n' 'apiVersion: v1' 'kind: ConfigMap' ;;
    *"apply -f -"*) command cat >/dev/null ;;
    *"get secret kwatch-license-instance"*) ;;
    *"get secret kwatch-license"*"go-template"*)
      if [ "$LICENSE_SECRET_PRESENT" = true ]; then
        printf '%s' "$(printf '%s' "$VALID_KEY" | base64 | tr -d '\n')"
      fi
      ;;
    *"get secret kwatch-license"*)
      [ "$LICENSE_SECRET_PRESENT" = true ] && printf '%s\n' secret/kwatch-license
      ;;
    *"get deployment kwatch"*"containers[*]}{.name}"*) printf '%s\n' kwatch ;;
    *"get kwatchconfig"*) printf '%s' '{"kind":"KwatchConfig"}' ;;
  esac
  return 0
}
deployment_name() { printf '%s' kwatch; }
wait_for_kwatch_rollout() { printf 'wait %s\n' "$1" >>"$KUBECTL_LOG"; }
restart_kwatch() { printf 'restart\n' >>"$KUBECTL_LOG"; }

license_apply_key "$VALID_KEY" full >/dev/null 2>&1
log=$(cat "$KUBECTL_LOG")
assert_contains "$log" "create secret generic kwatch-license --from-file=license-key=" "secret create"
assert_contains "$log" "--dry-run=client -o yaml" "secret dry-run"
assert_contains "$log" "apply -f -" "secret apply"
assert_eq "$(cat "$CAPTURE_DIR/stored-key")" "$VALID_KEY" "stored key"
assert_contains "$log" "patch deployment kwatch --type=strategic" "env patch"
assert_contains "$log" '"name":"KWATCH_LICENSE_KEY"' "env name"
assert_contains "$log" '"secretKeyRef":{"name":"kwatch-license","key":"license-key","optional":true}' "secretKeyRef"
assert_contains "$log" "kwatch.sh/deployment-overrides=license=1" "override recorded"
assert_contains "$log" "wait kwatch" "rollout wait"
assert_lacks "$log" "$VALID_KEY" "key leaked into a kubectl argument"

# A custom release name flows through to the Secret reference.
assert_contains "$(RELEASE=payments license_env_patch payments)" '"name":"payments-license"' "release-named secret"
assert_contains "$(license_env_patch kwatch remove)" '"$patch":"delete"' "removal patch"

# The marker survives sanitising and sizing rewrites, and is not "sizing".
DEPLOYMENT_OVERRIDES="requests.cpu=100m;license=1"
assert_eq "$(deployment_overrides_sanitize "$DEPLOYMENT_OVERRIDES")" "requests.cpu=100m;license=1" "sanitize keeps marker"
assert_eq "$(deployment_overrides_sanitize 'license=yes' 2>/dev/null)" "" "sanitize drops a bad marker"
assert_eq "$(overrides_without_license)" "requests.cpu=100m" "sizing without marker"
license_overrides_set off
assert_eq "$DEPLOYMENT_OVERRIDES" "requests.cpu=100m" "marker removed"
license_overrides_set on
license_overrides_set on
assert_eq "$DEPLOYMENT_OVERRIDES" "requests.cpu=100m;license=1" "marker added once"

# Upgrades re-apply the marker to the freshly downloaded manifest.
manifest="$CAPTURE_DIR/deploy.yaml"
write_manifest() {
  {
    printf '%s\n' 'kind: Deployment' 'spec:' '  template:' '    spec:' \
      '      containers:' '      - name: kwatch' \
      '        image: ghcr.io/abahmed/kwatch:v1.0.0'
    if [ "$1" = with-env ]; then
      printf '%s\n' '        env:' '          - name: CONFIG_FILE' \
        '            value: "/config/config.yaml"'
    fi
    printf '%s\n' '        resources:' '          limits:' \
      '            memory: "256Mi"' '            cpu: "500m"'
  } >"$manifest"
}
write_manifest with-env
DEPLOYMENT_OVERRIDES="license=1"
apply_deployment_overrides_to_manifest "$manifest" || fail "marker-only overrides failed to apply"
env_block=$(grep -A6 'KWATCH_LICENSE_KEY' "$manifest")
assert_contains "$env_block" "secretKeyRef:" "manifest secretKeyRef"
assert_contains "$env_block" "name: kwatch-license" "manifest secret name"
assert_contains "$env_block" "key: license-key" "manifest key"
assert_contains "$env_block" "optional: true" "manifest optional"
[ "$(grep -c 'name: CONFIG_FILE' "$manifest")" -eq 1 ] || fail "existing env was disturbed"
# Applying twice must not duplicate the entry.
apply_deployment_overrides_to_manifest "$manifest"
[ "$(grep -c 'name: KWATCH_LICENSE_KEY' "$manifest")" -eq 1 ] || fail "env was duplicated"
# The first env entry is still under the same `env:` header.
[ "$(grep -c '^        env:$' "$manifest")" -eq 1 ] || fail "env header was duplicated"

write_manifest no-env
apply_deployment_overrides_to_manifest "$manifest" || fail "manifest without env failed"
grep -q '^        env:$' "$manifest" || fail "env header not created"
grep -q 'name: KWATCH_LICENSE_KEY' "$manifest" || fail "env not added to env-less manifest"
grep -q '^        resources:$' "$manifest" || fail "resources were lost"

# Without the marker the manifest is untouched.
write_manifest with-env
DEPLOYMENT_OVERRIDES="requests.cpu=100m;requests.memory=64Mi;limits.cpu=500m;limits.memory=256Mi"
apply_deployment_overrides_to_manifest "$manifest" || true
! grep -q KWATCH_LICENSE_KEY "$manifest" || fail "env injected without the marker"

# --- removal ----------------------------------------------------------------
: >"$KUBECTL_LOG"
confirm_change() { return 0; }
LICENSE_SECRET_PRESENT=true
license_remove_flow >/dev/null 2>&1
log=$(cat "$KUBECTL_LOG")
assert_contains "$log" '"$patch":"delete"' "env removed"
assert_contains "$log" "delete secret kwatch-license --ignore-not-found" "secret deleted"
assert_lacks "$log" "kwatch-license-instance" "removal touched the instance Secret"

# --- move to this cluster ---------------------------------------------------
saved_kubectl=$(declare -f kubectl)
saved_pod_name=$(declare -f kwatch_pod_name)
: >"$KUBECTL_LOG"
confirm_change() { return 0; }
kwatch_pod_name() { printf '%s' kwatch-abc; }
MOVE_RC=0
kubectl() {
  printf '%s\n' "$*" >>"$KUBECTL_LOG"
  case "$*" in
    *"license move"*)
      if [ "$MOVE_RC" -eq 0 ]; then
        echo "License lic_…1234 is now active on this cluster."
      else
        echo "ERROR: transfer limit reached: a license can move 3 times in 30 days. A slot frees up in 3 days." >&2
      fi
      return "$MOVE_RC"
      ;;
    *"get secret kwatch-license"*"go-template"*)
      [ "$LICENSE_SECRET_PRESENT" = true ] && printf '%s' "$(printf '%s' "$VALID_KEY" | base64 | tr -d '\n')"
      ;;
    *"get secret kwatch-license"*)
      [ "$LICENSE_SECRET_PRESENT" = true ] && printf '%s\n' secret/kwatch-license
      ;;
  esac
  return 0
}
LICENSE_SECRET_PRESENT=true
out=$(license_move_flow 2>&1)
assert_contains "$(cat "$KUBECTL_LOG")" "-n kwatch exec kwatch-abc -- kwatch license move" "move runs in the Pod"
assert_contains "$out" "now active on this cluster" "move result is shown"
MOVE_RC=1
rc=0
out=$(license_move_flow 2>&1) || rc=$?
[ "$rc" -ne 0 ] || fail "a refused move must fail"
assert_contains "$out" "A slot frees up in 3 days." "refusal is shown"
assert_contains "$out" "transfer it at https://kwatch.dev/account" "refusal points at the website"
# Without a key there is nothing to move and the Pod is not touched.
: >"$KUBECTL_LOG"
LICENSE_SECRET_PRESENT=false
out=$(license_move_flow 2>&1)
assert_contains "$out" "Add it first" "no key"
assert_lacks "$(cat "$KUBECTL_LOG")" "license move" "no key reached the Pod"
LICENSE_SECRET_PRESENT=true
# Declining the confirmation changes nothing.
: >"$KUBECTL_LOG"
confirm_change() { return 1; }
out=$(license_move_flow 2>&1)
assert_contains "$out" "Nothing was changed" "declined"
assert_lacks "$(cat "$KUBECTL_LOG")" "license move" "declined move reached the Pod"
confirm_change() { return 0; }
eval "$saved_kubectl"
eval "$saved_pod_name"

# --- status fallback -------------------------------------------------------
# Exact output of `kwatch license status` (internal/app/license_cli.go).
CLI_VALID=$'Key:     KW1-…abcd\nState:   valid key (activation is not checked here)\nPlan:    pro\nLicense: l-…1\nExpires: 2027-01-01 (30 days left)'
CLI_EXPIRED=$'Key:     KW1-…abcd\nState:   expired\nPlan:    trial\nLicense: l-…1\nExpires: 2026-01-01 (0 days left)'
CLI_INVALID=$'Key:     KW1-…abcd\nState:   invalid (bad signature)'
CLI_NONE='No license key is configured: kwatch runs the Community edition.'
out=$(kwatch_license_cli_to_status "$CLI_VALID")
assert_contains "$out" "Edition: pro" "cli edition"
assert_contains "$out" "License: valid key" "cli state"
out=$(kwatch_license_cli_to_status "$CLI_EXPIRED")
assert_contains "$out" "Edition: Community" "cli expired edition"
assert_eq "$(license_state_word "$(license_status_lines "$out")")" expired "cli expired word"
out=$(kwatch_license_cli_to_status "$CLI_INVALID")
assert_eq "$(license_state_word "$(license_status_lines "$out")")" invalid "cli invalid word"
out=$(kwatch_license_cli_to_status "$CLI_NONE")
assert_contains "$out" "Edition: Community" "cli no key edition"
kwatch_license_cli_to_status "garbage" >/dev/null && fail "garbage parsed"

PROXY_TEXT=""; EXEC_TEXT=""
kwatch_status_proxy() { [ -n "$PROXY_TEXT" ] && printf '%s\n' "$PROXY_TEXT"; }
kwatch_status_exec() { [ -n "$EXEC_TEXT" ] && printf '%s\n' "$EXEC_TEXT"; }
PROXY_TEXT=$'Edition: Pro\nLicense: active'
EXEC_TEXT="$CLI_NONE"
assert_contains "$(kwatch_status_text)" "Edition: Pro" "proxy wins"
PROXY_TEXT=""
assert_contains "$(kwatch_status_text)" "Edition: Community" "exec fallback"
EXEC_TEXT="$CLI_VALID"
out=$(license_print_status "$(kwatch_status_text)" 2>&1)
assert_contains "$out" "Edition: pro" "fallback printed"
EXEC_TEXT=""
kwatch_status_text >/dev/null && fail "no source should fail"
out=$(license_status_section 2>&1)
assert_contains "$out" "license state unavailable (enable healthCheck.statusEndpoint for full status)" "unavailable message"

# --- Community provider cap -------------------------------------------------
expected='Community sends to 1 provider — extra providers stay inactive until you add a Pro license (free 90-day trial: https://kwatch.dev/signup?src=installer)'
assert_eq "$(community_provider_cap_message)" "$expected" "cap message"
STATUS_TEXT=$'Edition: Community\nLicense: community'
kwatch_status_text() { printf '%s\n' "$STATUS_TEXT"; }
LICENSE_COMMUNITY_CACHE=""
out=$(warn_community_provider_cap 2>&1)
assert_contains "$out" "$expected" "community warning"
STATUS_TEXT=$'Edition: Pro\nLicense: active'
LICENSE_COMMUNITY_CACHE=""
out=$(warn_community_provider_cap 2>&1)
assert_eq "$out" "" "pro edition warned"
# Without /status the Secret decides.
kwatch_status_text() { return 1; }
LICENSE_SECRET_PRESENT=false
LICENSE_COMMUNITY_CACHE=""
out=$(warn_community_provider_cap 2>&1)
assert_contains "$out" "$expected" "unknown edition without a key"
LICENSE_SECRET_PRESENT=true
LICENSE_COMMUNITY_CACHE=""
out=$(warn_community_provider_cap 2>&1)
assert_eq "$out" "" "unknown edition with a key warned"

# --- status wording ---------------------------------------------------------
assert_eq "$(license_state_word 'License: expired (was active)')" expired "state word"
assert_eq "$(license_state_word 'License: conflict')" conflict "conflict word"
assert_eq "$(license_state_word 'Edition: Community')" community "community word"
assert_contains "$(license_state_hint conflict)" \
  "license is bound to another cluster — choose \"Move license to this cluster\" in License / Pro, or transfer it at https://kwatch.dev/account" "conflict hint"
out=$(license_print_status $'Edition: Pro\nLicense: conflict\nPro features configured but inactive: routes' 2>&1)
assert_contains "$out" "Move license to this cluster" "status conflict suggests the move option"
assert_contains "$out" "transfer it at https://kwatch.dev/account" "status conflict hint"
assert_contains "$out" "Pro features configured but inactive: routes" "inactive line"

# --- PRO badge --------------------------------------------------------------
for path in routes routing templates severityByReason severityByOwnerKind \
  maintenance maintenance.enabled runbooks auditLog heartbeatMonitor \
  activeProbeMonitor namespaceSelector reasons; do
  config_path_is_pro "$path" || fail "$path should be marked PRO"
done
for path in telemetry maxRecentLogs routesNot; do
  ! config_path_is_pro "$path" || fail "$path should not be marked PRO"
done

# --- backups ----------------------------------------------------------------
backup_with() {
  : >"$KUBECTL_LOG"
  rm -f "$CAPTURE_DIR/stored-key"
  LAST_BACKUP_TIMESTAMP=""
  LICENSE_SECRET_PRESENT="$1"
  prune_config_backups() { :; }
  backup_config
}
backup_with true
log=$(cat "$KUBECTL_LOG")
assert_contains "$log" "create secret generic kwatch-config-" "backup Secret"
assert_contains "$log" "--from-file=license-key=" "backup includes the license"
assert_contains "$log" "get secret kwatch-license " "backup reads the license Secret"
assert_lacks "$log" "kwatch-license-instance" "backup touched the instance Secret"
assert_lacks "$log" "$VALID_KEY" "backup put the key on a command line"
assert_eq "$(cat "$CAPTURE_DIR/stored-key")" "$VALID_KEY" "backed-up key"
backup_with false
log=$(cat "$KUBECTL_LOG")
assert_lacks "$log" "--from-file=license-key" "backup without a license mentions one"
assert_lacks "$log" "kwatch-license-instance" "backup touched the instance Secret"

echo "kwatch license test passed"
