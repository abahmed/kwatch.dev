#!/usr/bin/env bash
# Regression: migration_notice must return 0 under set -e when the last
# deprecated catalog entry is unset (it used to end on a false [ -n ] test).
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../public/kwatch.sh
source "$ROOT/public/kwatch.sh"

set -e
CATALOG=(
  "a.old|string||core|old setting|deprecated|a.new"
  "clusterCheckins|boolean|false|core|unset deprecated setting|deprecated|none"
)
CATALOG_VERSION=1
kubectl() { return 0; }
config_value() { [ "$1" = a.old ] && echo set || true; }

out=$(migration_notice 2>&1)
grep -Fq 'Deprecated config detected: a.old' <<<"$out"
if grep -Fq 'clusterCheckins' <<<"$out"; then
  echo "unset deprecated entry was reported" >&2
  exit 1
fi

# Every deprecated entry unset: still success.
config_value() { return 0; }
migration_notice >/dev/null 2>&1
echo "migration-notice-test: ok"
