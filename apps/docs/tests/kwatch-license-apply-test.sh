#!/usr/bin/env bash
# Adding a license key to a running install must roll the Pod out once and
# never delete anything, including on a rollout timeout. kubectl is a stub
# that records every call; the real restart and rollout-wait code runs.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CAPTURE_DIR=$(mktemp -d)
trap 'rm -rf "$CAPTURE_DIR"' EXIT
export NO_COLOR=1 KWATCH_PLAIN_UI=true

# shellcheck source=../../web/public/kwatch.sh
source "$ROOT/../web/public/kwatch.sh"
NAMESPACE=kwatch
RELEASE=kwatch

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_contains() { grep -Fq -- "$2" <<<"$1" || fail "$3: missing '$2' in: $1"; }
assert_lacks() { ! grep -Fq -- "$2" <<<"$1" || fail "$3: unexpected '$2' in: $1"; }
count() { grep -Fc -- "$1" "$LOG" || true; }

LOG="$CAPTURE_DIR/kubectl.log"
KEY="KW1-$(printf 'payload' | base64 | tr -d '=\n').c2ln"
ENV_WIRED=true      # rc.19 manifests already carry the optional secretKeyRef
HAVE_LICENSE_RBAC=false
ROLLOUT_OK=true

kubectl() {
  printf '%s\n' "$*" >>"$LOG"
  case "$*" in
    *"apply -f -"*) printf 'applied %s\n' \
      "$(command cat | grep '^kind:' | head -1)" >>"$LOG" ;;
    *"create secret generic"*"--dry-run=client"*) printf '%s\n' 'kind: Secret' ;;
    *"create secret generic kwatch-license-instance"*) HAVE_LICENSE_RBAC=true ;;
    *"get role kwatch-license"*|*"get rolebinding kwatch-license"*|\
    *"get secret kwatch-license-instance"*)
      [ "$HAVE_LICENSE_RBAC" = true ] || return 1 ;;
    *"jsonpath"*"serviceAccountName"*) printf '%s' kwatch ;;
    *"containers[*]}{.name}"*) printf '%s\n' kwatch ;;
    *"secretKeyRef.name}"*)
      [ "$ENV_WIRED" = true ] && printf '%s' kwatch-license ;;
    *"create configmap"*) printf '%s\n' 'kind: ConfigMap' ;;
    *"rollout status"*) [ "$ROLLOUT_OK" = true ] || return 1 ;;
    *"get lease"*"holderIdentity"*) printf '%s' kwatch-pod ;;
    *"get pod kwatch-pod"*) printf '%s' True ;;
  esac
  return 0
}
deployment_name() { printf '%s' kwatch; }
deployment_overrides_read() { DEPLOYMENT_OVERRIDES=""; }
sleep() { :; }

rollouts() { echo $(( $(count "rollout restart") + $(count "patch deployment") )); }
assert_no_deletes() {
  local log
  log=$(cat "$LOG")
  assert_lacks "$log" "delete pod" "$1"
  assert_lacks "$log" "delete deployment" "$1"
  assert_lacks "$log" "--replicas" "$1"
  assert_lacks "$log" "scale " "$1"
  assert_lacks "$log" "rollout undo" "$1"
  assert_lacks "$log" "delete -f" "$1"
}

# 1. rc.19 install (env already wired, no license RBAC): the missing Role,
#    RoleBinding and instance Secret are added first, then one restart.
: >"$LOG"
license_apply_key "$KEY" full >/dev/null 2>&1 || fail "apply on an old install failed"
log=$(cat "$LOG")
assert_contains "$log" "get role kwatch-license" "RBAC checked"
assert_contains "$log" "applied kind: Role" "Role applied"
assert_contains "$log" "applied kind: RoleBinding" "RoleBinding applied"
assert_contains "$log" "create secret generic kwatch-license-instance" "instance Secret created"
[ "$(rollouts)" -eq 1 ] || fail "expected one rollout, saw $(rollouts)"
assert_no_deletes "old install"
rbac_line=$(grep -n 'create secret generic kwatch-license-instance' "$LOG" | head -1 | cut -d: -f1)
restart_line=$(grep -n 'rollout restart' "$LOG" | head -1 | cut -d: -f1)
[ "$rbac_line" -lt "$restart_line" ] || fail "RBAC must exist before kwatch restarts"

# 2. Env not wired yet: the patch is the only rollout trigger.
: >"$LOG"
ENV_WIRED=false
license_apply_key "$KEY" full >/dev/null 2>&1 || fail "apply with unwired env failed"
[ "$(count 'patch deployment kwatch --type=strategic')" -eq 1 ] || fail "env was not patched"
assert_lacks "$(cat "$LOG")" "rollout restart" "a second rollout was triggered"
[ "$(rollouts)" -eq 1 ] || fail "expected one rollout, saw $(rollouts)"
assert_no_deletes "unwired env"

# 3. Existing RBAC is left alone (the instance Secret holds kwatch's key).
: >"$LOG"
ENV_WIRED=true
license_apply_key "$KEY" full >/dev/null 2>&1 || fail "replace failed"
assert_lacks "$(cat "$LOG")" "create secret generic kwatch-license-instance" "instance Secret rewritten"
assert_lacks "$(cat "$LOG")" "applied kind: Role" "RBAC re-applied although present"

# 4. A rollout timeout reports and leaves everything as it is.
for wired in true false; do
  : >"$LOG"
  ENV_WIRED=$wired
  ROLLOUT_OK=false
  rc=0
  out=$(license_apply_key "$KEY" full 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail "a timed out rollout must fail (wired=$wired)"
  assert_contains "$out" "Nothing was deleted or repaired" "timeout message (wired=$wired)"
  [ "$(rollouts)" -eq 1 ] || fail "timeout started another rollout (wired=$wired)"
  assert_no_deletes "timeout (wired=$wired)"
  ROLLOUT_OK=true
done

echo "kwatch license apply test passed"
