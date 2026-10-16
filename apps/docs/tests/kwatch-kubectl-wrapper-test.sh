#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CAPTURE_DIR=$(mktemp -d)
trap 'rm -rf "$CAPTURE_DIR"' EXIT

cat >"$CAPTURE_DIR/kubectl" <<'EOF'
#!/usr/bin/env bash
if [[ " $* " == *" fail "* ]]; then
  printf '%s\n' 'partial-output'
  printf '%s\n' 'Error: forbidden' >&2
  exit 7
fi
printf '%s\n' 'machine-output'
printf '%s\n' 'Warning: informational' >&2
EOF
chmod +x "$CAPTURE_DIR/kubectl"
PATH="$CAPTURE_DIR:$PATH"

# shellcheck source=../static/kwatch.sh
source "$ROOT/static/kwatch.sh"
SELECTED_CONTEXT=test

stderr_file="$CAPTURE_DIR/stderr"
output=$(kubectl get pods 2>"$stderr_file")
[ "$output" = machine-output ] || {
  echo "kubectl warning contaminated stdout" >&2
  exit 1
}
grep -Fq 'Warning: informational' "$stderr_file"

failure_output="$CAPTURE_DIR/failure-output"
set +e
kubectl fail >"$failure_output" 2>"$stderr_file"
rc=$?
set -e
[ "$rc" -ne 0 ] || {
  echo "kubectl wrapper hid a command failure" >&2
  exit 1
}
[ "$rc" -eq 7 ] || {
  echo "kubectl wrapper changed the failure exit code" >&2
  exit 1
}
grep -Fq 'partial-output' "$failure_output"
grep -Fq 'Error: forbidden' "$stderr_file"

echo "kwatch kubectl wrapper test passed"
