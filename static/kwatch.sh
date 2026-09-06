#!/usr/bin/env bash
set -euo pipefail

BASE_URL="https://raw.githubusercontent.com/abahmed/kwatch"
RELEASES_URL="https://api.github.com/repos/abahmed/kwatch/releases/latest"
RELEASES_LIST_URL="https://api.github.com/repos/abahmed/kwatch/releases?per_page=30"
DEFAULT_NAMESPACE="kwatch"
DEFAULT_RELEASE="kwatch"
CATALOG_VERSION=1
FEATURE_CATALOG_VERSION=1
PROVIDER_CATALOG_VERSION=1
MAX_KUBECTL_ATTEMPTS=3
SELECTED_CONTEXT=""
FEATURE_CATALOG_SOURCE="unavailable"
FEATURE_CATALOG=()
PROVIDER_CATALOG_SOURCE="unavailable"
CATALOG_SOURCE="unavailable"
CATALOG=()
PROVIDER_CATALOG=()
CONFIG_MOUNT_PATH="/config"



if [ -t 2 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != dumb ]; then
  UI_RESET=$'\033[0m'
  UI_BOLD=$'\033[1m'
  UI_CYAN=$'\033[36m'
  UI_GREEN=$'\033[32m'
  UI_YELLOW=$'\033[33m'
  UI_RED=$'\033[31m'
  UI_DIM=$'\033[2m'
  UI_CLEAR=$'\033[K'
  UI_CLEAR_LINE=$'\033[2K\r'
else
  UI_RESET=""
  UI_BOLD=""
  UI_CYAN=""
  UI_GREEN=""
  UI_YELLOW=""
  UI_RED=""
  UI_DIM=""
  UI_CLEAR=""
  UI_CLEAR_LINE=""
fi

ui_info() { printf '%s%s%s\n' "$UI_CYAN" "$*" "$UI_RESET" >&2; }
ui_success() { printf '%s%s%s\n' "$UI_GREEN" "$*" "$UI_RESET" >&2; }
ui_warn() { printf '%s%s%s\n' "$UI_YELLOW" "$*" "$UI_RESET" >&2; }
ui_error() { printf '%s%s%s\n' "$UI_RED" "$*" "$UI_RESET" >&2; }

with_loading() {
  local label="$1"; shift
  local output_file pid frame=0 index char rc
  local -a spinner_frames=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
  if [ ! -t 2 ] || [ "${KWATCH_PLAIN_UI:-false}" = true ]; then
    "$@"
    return
  fi
  output_file=$(mktemp)
  "$@" >"$output_file" 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    index=$((frame % ${#spinner_frames[@]}))
    char="${spinner_frames[$index]}"
    printf '%s%s⏳ %s %s%s' "$UI_CLEAR_LINE" "$UI_CYAN" "$label" "$char" "$UI_CLEAR" >&2
    sleep 0.1
    frame=$((frame + 1))
  done
  if wait "$pid"; then
    rc=0
  else
    rc=$?
  fi
  if [ "$rc" -eq 0 ]; then
    printf '%s%s✅ %s%s%s\n' "$UI_CLEAR_LINE" "$UI_GREEN" "$label" "$UI_RESET" "$UI_CLEAR" >&2
    cat "$output_file"
    rm -f "$output_file"
    return 0
  fi
  printf '%s%s❌ %s%s%s\n' "$UI_CLEAR_LINE" "$UI_RED" "$label" "$UI_RESET" "$UI_CLEAR" >&2
  if [ -s "$output_file" ]; then
    cat "$output_file" >&2
  fi
  rm -f "$output_file"
  return "$rc"
}

die() { ui_error "Error: $*"; exit 1; }
need() { type -P "$1" >/dev/null 2>&1 || die "'$1' is required"; }
require_tools() { need kubectl; need curl; }
ask() {
  local prompt="$1" default="${2:-}" answer
  [ -n "$default" ] && prompt="$prompt [$default]"
  printf '%s%s%s: ' "$UI_BOLD" "$prompt" "$UI_RESET" >&2
  IFS= read -r answer
  printf '%s' "${answer:-$default}"
}
ask_secret() {
  local prompt="$1" answer
  printf '%s%s%s: ' "$UI_BOLD" "$prompt" "$UI_RESET" >&2
  IFS= read -r -s answer
  printf '\n' >&2
  printf '%s' "$answer"
}
ask_yes_no() {
  local prompt="$1" default="$2" answer
  while true; do
    answer=$(ask "$prompt" "$default")
    case "$answer" in
      y|Y|yes|Yes) printf 'true'; return 0 ;;
      n|N|no|No) printf 'false'; return 0 ;;
      *) ui_warn "⚠️ Please answer yes or no." ;;
    esac
  done
}
valid_name() { [[ "$1" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; }
valid_kubernetes_name() { [ "${#1}" -le 40 ] && valid_name "$1"; }
valid_release_version() { [[ "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-rc\.[0-9]+)?$ ]]; }

is_transient_kubectl_error() {
  case "$1" in
    *[Tt]imeout*|*[Uu]navailable*|*"connection refused"*|*"connection reset"*|*"too many requests"*|*"rate limit"*|*"embedded etcd"*|*"leader changed"*) return 0 ;;
  esac
  return 1
}

kubectl() {
  local attempt=1 output rc retryable=true
  [ -t 0 ] || retryable=false
  while [ "$attempt" -le "$MAX_KUBECTL_ATTEMPTS" ]; do
    if output=$(command kubectl --context "$SELECTED_CONTEXT" "$@" 2>&1); then
      printf '%s\n' "$output"
      return 0
    fi
    rc=$?
    printf '%s\n' "$output" >&2
    if ! is_transient_kubectl_error "$output" || [ "$attempt" = "$MAX_KUBECTL_ATTEMPTS" ] || [ "$retryable" = false ]; then
      return "$rc"
    fi
    echo "Temporary Kubernetes error; retrying ($((attempt + 1))/$MAX_KUBECTL_ATTEMPTS)..." >&2
    sleep $((attempt * 2))
    attempt=$((attempt + 1))
  done
  return 1
}

select_context() {
  local current choice index context server default_choice=""
  local -a contexts=()
  while IFS= read -r context; do
    [ -n "$context" ] && contexts+=("$context")
  done < <(command kubectl config get-contexts -o name 2>/dev/null || true)
  [ "${#contexts[@]}" -gt 0 ] || die "no Kubernetes contexts found in kubeconfig"
  current=$(command kubectl config current-context 2>/dev/null || true)

  if [ "${#contexts[@]}" -eq 1 ]; then
    SELECTED_CONTEXT="${contexts[0]}"
  else
    [ -t 0 ] || die "multiple Kubernetes contexts found; an interactive terminal is required to choose one"
    echo >&2
    ui_info "🧭 Select the Kubernetes cluster to manage:"
    for index in "${!contexts[@]}"; do
      if [ "${contexts[$index]}" = "$current" ]; then
        echo "  $((index + 1))) ${contexts[$index]} (current)" >&2
        default_choice=$((index + 1))
      else
        echo "  $((index + 1))) ${contexts[$index]}" >&2
      fi
    done
    [ -n "$default_choice" ] || default_choice=1
    while true; do
      choice=$(ask "Cluster number (Enter keeps current)" "$default_choice")
      if [[ "$choice" =~ ^[0-9]+$ ]] &&
        [ "$choice" -ge 1 ] && [ "$choice" -le "${#contexts[@]}" ]; then
        SELECTED_CONTEXT="${contexts[$((choice - 1))]}"
        break
      fi
      ui_warn "⚠️ Choose a number from 1 to ${#contexts[@]}."
    done
  fi

  server=$(command kubectl --context "$SELECTED_CONTEXT" config view --minify \
    -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true)
  [ -n "$server" ] || die "could not read the Kubernetes server for context '$SELECTED_CONTEXT'"
  ui_success "Selected cluster: $SELECTED_CONTEXT"
  ui_info "Kubernetes server: $server"
}

catalog_entry() {
  local wanted="$1" entry path type default category description status replacement
  for entry in "${CATALOG[@]}"; do
    IFS='|' read -r path type default category description status replacement <<<"$entry"
    [ "$path" = "$wanted" ] && { printf '%s\n' "$entry"; return; }
  done
}

load_catalog_file() {
  local file="$1" entry path type default category description status replacement
  local -a loaded=()
  while IFS= read -r entry || [ -n "$entry" ]; do
    if [[ "$entry" =~ ^#\ kwatch\ config\ catalog\ v([0-9]+)$ ]]; then
      CATALOG_VERSION="${BASH_REMATCH[1]}"
      continue
    fi
    [[ -z "$entry" || "$entry" = \#* ]] && continue
    IFS='|' read -r path type default category description status replacement <<<"$entry"
    [ -n "$path" ] && [ -n "$type" ] && [ -n "$category" ] && [ -n "$description" ] || return 1
    loaded+=("$entry")
  done < "$file"
  [ "${#loaded[@]}" -gt 0 ] || return 1
  CATALOG=("${loaded[@]}")
}

cache_catalog() {
  local file="$1"
  kubectl -n "$NAMESPACE" create configmap "$CATALOG_CACHE_NAME" \
    --from-file=catalog.tsv="$file" \
    --from-literal=source="$CATALOG_SOURCE" \
    --from-literal=updated-at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true
}

load_catalog_for_version() {
  local version="${1:-}" tmp cached cached_source
  tmp=$(mktemp)
  trap 'if [ -n "${tmp:-}" ]; then rm -f "$tmp"; fi' RETURN
  if [ -n "$version" ] && with_loading "Loading configuration catalog" \
      curl -fsSL --location --retry 2 --retry-delay 1 --connect-timeout 8 \
      "$BASE_URL/$version/deploy/config-catalog.tsv" -o "$tmp" \
      && load_catalog_file "$tmp"; then
    CATALOG_SOURCE="release:$version"
    cache_catalog "$tmp"
    return 0
  fi
  cached_source=$(kubectl -n "$NAMESPACE" get configmap "$CATALOG_CACHE_NAME" \
    -o jsonpath='{.data.source}' 2>/dev/null || true)
  [ "$cached_source" = "release:$version" ] || return 1
  cached=$(kubectl -n "$NAMESPACE" get configmap "$CATALOG_CACHE_NAME" \
    -o jsonpath='{.data.catalog\.tsv}' 2>/dev/null || true)
  if [ -n "$cached" ]; then
    printf '%s\n' "$cached" > "$tmp"
    if load_catalog_file "$tmp"; then
      CATALOG_SOURCE="cache"
      return 0
    fi
  fi
  return 1
}

load_feature_catalog_file() {
  local file="$1" entry id lifecycle description dependencies
  local -a loaded=()
  while IFS= read -r entry || [ -n "$entry" ]; do
    if [[ "$entry" =~ ^#\ kwatch\ feature\ catalog\ v([0-9]+)$ ]]; then
      FEATURE_CATALOG_VERSION="${BASH_REMATCH[1]}"
      continue
    fi
    [[ -z "$entry" || "$entry" = \#* ]] && continue
    IFS='|' read -r id lifecycle description dependencies <<<"$entry"
    [ -n "$id" ] && \
      [ "$lifecycle" = startup -o "$lifecycle" = runtime ] && \
      [ -n "$description" ] || return 1
    loaded+=("$entry")
  done < "$file"
  [ "${#loaded[@]}" -gt 0 ] || return 1
  FEATURE_CATALOG=("${loaded[@]}")
}

cache_feature_catalog() {
  local file="$1"
  kubectl -n "$NAMESPACE" create configmap "$FEATURE_CATALOG_CACHE_NAME" \
    --from-file=features.tsv="$file" \
    --from-literal=source="$FEATURE_CATALOG_SOURCE" \
    --from-literal=updated-at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true
}

load_feature_catalog_for_version() {
  local version="${1:-}" tmp cached cached_source
  tmp=$(mktemp)
  trap 'if [ -n "${tmp:-}" ]; then rm -f "$tmp"; fi' RETURN
  if [ -n "$version" ] && with_loading "Loading feature catalog" \
      curl -fsSL --location --retry 2 --retry-delay 1 --connect-timeout 8 \
      "$BASE_URL/$version/deploy/feature-catalog.tsv" -o "$tmp" \
      && load_feature_catalog_file "$tmp"; then
    FEATURE_CATALOG_SOURCE="release:$version"
    cache_feature_catalog "$tmp"
    return 0
  fi
  cached_source=$(kubectl -n "$NAMESPACE" get configmap "$FEATURE_CATALOG_CACHE_NAME" \
    -o jsonpath='{.data.source}' 2>/dev/null || true)
  [ "$cached_source" = "release:$version" ] || return 1
  cached=$(kubectl -n "$NAMESPACE" get configmap "$FEATURE_CATALOG_CACHE_NAME" \
    -o jsonpath='{.data.features\.tsv}' 2>/dev/null || true)
  if [ -n "$cached" ]; then
    printf '%s\n' "$cached" > "$tmp"
    if load_feature_catalog_file "$tmp"; then
      FEATURE_CATALOG_SOURCE="cache"
      return 0
    fi
  fi
  return 1
}

load_provider_catalog_file() {
  local file="$1" entry provider display field type required secret validation default description
  local group condition
  local -a loaded=()
  while IFS= read -r entry || [ -n "$entry" ]; do
    if [[ "$entry" =~ ^#\ kwatch\ provider\ catalog\ v([0-9]+)$ ]]; then
      PROVIDER_CATALOG_VERSION="${BASH_REMATCH[1]}"
      continue
    fi
    [[ -z "$entry" || "$entry" = \#* ]] && continue
    IFS='|' read -r provider display field type required secret validation default \
      description group condition <<<"$entry"
    [ -n "$provider" ] && [ -n "$display" ] && [ -n "$field" ] && \
      case "$type" in
        string|integer|boolean|list|json|headers) ;;
        *) return 1 ;;
      esac
    [ -n "$provider" ] && [ -n "$display" ] && [ -n "$field" ] && \
      { [ "$required" = true ] || [ "$required" = false ]; } && \
      { [ "$secret" = true ] || [ "$secret" = false ]; } && \
      [ -n "$description" ] || return 1
    if [ -n "$condition" ]; then
      case "$condition" in
        choice:*) [ -n "$group" ] || return 1 ;;
        at-least-one) [ -n "$group" ] || return 1 ;;
        required-if:*) [[ "$condition" = *"="* ]] || return 1 ;;
        *) return 1 ;;
      esac
    fi
    loaded+=("$entry")
  done < "$file"
  [ "${#loaded[@]}" -gt 0 ] || return 1
  PROVIDER_CATALOG=("${loaded[@]}")
}

cache_provider_catalog() {
  local file="$1"
  kubectl -n "$NAMESPACE" create configmap "$PROVIDER_CATALOG_CACHE_NAME" \
    --from-file=providers.tsv="$file" \
    --from-literal=source="$PROVIDER_CATALOG_SOURCE" \
    --from-literal=updated-at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true
}

load_provider_catalog_for_version() {
  local version="${1:-}" tmp cached cached_source
  tmp=$(mktemp)
  trap 'if [ -n "${tmp:-}" ]; then rm -f "$tmp"; fi' RETURN
  if [ -n "$version" ] && with_loading "Loading provider catalog" \
      curl -fsSL --location --retry 2 --retry-delay 1 --connect-timeout 8 \
      "$BASE_URL/$version/deploy/provider-catalog.tsv" -o "$tmp" \
      && load_provider_catalog_file "$tmp"; then
    PROVIDER_CATALOG_SOURCE="release:$version"
    cache_provider_catalog "$tmp"
    return 0
  fi
  cached_source=$(kubectl -n "$NAMESPACE" get configmap "$PROVIDER_CATALOG_CACHE_NAME" \
    -o jsonpath='{.data.source}' 2>/dev/null || true)
  [ "$cached_source" = "release:$version" ] || return 1
  cached=$(kubectl -n "$NAMESPACE" get configmap "$PROVIDER_CATALOG_CACHE_NAME" \
    -o jsonpath='{.data.providers\.tsv}' 2>/dev/null || true)
  if [ -n "$cached" ]; then
    printf '%s\n' "$cached" > "$tmp"
    if load_provider_catalog_file "$tmp"; then
      PROVIDER_CATALOG_SOURCE="cache"
      return 0
    fi
  fi
  return 1
}

BACKUP_NAME=""
backup_config() {
  local resource timestamp
  resource=$(kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" -o json)
  timestamp=$(date -u +%Y%m%d%H%M%S)
  BACKUP_NAME="${RELEASE}-config-$timestamp"
  kubectl -n "$NAMESPACE" create secret generic "$BACKUP_NAME" \
    --from-literal=resource.json="$resource" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

restore_backup() {
  local encoded deployment backup_file
  [ -n "$BACKUP_NAME" ] || return 0
  encoded=$(kubectl -n "$NAMESPACE" get secret "$BACKUP_NAME" \
    -o 'jsonpath={.data.resource\.json}')
  [ -n "$encoded" ] || die "backup is missing resource.json; refusing to restore it"
  backup_file=$(mktemp)
  if ! decode_base64_file "$encoded" "$backup_file"; then
    rm -f "$backup_file"
    die "backup is not valid base64; refusing to restore it"
  fi
  if ! kubectl -n "$NAMESPACE" apply -f "$backup_file" >/dev/null; then
    rm -f "$backup_file"
    die "backup resource could not be restored"
  fi
  rm -f "$backup_file"
  deployment=$(deployment_name)
  [ -n "$deployment" ] || return 0
  restart_kwatch
}

config_value() {
  local path="$1"
  kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" \
    -o "jsonpath={.spec.$path}" 2>/dev/null || true
}

ensure_config_resource() {
  if kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" >/dev/null 2>&1; then
    kubectl -n "$NAMESPACE" annotate kwatchconfig "$RELEASE" \
      "kwatch.dev/config-schema=$CATALOG_VERSION" --overwrite >/dev/null
    kubectl -n "$NAMESPACE" label kwatchconfig "$RELEASE" \
      app.kubernetes.io/instance="$RELEASE" \
      app.kubernetes.io/managed-by=kwatch.sh --overwrite >/dev/null 2>&1 || true
    return 0
  fi
  kubectl -n "$NAMESPACE" apply -f - <<EOF >/dev/null
apiVersion: kwatch.abahmed.dev/v1alpha1
kind: KwatchConfig
metadata:
  name: $RELEASE
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/instance: "$RELEASE"
    app.kubernetes.io/managed-by: kwatch.sh
    kwatch.dev/config-schema: "$CATALOG_VERSION"
spec:
  crd:
    enabled: true
EOF
}

ensure_crd() {
  local version="${1:-}" tmp
  if [ -z "$version" ] && kubectl get crd kwatchconfigs.kwatch.abahmed.dev >/dev/null 2>&1; then
    return 0
  fi
  if [ -z "$version" ]; then
    version=$(latest_version) || die "could not determine kwatch version from GitHub"
  fi
  valid_release_version "$version" || die "invalid kwatch release version: $version"
  tmp=$(mktemp)
  trap 'if [ -n "${tmp:-}" ]; then rm -f "$tmp"; fi' RETURN
  with_loading "Downloading CRD for $version" curl -fsSL --location \
    --retry 3 --retry-delay 2 --connect-timeout 10 \
    "$BASE_URL/$version/deploy/crd.yaml" -o "$tmp" ||
    die "could not download the CRD for $version"
  grep -q '^kind: CustomResourceDefinition$' "$tmp" || die "downloaded CRD for $version is invalid"
  with_loading "Applying CRD" \
    kubectl apply --server-side --field-manager=kwatch-manager -f "$tmp" \
    >/dev/null || die "could not apply the CRD for $version"
  with_loading "Waiting for CRD readiness" kubectl wait \
    --for=condition=Established crd/kwatchconfigs.kwatch.abahmed.dev \
    --timeout=60s >/dev/null || die "CRD did not become ready"
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\r//g; s/\n/\\n/g'
}

json_array() {
  local raw="$1" item first=true
  if [ -z "$raw" ] || [ "$raw" = all ] || [ "$raw" = empty ]; then
    printf '[]'
    return
  fi
  printf '['
  IFS=',' read -ra items <<<"$raw"
  for item in "${items[@]}"; do
    item="${item#${item%%[![:space:]]*}}"
    item="${item%${item##*[![:space:]]}}"
    [ -n "$item" ] || continue
    [ "$first" = true ] || printf ','
    printf '"%s"' "$(json_escape "$item")"
    first=false
  done
  printf ']'
}

write_provider_value() {
  local file="$1" field="$2" type="$3" value="$4"
  local key parent child yaml_value
  case "$type" in
    boolean)
      [[ "$value" = true || "$value" = false ]] ||
        die "$field must be true or false"
      yaml_value="$value"
      ;;
    integer)
      [[ "$value" =~ ^[0-9]+$ ]] ||
        die "$field must be a non-negative integer"
      yaml_value="$value"
      ;;
    list)
      yaml_value=$(json_array "$value")
      ;;
    json)
      [ -n "$value" ] || die "$field cannot be empty"
      yaml_value="$value"
      ;;
    *)
      yaml_value="\"$(json_escape "$value")\""
      ;;
  esac
  if [[ "$field" == *.* ]]; then
    parent="${field%%.*}"
    child="${field#*.}"
    key="|$parent|"
    case "$WRITTEN_PROVIDER_SECTIONS" in
      *"$key"*) ;;
      *)
        printf '    %s:\n' "$parent" >>"$file"
        WRITTEN_PROVIDER_SECTIONS="${WRITTEN_PROVIDER_SECTIONS}${parent}|"
        ;;
    esac
    printf '      %s: %s\n' "$child" "$yaml_value" >>"$file"
    return
  fi
  printf '    %s: %s\n' "$field" "$yaml_value" >>"$file"
}

write_provider_secret() {
  local file="$1" field="$2" value="$3" tmp_dir="$4"
  local secret_key value_file
  case "$value" in
    *$'\n'*|*$'\r'*) die "$field must be one line" ;;
  esac
  secret_key="${PROVIDER}-${field//./-}"
  value_file="$tmp_dir/$secret_key"
  printf '%s' "$value" >"$value_file"
  chmod 600 "$value_file"
  SECRET_ARGS+=(--from-file="$secret_key=$value_file")
  if [[ "$field" == *.* ]]; then
    local parent="${field%%.*}" child="${field#*.}" key="|$parent|"
    case "$WRITTEN_PROVIDER_SECTIONS" in
      *"$key"*) ;;
      *)
        printf '    %s:\n' "$parent" >>"$file"
        WRITTEN_PROVIDER_SECTIONS="${WRITTEN_PROVIDER_SECTIONS}${parent}|"
        ;;
    esac
    printf '      %s: "${file:%s/%s}"\n' \
      "$child" "$CONFIG_MOUNT_PATH" "$secret_key" >>"$file"
    return
  fi
  printf '    %s: "${file:%s/%s}"\n' \
    "$field" "$CONFIG_MOUNT_PATH" "$secret_key" >>"$file"
}

write_config_secret_value() {
  local file="$1" path="$2" value="$3" tmp_dir="$4"
  local secret_key value_file parent child key
  case "$value" in
    *$'\n'*|*$'\r'*) return 1 ;;
  esac
  if [ "$path" = heartbeatMonitor.url ] &&
    [[ ! "$value" =~ ^https?:// ]]; then
    return 1
  fi
  secret_key="${RELEASE}-config-${path//./-}"
  value_file="$tmp_dir/$secret_key"
  printf '%s' "$value" >"$value_file"
  chmod 600 "$value_file"
  SECRET_ARGS+=(--from-file="$secret_key=$value_file")
  if [[ "$path" == *.* ]]; then
    parent="${path%%.*}"
    child="${path#*.}"
    key="|$parent|"
    case "$WRITTEN_CONFIG_SECTIONS" in
      *"$key"*) ;;
      *)
        printf '%s:\n' "    $parent" >>"$file"
        WRITTEN_CONFIG_SECTIONS="${WRITTEN_CONFIG_SECTIONS}${parent}|"
        ;;
    esac
    printf '      %s: "${file:%s/%s}"\n' \
      "$child" "$CONFIG_MOUNT_PATH" "$secret_key" >>"$file"
    return
  fi
  printf '    %s: "${file:%s/%s}"\n' \
    "$path" "$CONFIG_MOUNT_PATH" "$secret_key" >>"$file"
}

secret_data_base64() {
  local secret_name="$1" key="$2" encoded
  encoded=$(kubectl -n "$NAMESPACE" get secret "$secret_name" \
    -o "go-template={{index .data \"$key\"}}" 2>/dev/null || true)
  case "$encoded" in
    ""|"<no value>"|null|\(null\)) return 0 ;;
  esac
  printf '%s' "$encoded"
}

decode_base64_file() {
  local encoded="$1" file="$2"
  [ -n "$encoded" ] || return 1
  printf '%s' "$encoded" | base64 --decode >"$file" 2>/dev/null && return 0
  printf '%s' "$encoded" | base64 -d >"$file" 2>/dev/null && return 0
  printf '%s' "$encoded" | base64 -D >"$file" 2>/dev/null
}

preserve_secret_file() {
  local key="$1" tmp_dir="$2" encoded value_file
  encoded=$(secret_data_base64 "$CONFIG_SECRET_NAME" "$key")
  [ -n "$encoded" ] || return 1
  value_file="$tmp_dir/$key"
  decode_base64_file "$encoded" "$value_file" || return 1
  chmod 600 "$value_file"
  SECRET_ARGS+=(--from-file="$key=$value_file")
}

preserve_provider_secret() {
  local file="$1" provider="$2" field="$3" tmp_dir="$4"
  local secret_key key parent child
  secret_key="${provider}-${field//./-}"
  preserve_secret_file "$secret_key" "$tmp_dir" || return 1
  if [[ "$field" == *.* ]]; then
    parent="${field%%.*}"
    child="${field#*.}"
    key="|$parent|"
    case "$WRITTEN_PROVIDER_SECTIONS" in
      *"$key"*) ;;
      *)
        printf '    %s:\n' "$parent" >>"$file"
        WRITTEN_PROVIDER_SECTIONS="${WRITTEN_PROVIDER_SECTIONS}${parent}|"
        ;;
    esac
    printf '      %s: "${file:%s/%s}"\n' \
      "$child" "$CONFIG_MOUNT_PATH" "$secret_key" >>"$file"
    return 0
  fi
  printf '    %s: "${file:%s/%s}"\n' \
    "$field" "$CONFIG_MOUNT_PATH" "$secret_key" >>"$file"
}

preserve_config_secret() {
  local file="$1" path="$2" tmp_dir="$3"
  local secret_key parent child key
  secret_key="${RELEASE}-config-${path//./-}"
  preserve_secret_file "$secret_key" "$tmp_dir" || return 1
  parent="${path%%.*}"
  child="${path#*.}"
  key="|$parent|"
  case "$WRITTEN_CONFIG_SECTIONS" in
    *"$key"*) ;;
    *)
      printf '    %s:\n' "$parent" >>"$file"
      WRITTEN_CONFIG_SECTIONS="${WRITTEN_CONFIG_SECTIONS}${parent}|"
      ;;
  esac
  printf '      %s: "${file:%s/%s}"\n' \
    "$child" "$CONFIG_MOUNT_PATH" "$secret_key" >>"$file"
}

old_provider_field_block() {
  local provider="$1" field="$2" old_file="$3"
  local parent child
  if [[ "$field" == *.* ]]; then
    parent="${field%%.*}"
    child="${field#*.}"
    awk -v provider="  $provider:" -v parent="    $parent:" \
      -v child="      $child:" '
      $0 == provider { in_provider=1; next }
      in_provider && $0 ~ /^  [^ ]/ { exit }
      in_provider && $0 == parent { in_parent=1; next }
      in_parent && $0 ~ /^    [^ ]/ { in_parent=0 }
      in_parent && index($0, child) == 1 { print; exit }
    ' "$old_file"
    return
  fi
  awk -v provider="  $provider:" -v field="    $field:" '
    $0 == provider { in_provider=1; next }
    in_provider && $0 ~ /^  [^ ]/ { exit }
    in_provider && index($0, field) == 1 { print; exit }
  ' "$old_file"
}

old_provider_section() {
  local provider="$1" field="$2" old_file="$3"
  awk -v provider="  $provider:" -v field="    $field:" '
    $0 == provider { in_provider=1; next }
    in_provider && $0 ~ /^  [^ ]/ { exit }
    in_provider && index($0, field) == 1 { in_field=1 }
    in_field && $0 ~ /^    [^ ]/ && index($0, field) != 1 { exit }
    in_field { print }
  ' "$old_file"
}

old_provider_exists() {
  local provider="$1"
  [ -s "${OLD_CONFIG_PATH:-}" ] || return 1
  awk -v wanted="  $provider:" '
    $0 == wanted { found=1; exit }
    END { exit(found ? 0 : 1) }
  ' "$OLD_CONFIG_PATH"
}

preserve_provider_optional() {
  local file="$1" provider="$2" field="$3" type="$4" tmp_dir="$5"
  local block ref key parent child section_key
  [ -s "${OLD_CONFIG_PATH:-}" ] || return 1
  if [ "$type" = headers ]; then
    block=$(old_provider_section "$provider" "$field" "$OLD_CONFIG_PATH")
    [ -n "$block" ] || return 1
    while IFS= read -r ref; do
      key="${ref##*/}"
      key="${key%\}}"
      [ -n "$key" ] || continue
      preserve_secret_file "$key" "$tmp_dir" || return 1
    done < <(printf '%s\n' "$block" | grep -o '\${file:[^}]*}' || true)
    printf '%s\n' "$block" >>"$file"
    return 0
  fi
  block=$(old_provider_field_block "$provider" "$field" "$OLD_CONFIG_PATH")
  [ -n "$block" ] || return 1
  if [[ "$field" == *.* ]]; then
    parent="${field%%.*}"
    child="${field#*.}"
    section_key="|$parent|"
    case "$WRITTEN_PROVIDER_SECTIONS" in
      *"$section_key"*) ;;
      *)
        printf '    %s:\n' "$parent" >>"$file"
        WRITTEN_PROVIDER_SECTIONS="${WRITTEN_PROVIDER_SECTIONS}${parent}|"
        ;;
    esac
    printf '      %s\n' "${block#*      }" >>"$file"
    return 0
  fi
  printf '%s\n' "$block" >>"$file"
}

write_webhook_headers() {
  local file="$1" tmp_dir="$2" count name value i secret_key value_file
  while true; do
    count=$(ask "Number of custom webhook headers" "0")
    [[ "$count" =~ ^[0-9]+$ ]] && break
    ui_warn "⚠️ Header count must be a non-negative integer."
  done
  [ "$count" -gt 0 ] || return 0
  printf '    headers:\n' >>"$file"
  for ((i = 1; i <= count; i++)); do
    while true; do
      name=$(ask "Header $i name")
      [ -n "$name" ] && break
      ui_warn "⚠️ Header name cannot be empty."
    done
    while true; do
      value=$(ask_secret "Header $i value")
      if [ -n "$value" ] && [[ "$value" != *$'\n'* &&
        "$value" != *$'\r'* ]]; then
        break
      fi
      ui_warn "⚠️ Header value must be a non-empty single line."
    done
    secret_key="${PROVIDER}-header-${i}"
    value_file="$tmp_dir/$secret_key"
    printf '%s' "$value" >"$value_file"
    chmod 600 "$value_file"
    SECRET_ARGS+=(--from-file="$secret_key=$value_file")
    printf '      - name: "%s"\n' "$(json_escape "$name")" >>"$file"
    printf '        value: "${file:%s/%s}"\n' \
      "$CONFIG_MOUNT_PATH" "$secret_key" >>"$file"
  done
}

patch_config_value() {
  local path="$1" type="$2" value="$3" top field json_value
  if [[ "$path" == *.* ]]; then
    top="${path%%.*}"
    field="${path#*.}"
    case "$type" in
      boolean) [[ "$value" = true || "$value" = false ]] || return 1; json_value="$value" ;;
      integer) [[ "$value" =~ ^[0-9]+$ ]] || return 1; json_value="$value" ;;
      float) [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1; json_value="$value" ;;
      list) json_value="$(json_array "$value")" ;;
      json) json_value="$value" ;;
      *) json_value="\"$(json_escape "$value")\"" ;;
    esac
    kubectl -n "$NAMESPACE" patch kwatchconfig "$RELEASE" --type merge \
      -p "{\"spec\":{\"$top\":{\"$field\":$json_value}}}" >/dev/null
  else
    case "$type" in
      boolean) [[ "$value" = true || "$value" = false ]] || return 1; json_value="$value" ;;
      integer) [[ "$value" =~ ^[0-9]+$ ]] || return 1; json_value="$value" ;;
      float) [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1; json_value="$value" ;;
      list) json_value="$(json_array "$value")" ;;
      json) json_value="$value" ;;
      *) json_value="\"$(json_escape "$value")\"" ;;
    esac
    kubectl -n "$NAMESPACE" patch kwatchconfig "$RELEASE" --type merge \
      -p "{\"spec\":{\"$path\":$json_value}}" >/dev/null
  fi
}

verify_runtime_tls_access() {
  local deployment service_account subject result verb
  deployment=$(deployment_name)
  if [ -z "$deployment" ]; then
    echo "Cannot verify TLS access: kwatch deployment was not found." >&2
    return 1
  fi
  service_account=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.serviceAccountName}' 2>/dev/null || true)
  [ -n "$service_account" ] || service_account=default
  subject="system:serviceaccount:$NAMESPACE:$service_account"
  for verb in get list watch; do
    result=$(kubectl auth can-i "$verb" secrets --all-namespaces --as="$subject" 2>/dev/null || true)
    result=$(printf '%s\n' "$result" | awk '
      { line=tolower($0); gsub(/^[[:space:]]+|[[:space:]]+$/, "", line) }
      line == "yes" { answer="yes" }
      line == "no" { answer="no" }
      END { print answer }
    ')
    case "$result" in
      yes) ;;
      no)
        echo "TLS monitoring needs the kwatch ServiceAccount to $verb Secrets; RBAC is missing." >&2
        return 1
        ;;
      *)
        ui_info "ℹ️ Could not preflight TLS RBAC for $verb; the runtime check remains authoritative."
        ;;
    esac
  done
}

enable_initial_tls_monitor() {
  [ "${TLS_MONITOR_ENABLED:-false}" = true ] || return 0
  kubectl -n "$NAMESPACE" patch kwatchconfig "$RELEASE" --type merge \
    -p '{"spec":{"tlsMonitor":{"enabled":true}}}' >/dev/null || \
    { echo "Could not enable TLS monitoring in KwatchConfig." >&2; return 1; }
  verify_runtime_tls_access
}

show_catalog_entry() {
  local entry="$1" path type default category description status replacement current
  IFS='|' read -r path type default category description status replacement <<<"$entry"
  current=$(config_value "$path")
  [ -n "$current" ] || current="default ($default)"
  echo
  echo "$path"
  echo "  $description"
  echo "  Type: $type | Current: $current | Default: $default"
  if [ "$status" = deprecated ]; then
    echo "  Deprecated: use $replacement instead."
  fi
}

migration_notice() {
  local schema entry path type default category description status replacement current
  schema=$(kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" \
    -o 'jsonpath={.metadata.labels.kwatch\.dev/config-schema}' 2>/dev/null || true)
  if [ -n "$schema" ] && [ "$schema" -lt "$CATALOG_VERSION" ] 2>/dev/null; then
    echo "Configuration schema $schema is older than this manager's schema $CATALOG_VERSION." >&2
    echo "New settings will use their documented defaults; existing settings are preserved." >&2
  fi
  for entry in "${CATALOG[@]}"; do
    IFS='|' read -r path type default category description status replacement <<<"$entry"
    [ "$status" = deprecated ] || continue
    current=$(config_value "$path")
    [ -n "$current" ] && echo "Deprecated config detected: $path (use $replacement)" >&2
  done
}

migrate_legacy_silences() {
  local marker values item field rule_key first
  marker=$(kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" \
    -o 'jsonpath={.metadata.annotations.kwatch\.dev/legacy-silences-migrated}' 2>/dev/null || true)
  [ "$marker" = "$CATALOG_VERSION" ] && return 0

  for field in ignoreContainerNames ignorePodNames ignoreLogPatterns ignoreContainerMessages ignoreNodeReasons ignoreNodeMessages; do
    case "$field" in
      ignoreContainerNames) rule_key=containerNames ;;
      ignorePodNames) rule_key=podNamePatterns ;;
      ignoreLogPatterns) rule_key=logPatterns ;;
      ignoreContainerMessages) rule_key=containerMessages ;;
      ignoreNodeReasons) rule_key=nodeReasons ;;
      ignoreNodeMessages) rule_key=nodeMessages ;;
    esac
    values=$(kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" \
      -o "jsonpath={range .spec.$field[*]}{.}{\"\\n\"}{end}" 2>/dev/null || true)
    [ -n "$values" ] || continue
    first=$(kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" \
      -o 'jsonpath={.spec.silences}' 2>/dev/null || true)
    if [ -z "$first" ]; then
      kubectl -n "$NAMESPACE" patch kwatchconfig "$RELEASE" --type merge \
        -p '{"spec":{"silences":[]}}' >/dev/null
    fi
    while IFS= read -r item; do
      [ -n "$item" ] || continue
      kubectl -n "$NAMESPACE" patch kwatchconfig "$RELEASE" --type=json \
        -p "[{\"op\":\"add\",\"path\":\"/spec/silences/-\",\"value\":{\"$rule_key\":[\"$(json_escape "$item")\"]}}]" >/dev/null
    done <<< "$values"
    kubectl -n "$NAMESPACE" patch kwatchconfig "$RELEASE" --type=json \
      -p "[{\"op\":\"remove\",\"path\":\"/spec/$field\"}]" >/dev/null
  done
  kubectl -n "$NAMESPACE" annotate kwatchconfig "$RELEASE" \
    "kwatch.dev/legacy-silences-migrated=$CATALOG_VERSION" --overwrite >/dev/null
  echo "Legacy ignore settings were migrated into scoped silences." >&2
}

configure_flow() {
  local deployment
  require_config_catalog
  ensure_crd
  preflight_access manage
  preflight_config_resource
  ensure_config_resource
  backup_config
  if ! migrate_legacy_silences; then
    echo "Legacy configuration migration failed; restoring the previous configuration." >&2
    restore_backup
    die "configuration migration failed"
  fi
  while true; do
    echo
    echo "kwatch configuration"
    printf '%s\n' "1) Alerts" "2) Scope" "3) Performance" \
      "4) Incident memory" "5) Noise reduction" "6) Monitors" \
      "7) Operations" "8) Compatibility" "9) Product control" \
      "10) Security" "11) Back"
    local choice category entry path type default category_name description status replacement current value
    choice=$(ask "Category" "1")
    case "$choice" in
      1) category="Alerts" ;; 2) category="Scope" ;; 3) category="Performance" ;;
      4) category="Incident memory" ;; 5) category="Noise reduction" ;; 6) category="Monitors" ;;
      7) category="Operations" ;; 8) category="Compatibility" ;; 9) category="Product control" ;;
      10) category="Security" ;; 11) return ;;
      *) echo "Unknown choice"; continue ;;
    esac
    echo
    local i=1 display_value prompt_default
    for entry in "${CATALOG[@]}"; do
      IFS='|' read -r path type default category_name description status replacement <<<"$entry"
      [ "$category_name" = "$category" ] || continue
      current=$(config_value "$path")
      display_value="$current"
      [ -n "$display_value" ] || display_value="default ($default)"
      printf '%s) %s — %s\n' "$i" "$path" "$display_value"
      i=$((i + 1))
    done
    choice=$(ask "Setting" "")
    [ "$choice" -ge 1 ] 2>/dev/null || { echo "Unknown setting"; continue; }
    i=1
    for entry in "${CATALOG[@]}"; do
      IFS='|' read -r path type default category_name description status replacement <<<"$entry"
      [ "$category_name" = "$category" ] || continue
      if [ "$i" = "$choice" ]; then
        if [ "$status" = secret ]; then
          echo "Secret-backed settings are changed with configure-alert."
          break
        fi
        current=$(config_value "$path")
        show_catalog_entry "$entry"
        [ "$status" = deprecated ] && echo "  Existing values are preserved; migration is not destructive."
        prompt_default="$current"
        [ -n "$prompt_default" ] || prompt_default="$default"
        value=$(ask "New value (Enter keeps current)" "$prompt_default")
        [ -n "$value" ] || continue
        backup_config
        if ! patch_config_value "$path" "$type" "$value"; then
          echo "Invalid configuration value; restoring the previous configuration." >&2
          restore_backup
          continue
        fi
        if [ "$path" = tlsMonitor.enabled ] && [ "$value" = true ]; then
          if ! verify_runtime_tls_access; then
            echo "TLS monitoring was not enabled because the deployed ServiceAccount lacks Secret access." >&2
            restore_backup
            die "TLS RBAC validation failed"
          fi
        fi
        kubectl -n "$NAMESPACE" annotate kwatchconfig "$RELEASE" \
          "kwatch.dev/config-schema=$CATALOG_VERSION" --overwrite >/dev/null
        deployment=$(deployment_name || true)
        if [ -n "$deployment" ]; then
          if ! restart_kwatch; then
            echo "Configuration failed validation; restoring backup." >&2
            restore_backup
            die "configuration update failed"
          fi
        else
          ui_info "ℹ️ Configuration saved; no kwatch Deployment is currently running."
          ui_info "🛠️ Choose 'Upgrade or repair workload' to activate it."
        fi
        echo "Updated $path."
        break
      fi
      i=$((i + 1))
    done
  done
}

configure_alert_flow() {
  local backup deployment
  require_provider_catalog
  adopt_existing_config_secret
  preflight_alert_access
  backup=$(mktemp)
  trap 'if [ -n "${backup:-}" ]; then rm -f "$backup"; fi' RETURN
  kubectl -n "$NAMESPACE" get secret "$CONFIG_SECRET_NAME" -o yaml >"$backup" 2>/dev/null || true
  write_config_secret
  deployment=$(deployment_name)
  if [ -n "$deployment" ] && ! restart_kwatch; then
    ui_warn "⚠️ Notification rollout failed; restoring the previous configuration."
    kubectl apply -f "$backup" >/dev/null 2>&1 || true
    restart_kwatch || true
    die "could not restart kwatch after changing notification providers"
  fi
  echo "Notification providers updated."
}

configure_after_install() {
  local choice
  choice=$(ask_yes_no \
    "🛠️ Configure additional kwatch settings now? This includes all catalog settings" \
    "y")
  [ "$choice" = true ] || return 0
  configure_flow
}

preflight_alert_access() {
  check_access get deployments namespace
  check_access patch deployments namespace
  check_access get secrets namespace
  check_access create secrets namespace
  check_access patch secrets namespace
}

NAMESPACE="${KWATCH_NAMESPACE:-$DEFAULT_NAMESPACE}"
RELEASE="${KWATCH_RELEASE:-$DEFAULT_RELEASE}"
NAMESPACE_CREATED=false
CONFIG_SECRET_NAME="${RELEASE}-config"
STATE_CONFIGMAP_NAME="${RELEASE}-manager-state"
CATALOG_CACHE_NAME="${RELEASE}-config-catalog"
FEATURE_CATALOG_CACHE_NAME="${RELEASE}-feature-catalog"
PROVIDER_CATALOG_CACHE_NAME="${RELEASE}-provider-catalog"
valid_kubernetes_name "$NAMESPACE" || die "invalid namespace: $NAMESPACE (maximum 40 characters)"
valid_kubernetes_name "$RELEASE" || die "invalid release name: $RELEASE (maximum 40 characters)"

record_state() {
  local phase="$1" version="${2:-}" message="${3:-}"
  kubectl -n "$NAMESPACE" create configmap "$STATE_CONFIGMAP_NAME" \
    --from-literal=phase="$phase" \
    --from-literal=version="$version" \
    --from-literal=context="$SELECTED_CONTEXT" \
    --from-literal=message="$message" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true
  kubectl -n "$NAMESPACE" label configmap "$STATE_CONFIGMAP_NAME" \
    app.kubernetes.io/instance="$RELEASE" \
    app.kubernetes.io/managed-by=kwatch.sh --overwrite >/dev/null 2>&1 || true
}

previous_state() {
  kubectl -n "$NAMESPACE" get configmap "$STATE_CONFIGMAP_NAME" \
    -o jsonpath='{.data.phase}' 2>/dev/null || true
}

confirm_resume() {
  local phase choice
  phase=$(previous_state)
  [ -n "$phase" ] && [ "$phase" != complete ] || return 0
  [ -t 0 ] || die "a previous kwatch operation is '$phase'; an interactive terminal is required to resume safely"
  echo "A previous kwatch operation stopped during: $phase" >&2
  choice=$(ask_yes_no "Continue and resume the operation" "y")
  [ "$choice" = true ] || die "operation cancelled; no changes were made"
}

check_access() {
  local verb="$1" resource="$2" scope="${3:-}" result
  if [ -n "$scope" ]; then
    result=$(kubectl auth can-i "$verb" "$resource" --namespace "$NAMESPACE" 2>/dev/null || true)
  else
    result=$(kubectl auth can-i "$verb" "$resource" 2>/dev/null || true)
  fi
  # The kubectl wrapper keeps stderr with command output for retry diagnostics,
  # so an authorization warning may surround the actual yes/no answer. Extract
  # an exact answer instead of treating the warning text as the result.
  result=$(printf '%s\n' "$result" | awk '
    { line=tolower($0); gsub(/^[[:space:]]+|[[:space:]]+$/, "", line) }
    line == "yes" { answer="yes" }
    line == "no" { answer="no" }
    END { print answer }
  ')
  case "$result" in
    yes|yes\ *) ;;
    no|no\ *) die "missing Kubernetes permission: $verb $resource${scope:+ in namespace $NAMESPACE}" ;;
    *)
      # Some Kubernetes distributions reject a preflight SelfSubjectAccessReview
      # for cluster resources even though the real operation is allowed. Do not
      # turn that discovery limitation into a noisy false warning; the command
      # below remains the authoritative check.
      return 0
      ;;
  esac
}

preflight_access() {
  local mode="${1:-manage}"
  check_access get deployments namespace
  check_access get secrets namespace
  check_access get pods namespace
  check_access get roles namespace
  check_access get rolebindings namespace
  check_access get customresourcedefinitions
  check_access patch namespaces
  if [ "$mode" = install ]; then
    check_access create namespaces
    check_access create deployments namespace
    check_access patch deployments namespace
    check_access create secrets namespace
    check_access patch secrets namespace
    check_access create roles namespace
    check_access patch roles namespace
    check_access create rolebindings namespace
    check_access patch rolebindings namespace
    check_access create customresourcedefinitions
    check_access patch customresourcedefinitions
    check_access create clusterroles
    check_access patch clusterroles
    check_access create clusterrolebindings
    check_access patch clusterrolebindings
  else
    check_access patch deployments namespace
    check_access patch secrets namespace
    check_access patch customresourcedefinitions
    if [ "$mode" = upgrade ]; then
      check_access patch clusterroles
      check_access patch clusterrolebindings
    fi
  fi
}

preflight_config_resource() {
  check_access get kwatchconfigs namespace
  if kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" >/dev/null 2>&1; then
    check_access patch kwatchconfigs namespace
  else
    check_access create kwatchconfigs namespace
  fi
}

latest_version() {
  local response version
  response=$(with_loading "Checking stable release" curl -fsSL --location \
    --retry 3 --retry-delay 2 --connect-timeout 10 "$RELEASES_URL") || return 1
  version=$(printf '%s' "$response" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  valid_release_version "$version" || return 1
  printf '%s' "$version"
}

latest_release_candidate() {
  local response tag
  response=$(with_loading "Checking release candidates" curl -fsSL --location \
    --retry 3 --retry-delay 2 --connect-timeout 10 "$RELEASES_LIST_URL") || return 1
  while IFS= read -r tag; do
    if [[ "$tag" == *-rc.* ]] && valid_release_version "$tag"; then
      printf '%s' "$tag"
      return 0
    fi
  done < <(
    printf '%s' "$response" |
      sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
  )
  return 1
}

select_release_version() {
  local stable preview choice
  stable=$(latest_version) || return 1
  preview=$(latest_release_candidate || true)
  if [ -z "$preview" ]; then
    printf '%s' "$stable"
    return 0
  fi
  ui_info "📦 Available kwatch releases:"
  echo "  1) ${UI_GREEN}✅ Stable ($stable)${UI_RESET} [recommended]" >&2
  echo "  2) ${UI_YELLOW}🧪 Release candidate ($preview)${UI_RESET}" >&2
  while true; do
    choice=$(ask "Release channel (1 or 2)" "1")
    case "$choice" in
      1) printf '%s' "$stable"; return 0 ;;
      2) printf '%s' "$preview"; return 0 ;;
      *) ui_warn "⚠️ Choose 1 for stable or 2 for the release candidate." ;;
    esac
  done
}

deployment_name() {
  local name app
  name=$(kubectl -n "$NAMESPACE" get deployment \
    -l "app.kubernetes.io/instance=$RELEASE,app.kubernetes.io/managed-by=kwatch.sh" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -n "$name" ]; then
    printf '%s' "$name"
    return
  fi
  name=$(kubectl -n "$NAMESPACE" get deployment \
    -l 'app=kwatch,app.kubernetes.io/managed-by=kwatch.sh' \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -n "$name" ]; then
    printf '%s' "$name"
    return
  fi
  # Older releases did not add the managed-by label. The release name is the
  # manager's ownership boundary, so discover that exact Deployment as a
  # compatibility fallback and adopt its existing configuration Secret.
  app=$(kubectl -n "$NAMESPACE" get deployment "$RELEASE" \
    -o 'jsonpath={.metadata.labels.app}' 2>/dev/null || true)
  [ "$app" = kwatch ] || return 0
  kubectl -n "$NAMESPACE" get deployment "$RELEASE" \
    -o jsonpath='{.metadata.name}' 2>/dev/null || true
}

managed_install_present() {
  local deployment schema owner state_owner config_data namespace_marker
  deployment=$(deployment_name || true)
  [ -n "$deployment" ] && return 0

  schema=$(kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" \
    -o 'jsonpath={.metadata.labels.kwatch\.dev/config-schema}' \
    2>/dev/null || true)
  if [ -z "$schema" ]; then
    schema=$(kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" \
      -o 'jsonpath={.metadata.annotations.kwatch\.dev/config-schema}' \
      2>/dev/null || true)
  fi
  [ -n "$schema" ] && return 0

  owner=$(kubectl -n "$NAMESPACE" get secret "$CONFIG_SECRET_NAME" \
    -o 'jsonpath={.metadata.labels.app\.kubernetes\.io/managed-by}' \
    2>/dev/null || true)
  [ "$owner" = kwatch.sh ] && return 0

  config_data=$(kubectl -n "$NAMESPACE" get secret "$CONFIG_SECRET_NAME" \
    -o 'jsonpath={.data.config\.yaml}' 2>/dev/null || true)
  [ -n "$config_data" ] && return 0

  state_owner=$(kubectl -n "$NAMESPACE" get configmap "$STATE_CONFIGMAP_NAME" \
    -o 'jsonpath={.metadata.labels.app\.kubernetes\.io/managed-by}' \
    2>/dev/null || true)
  [ "$state_owner" = kwatch.sh ] && return 0

  # Releases before Secret-backed configuration used a ConfigMap named after
  # the release. Its config.yaml is a reliable legacy installation marker.
  config_data=$(kubectl -n "$NAMESPACE" get configmap "$RELEASE" \
    -o 'jsonpath={.data.config\.yaml}' 2>/dev/null || true)
  [ -n "$config_data" ] && return 0

  namespace_marker=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.annotations.kwatch\.dev/managed-namespace}' \
    2>/dev/null || true)
  [ "$namespace_marker" = true ]
}

adopt_existing_config_secret() {
  local deployment secret_name
  deployment=$(deployment_name || true)
  [ -n "$deployment" ] || return 0
  secret_name=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.volumes[?(@.name=="config-volume")].secret.secretName}' \
    2>/dev/null || true)
  if [ -n "$secret_name" ]; then
    CONFIG_SECRET_NAME="$secret_name"
    ui_info "🔐 Using existing configuration Secret: $CONFIG_SECRET_NAME"
  fi
}

restart_kwatch() {
  local deployment
  deployment=$(deployment_name || true)
  if [ -z "$deployment" ]; then
    ui_error "❌ kwatch Deployment was not found; configuration was not activated."
    return 1
  fi
  with_loading "Restarting kwatch" kubectl -n "$NAMESPACE" \
    rollout restart "deployment/$deployment" >/dev/null || return 1
  with_loading "Waiting for kwatch rollout" kubectl -n "$NAMESPACE" \
    rollout status "deployment/$deployment" --timeout=5m || return 1
}

resolve_action() {
  local requested="$1" existing_deployment has_config has_secret
  existing_deployment=$(deployment_name || true)
  has_config=false
  has_secret=false
  if kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" >/dev/null 2>&1; then
    has_config=true
  fi
  if kubectl -n "$NAMESPACE" get secret "$CONFIG_SECRET_NAME" >/dev/null 2>&1; then
    has_secret=true
  fi
  case "$requested" in
    install)
      if [ -n "$existing_deployment" ] || [ "$has_config" = true ] ||
        [ "$has_secret" = true ]; then
        ui_warn "🔄 Existing kwatch resources were found; treating install as upgrade to preserve them."
        printf 'upgrade'
        return 0
      fi
      ;;
    upgrade)
      if [ -z "$existing_deployment" ] &&
        [ "$has_config" != true ] && [ "$has_secret" != true ]; then
        ui_warn "🧭 No existing kwatch resources were found; treating upgrade as install."
        printf 'install'
        return 0
      fi
      ;;
  esac
  printf '%s' "$requested"
}

installed_version() {
  local image tag deployment
  image=$(kubectl -n "$NAMESPACE" get deployment \
    -l "app.kubernetes.io/instance=$RELEASE,app.kubernetes.io/managed-by=kwatch.sh" \
    -o jsonpath='{.items[0].spec.template.spec.containers[0].image}' \
    2>/dev/null || true)
  if [ -z "$image" ]; then
    image=$(kubectl -n "$NAMESPACE" get deployment \
      -l 'app=kwatch,app.kubernetes.io/managed-by=kwatch.sh' \
      -o jsonpath='{.items[0].spec.template.spec.containers[0].image}' \
      2>/dev/null || true)
  fi
  if [ -z "$image" ]; then
    # Pre-catalog releases did not carry the manager labels. Reuse the same
    # app-labelled compatibility lookup used for upgrades and cleanup.
    deployment=$(deployment_name || true)
    if [ -n "$deployment" ]; then
      image=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
        -o jsonpath='{.spec.template.spec.containers[0].image}' \
        2>/dev/null || true)
    fi
  fi
  tag="${image##*:}"
  valid_release_version "$tag" && printf '%s' "$tag"
}

maybe_load_catalog() {
  local version="${1:-}" catalog_version ok=true
  if [ -z "$version" ]; then
    version=$(installed_version || true)
  fi
  if [ -z "$version" ]; then
    version=$(latest_version || true)
  fi
  [ -n "$version" ] || {
    ui_error "❌ Could not determine the kwatch release for catalog loading."
    return 1
  }
  catalog_version="$version"
  if load_catalog_for_version "$version"; then
    ui_success "📚 Configuration catalog: $CATALOG_SOURCE ($version)"
  else
    ui_error "❌ Configuration catalog unavailable for $version."
    ok=false
  fi
  if load_feature_catalog_for_version "$catalog_version"; then
    ui_success "🧩 Feature catalog: $FEATURE_CATALOG_SOURCE ($catalog_version)"
  else
    ui_error "❌ Feature catalog unavailable for $catalog_version."
    ok=false
  fi
  if load_provider_catalog_for_version "$catalog_version"; then
    ui_success "🔌 Provider catalog: $PROVIDER_CATALOG_SOURCE ($catalog_version)"
  else
    ui_error "❌ Provider catalog unavailable for $catalog_version."
    ok=false
  fi
  [ "$ok" = true ]
}

require_config_catalog() {
  [ "${#CATALOG[@]}" -gt 0 ] ||
    die "configuration catalog is unavailable; retry while the release artifact is reachable"
}

require_provider_catalog() {
  [ "${#PROVIDER_CATALOG[@]}" -gt 0 ] ||
    die "provider catalog is unavailable; retry while the release artifact is reachable"
}

features_flow() {
  [ "${#FEATURE_CATALOG[@]}" -gt 0 ] || die "feature catalog is unavailable; retry while the release artifact is reachable"
  echo "kwatch capabilities:"
  local entry id lifecycle description dependencies
  for entry in "${FEATURE_CATALOG[@]}"; do
    IFS='|' read -r id lifecycle description dependencies <<<"$entry"
    if [ -n "$dependencies" ]; then
      printf '%-42s %-7s %s (needs: %s)\n' "$id" "$lifecycle" "$description" "$dependencies"
    else
      printf '%-42s %-7s %s\n' "$id" "$lifecycle" "$description"
    fi
  done
}

provider_available() {
  local entry provider display field type required secret validation default
  local description group condition
  for entry in "${PROVIDER_CATALOG[@]}"; do
    IFS='|' read -r provider display field type required secret validation default \
      description group condition <<<"$entry"
    case "${CONFIGURED_PROVIDERS:-|}" in
      *"|$provider|"*) continue ;;
    esac
    return 0
  done
  return 1
}

remove_namespaced_workload() {
  delete_owned() {
    local scope="$1" kind="$2" name="$3" owner app
    if [ "$scope" = namespace ]; then
      owner=$(kubectl -n "$NAMESPACE" get "$kind" "$name" \
        -o 'jsonpath={.metadata.labels.app\.kubernetes\.io/managed-by}' \
        2>/dev/null || true)
    else
      owner=$(kubectl get "$kind" "$name" \
        -o 'jsonpath={.metadata.labels.app\.kubernetes\.io/managed-by}' \
        2>/dev/null || true)
    fi
    if [ "$owner" != kwatch.sh ] && [ "$kind" = deployment ] &&
      [ "$name" = "$RELEASE" ]; then
      app=$(kubectl -n "$NAMESPACE" get deployment "$name" \
        -o 'jsonpath={.metadata.labels.app}' 2>/dev/null || true)
      [ "$app" = kwatch ] && owner=kwatch.sh
    fi
    [ "$owner" = kwatch.sh ] || return 0
    if [ "$scope" = namespace ]; then
      kubectl -n "$NAMESPACE" delete "$kind" "$name" \
        --ignore-not-found >/dev/null 2>&1 || true
    else
      kubectl delete "$kind" "$name" --ignore-not-found >/dev/null 2>&1 || true
    fi
  }
  delete_owned namespace deployment "$RELEASE"
  delete_owned namespace service "$RELEASE"
  delete_owned namespace serviceaccount "$RELEASE"
  delete_owned namespace role "${RELEASE}-configmap-manager"
  delete_owned namespace rolebinding "${RELEASE}-configmap-manager"
  delete_owned cluster clusterrolebinding "$RELEASE"
  delete_owned cluster clusterrole "$RELEASE"
}

rollback_deployment() {
  local deployment
  deployment=$(deployment_name)
  [ -n "$deployment" ] || return 0
  kubectl -n "$NAMESPACE" rollout undo "deployment/$deployment" >/dev/null 2>&1 || return 0
  kubectl -n "$NAMESPACE" rollout status "deployment/$deployment" --timeout=5m >/dev/null 2>&1 || true
}

choose_provider() {
  local choice query normalized entry provider display field type required secret
  local validation default description seen="|" i provider_name display_name
  local exact_match
  local -a providers=() displays=() matches=()
  for entry in "${PROVIDER_CATALOG[@]}"; do
    IFS='|' read -r provider display field type required secret validation default \
      description group condition <<<"$entry"
    case "${CONFIGURED_PROVIDERS:-|}" in
      *"|$provider|"*) continue ;;
    esac
    case "$seen" in
      *"|$provider|"*) continue ;;
    esac
    providers+=("$provider")
    displays+=("$display")
    seen="${seen}${provider}|"
  done
  while true; do
    echo >&2
    echo "📣 Where should kwatch send alerts?" >&2
    query=$(ask "🔎 Provider name, number, or search (Enter to browse)" "")
    if [ -z "$query" ]; then
      for i in "${!providers[@]}"; do
        printf '  %d) %s\n' "$((i + 1))" "${displays[$i]}" >&2
      done
      query=$(ask "🎯 Choose provider number or name" "")
    fi
    if [[ "$query" =~ ^[0-9]+$ ]]; then
      if [ "$query" -ge 1 ] && [ "$query" -le "${#providers[@]}" ]; then
        PROVIDER="${providers[$((query - 1))]}"
        ui_success "✅ Provider selected: ${displays[$((query - 1))]}"
        return 0
      fi
      ui_warn "⚠️ Provider number is out of range."
      continue
    fi
    normalized=$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]' |
      sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [ -n "$normalized" ] || continue
    matches=()
    exact_match=-1
    for i in "${!providers[@]}"; do
      provider_name=$(printf '%s' "${providers[$i]}" |
        tr '[:upper:]' '[:lower:]')
      display_name=$(printf '%s' "${displays[$i]}" |
        tr '[:upper:]' '[:lower:]')
      if [ "$provider_name" = "$normalized" ] ||
        [ "$display_name" = "$normalized" ]; then
        if [ "$exact_match" -eq -1 ]; then
          exact_match=$i
        else
          exact_match=-2
        fi
      fi
      if [[ "$provider_name" == *"$normalized"* ]] ||
        [[ "$display_name" == *"$normalized"* ]]; then
        matches+=("$i")
      fi
    done
    if [ "$exact_match" -ge 0 ]; then
      PROVIDER="${providers[$exact_match]}"
      ui_success "✅ Provider selected: ${displays[$exact_match]}"
      return 0
    fi
    if [ "${#matches[@]}" -eq 1 ]; then
      i="${matches[0]}"
      PROVIDER="${providers[$i]}"
      ui_success "✅ Provider selected: ${displays[$i]}"
      return 0
    fi
    if [ "${#matches[@]}" -gt 1 ]; then
      echo "🔎 Matching providers for '$query':" >&2
      local match_number=1
      for i in "${matches[@]}"; do
        printf '  %d) %s (%s)\n' "$match_number" \
          "${displays[$i]}" "${providers[$i]}" >&2
        match_number=$((match_number + 1))
      done
      choice=$(ask "🎯 Choose a matching provider number" "")
      if [[ "$choice" =~ ^[0-9]+$ ]] &&
        [ "$choice" -ge 1 ] && [ "$choice" -le "${#matches[@]}" ]; then
        i="${matches[$((choice - 1))]}"
        PROVIDER="${providers[$i]}"
        ui_success "✅ Provider selected: ${displays[$i]}"
        return 0
      fi
      ui_warn "⚠️ Choose one of the matching provider numbers."
      continue
    fi
    ui_warn "⚠️ No provider matched '$query'. Try a partial name or number."
  done
}

choose_tls_monitor() {
  TLS_MONITOR_ENABLED=$(ask_yes_no \
    "🔒 Enable TLS certificate monitoring? It reads TLS Secrets" "n")
}

provider_group_value() {
  local group="$1" rest
  rest="${PROVIDER_GROUP_SELECTIONS#*|$group=}"
  [ "$rest" != "$PROVIDER_GROUP_SELECTIONS" ] || return 1
  printf '%s' "${rest%%|*}"
}

set_provider_group_value() {
  local group="$1" value="$2"
  PROVIDER_GROUP_SELECTIONS="${PROVIDER_GROUP_SELECTIONS}${group}=${value}|"
}

provider_group_present() {
  local group="$1"
  case "${PROVIDER_GROUP_PRESENCE:-|}" in
    *"|$group|"*) return 0 ;;
    *) return 1 ;;
  esac
}

mark_provider_group_present() {
  local group="$1"
  [ -n "$group" ] || return 0
  provider_group_present "$group" ||
    PROVIDER_GROUP_PRESENCE="${PROVIDER_GROUP_PRESENCE:-|}${group}|"
}

provider_group_has_later_field() {
  local target_group="$1" current_field="$2"
  local entry provider display field type required secret validation default
  local description group condition seen=false
  for entry in "${PROVIDER_CATALOG[@]}"; do
    IFS='|' read -r provider display field type required secret validation default \
      description group condition <<<"$entry"
    [ "$provider" = "$PROVIDER" ] || continue
    [ "$group" = "$target_group" ] || continue
    [ "$condition" = at-least-one ] || continue
    if [ "$seen" = true ]; then
      return 0
    fi
    [ "$field" = "$current_field" ] && seen=true
  done
  return 1
}

select_provider_groups() {
  local entry provider display field type required secret validation default
  local description group condition choice value selected i
  local seen="|"
  local -a groups=() values=()
  PROVIDER_GROUP_SELECTIONS="|"
  for entry in "${PROVIDER_CATALOG[@]}"; do
    IFS='|' read -r provider display field type required secret validation default \
      description group condition <<<"$entry"
    [ "$provider" = "$PROVIDER" ] || continue
    case "$condition" in
      choice:*)
        case "$seen" in
          *"|$group|"*) ;;
          *) groups+=("$group"); seen="${seen}${group}|" ;;
        esac
        ;;
    esac
  done
  [ "${#groups[@]}" -gt 0 ] || return 0
  for group in "${groups[@]}"; do
    values=()
    for entry in "${PROVIDER_CATALOG[@]}"; do
      IFS='|' read -r provider display field type required secret validation default \
        description entry_group condition <<<"$entry"
      [ "$provider" = "$PROVIDER" ] || continue
      [ "$entry_group" = "$group" ] || continue
      case "$condition" in
        choice:*) values+=("${condition#choice:}|$field|$description") ;;
      esac
    done
    [ "${#values[@]}" -gt 0 ] || continue
    echo >&2
    printf '🔐 Choose %s:%s\n' "$group" >&2
    i=1
    for value in "${values[@]}"; do
      IFS='|' read -r selected field description <<<"$value"
      printf '  %d) %s (%s)\n' "$i" "$selected" "$field" >&2
      i=$((i + 1))
    done
    while true; do
      choice=$(ask "🎯 $group option" "1")
      if [[ "$choice" =~ ^[0-9]+$ ]] &&
        [ "$choice" -ge 1 ] && [ "$choice" -le "${#values[@]}" ]; then
        value="${values[$((choice - 1))]}"
        IFS='|' read -r selected field description <<<"$value"
        set_provider_group_value "$group" "$selected"
        break
      fi
      ui_warn "⚠️ Choose one of the listed $group options."
    done
  done
}

provider_condition_matches() {
  local group="$1" condition="$2" selected expected expression
  case "$condition" in
    choice:*)
      selected=$(provider_group_value "$group" || true)
      expected="${condition#choice:}"
      [ "$selected" = "$expected" ]
      ;;
    at-least-one) return 0 ;;
    required-if:*)
      expression="${condition#required-if:}"
      group="${expression%%=*}"
      expected="${expression#*=}"
      selected=$(provider_group_value "$group" || true)
      [ "$selected" = "$expected" ]
      ;;
    "") return 0 ;;
    *) return 1 ;;
  esac
}

prompt_provider_value() {
  local field="$1" type="$2" secret="$3" validation="$4"
  local default="$5" description="$6" value
  while true; do
    if [ "$secret" = true ]; then
      value=$(ask_secret "$description")
    else
      value=$(ask "$description" "$default")
    fi
    [ -n "$value" ] || { printf ''; return 0; }
    case "$type" in
      boolean)
        [[ "$value" = true || "$value" = false ]] || {
          ui_warn "⚠️ $field must be true or false."; continue;
        }
        ;;
      integer)
        [[ "$value" =~ ^[0-9]+$ ]] || {
          ui_warn "⚠️ $field must be a non-negative integer."; continue;
        }
        ;;
      json)
        [[ "$value" = \[* || "$value" = \{* ]] || {
          ui_warn "⚠️ $field must be a JSON object or array."; continue;
        }
        ;;
    esac
    case "$validation" in
      url)
        [[ "$value" =~ ^https?:// ]] || {
          ui_warn "⚠️ $field must be an http or https URL."; continue;
        }
        ;;
      signed-integer|telegram-chat-id)
        [[ "$value" =~ ^-?[0-9]+$ ]] || {
          ui_warn "⚠️ $field must be a signed integer."; continue;
        }
        ;;
      port)
        [[ "$value" =~ ^[0-9]+$ ]] || {
          ui_warn "⚠️ $field must be a numeric port."; continue;
        }
        ;;
      integer)
        [[ "$value" =~ ^[0-9]+$ ]] || {
          ui_warn "⚠️ $field must be a non-negative integer."; continue;
        }
        ;;
      boolean)
        [[ "$value" = true || "$value" = false ]] || {
          ui_warn "⚠️ $field must be true or false."; continue;
        }
        ;;
      json)
        [[ "$value" = \[* || "$value" = \{* ]] || {
          ui_warn "⚠️ $field must be a JSON object or array."; continue;
        }
        ;;
      "") ;;
      *)
        ui_error "❌ Provider catalog has unknown validation: $validation"
        return 1
        ;;
    esac
    printf '%s' "$value"
    return 0
  done
}

apply_config_secret() {
  if [ "${#SECRET_ARGS[@]}" -gt 0 ]; then
    kubectl -n "$NAMESPACE" create secret generic "$secret_name" \
      --from-file=config.yaml="$config_tmp" \
      "${SECRET_ARGS[@]}" \
      --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  else
    kubectl -n "$NAMESPACE" create secret generic "$secret_name" \
      --from-file=config.yaml="$config_tmp" \
      --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  fi
}

write_provider_field() {
  local entry="$1" mode="$2" configure_optional="$3" priority="$4"
  local provider display field type required secret validation default description
  local group condition field_description value field_required field_priority
  IFS='|' read -r provider display field type required secret validation default \
    description group condition <<<"$entry"
  [ "$provider" = "$PROVIDER" ] || return 0
  case "$condition" in
    choice:*)
      provider_condition_matches "$group" "$condition" || return 0
      required=true
      field_priority=1
      ;;
    required-if:*)
      provider_condition_matches "$group" "$condition" || return 0
      required=true
      field_priority=2
      ;;
    at-least-one) field_priority=3 ;;
    *) field_priority=3 ;;
  esac
  if [ "$mode" = group ] && [ "$condition" != at-least-one ]; then
    return 0
  fi
  if [ "$mode" != group ] && [ "$condition" = at-least-one ]; then
    return 0
  fi
  [ "$field_priority" = "$priority" ] || return 0
  field_required="$required"
  if [ "$condition" = at-least-one ] &&
    ! provider_group_present "$group" &&
    ! provider_group_has_later_field "$group" "$field"; then
    field_required=true
  fi
  if [ "$mode" = required ] && [ "$field_required" != true ]; then
    return 0
  fi
  if [ "$mode" = optional ] && [ "$field_required" = true ]; then
    return 0
  fi
  if [ "$mode" = group ] && [ "$field_required" != true ] &&
    provider_group_present "$group"; then
    return 0
  fi
  if [ "$mode" = optional ] && [ "$configure_optional" = false ]; then
    if [ "$secret" = true ] &&
      preserve_provider_secret "$config_tmp" "$provider" "$field" "$tmp_dir"; then
      mark_provider_group_present "$group"
    elif [ -z "$condition" ] && old_provider_exists "$provider" &&
      preserve_provider_optional "$config_tmp" "$provider" "$field" \
      "$type" "$tmp_dir"; then
      mark_provider_group_present "$group"
    elif [ -n "$default" ] && [ "$type" != headers ]; then
      write_provider_value "$config_tmp" "$field" "$type" "$default"
    fi
    return 0
  fi
  if [ "$type" = headers ]; then
    write_webhook_headers "$config_tmp" "$tmp_dir"
    return 0
  fi
  while true; do
    field_description="$description"
    [ "$field_required" = true ] ||
      field_description="$description (optional; Enter to skip)"
    value=$(prompt_provider_value "$field" "$type" "$secret" \
      "$validation" "$default" "$field_description") || return 1
    if [ -z "$value" ]; then
      if [ "$secret" = true ] &&
        preserve_provider_secret "$config_tmp" "$provider" "$field" "$tmp_dir"; then
        mark_provider_group_present "$group"
        break
      fi
      if old_provider_exists "$provider" &&
        preserve_provider_optional "$config_tmp" "$provider" "$field" \
        "$type" "$tmp_dir"; then
        mark_provider_group_present "$group"
        break
      fi
      if [ "$field_required" = true ]; then
        ui_warn "⚠️ $field cannot be empty."
        continue
      fi
      break
    fi
    if [ "$secret" = true ]; then
      write_provider_secret "$config_tmp" "$field" "$value" "$tmp_dir"
    else
      write_provider_value "$config_tmp" "$field" "$type" "$value"
    fi
    mark_provider_group_present "$group"
    break
  done
}

write_provider_block() {
  local entry mode configure_optional priority
  WRITTEN_PROVIDER_SECTIONS="|"
  PROVIDER_GROUP_PRESENCE="|"
  printf '  %s:\n' "$PROVIDER" >>"$config_tmp"
  # Authentication and other required fields are collected before optional
  # presentation settings, regardless of catalog row order.
  configure_optional=true
  for priority in 1 2 3; do
    for entry in "${PROVIDER_CATALOG[@]}"; do
      write_provider_field "$entry" required "$configure_optional" \
        "$priority" || return 1
    done
  done
  # Keep at-least-one destination groups in catalog order. This lets the user
  # choose the first destination without being forced into the last row.
  for entry in "${PROVIDER_CATALOG[@]}"; do
    write_provider_field "$entry" group true 3 || return 1
  done
  if [ "${TELEMETRY_ASKED:-false}" != true ]; then
    telemetry_enabled=$(ask_yes_no \
      "📊 Send anonymous usage data to help improve kwatch" "y")
    TELEMETRY_ASKED=true
  fi
  configure_optional=$(ask_yes_no \
    "Configure optional settings for $PROVIDER too?" "y")
  for priority in 1 2 3; do
    for entry in "${PROVIDER_CATALOG[@]}"; do
      write_provider_field "$entry" optional "$configure_optional" \
        "$priority" || return 1
    done
  done
}

write_config_secret() {
  local secret_name="${CONFIG_SECRET_NAME:-${RELEASE}-config}"
  local tmp_dir config_tmp telemetry_enabled configure_alerts
  local add_provider
  local entry path type default category description status replacement value
  local encoded
  SECRET_ARGS=()
  WRITTEN_CONFIG_SECTIONS="|"
  CONFIGURED_PROVIDERS="|"
  TELEMETRY_ASKED=false
  tmp_dir=$(mktemp -d)
  config_tmp="$tmp_dir/config.yaml"
  trap 'if [ -n "${tmp_dir:-}" ]; then rm -rf "$tmp_dir"; fi' RETURN
  OLD_CONFIG_PATH="$tmp_dir/old-config.yaml"
  encoded=$(secret_data_base64 "$CONFIG_SECRET_NAME" config.yaml)
  if [ -n "$encoded" ]; then
    if ! decode_base64_file "$encoded" "$OLD_CONFIG_PATH"; then
      : >"$OLD_CONFIG_PATH"
    fi
  fi
  configure_alerts=$(ask_yes_no \
    "📣 Configure notification providers now?" "y")
  telemetry_enabled=true
  if [ "$configure_alerts" = true ]; then
    printf 'crd:\n  enabled: true\nalert:\n' >"$config_tmp"
    while true; do
      choose_provider
      select_provider_groups
      write_provider_block || return 1
      CONFIGURED_PROVIDERS="${CONFIGURED_PROVIDERS}${PROVIDER}|"
      provider_available || break
      add_provider=$(ask_yes_no "➕ Add another notification provider?" "n")
      if [ "$add_provider" != true ]; then
        break
      fi
    done
  else
    printf 'crd:\n  enabled: true\nalert: {}\n' >"$config_tmp"
  fi
  if [ "$TELEMETRY_ASKED" != true ]; then
    telemetry_enabled=$(ask_yes_no \
      "📊 Send anonymous usage data to help improve kwatch" "y")
  fi
  printf 'telemetry:\n  enabled: %s\n' "$telemetry_enabled" >>"$config_tmp"
  for entry in "${CATALOG[@]}"; do
    IFS='|' read -r path type default category description status replacement <<<"$entry"
    [ "$status" = secret ] || continue
    while true; do
      value=$(ask_secret "$description (leave empty to skip)")
      if [ -z "$value" ]; then
        preserve_config_secret "$config_tmp" "$path" "$tmp_dir" || true
        break
      fi
      if write_config_secret_value "$config_tmp" "$path" "$value" "$tmp_dir"; then
        break
      fi
      ui_warn "⚠️ $path must be a valid single-line secret value. Try again."
    done
  done
  with_loading "Saving notification configuration" apply_config_secret ||
    die "could not save the notification configuration"
  kubectl -n "$NAMESPACE" label secret "$secret_name" \
    app.kubernetes.io/instance="$RELEASE" \
    app.kubernetes.io/managed-by=kwatch.sh --overwrite >/dev/null
  CONFIG_SECRET_NAME="$secret_name"
}

apply_manifests() {
  local version="$1" tmp crd_tmp apply_tmp="" deployment existing_deployment
  local manifest_to_apply
  valid_release_version "$version" || die "invalid kwatch release version: $version"
  existing_deployment=$(deployment_name || true)
  if [ -n "$existing_deployment" ]; then
    adopt_existing_config_secret
  fi
  tmp=$(mktemp)
  crd_tmp=$(mktemp)
  trap 'rm -f "${tmp:-}" "${tmp:-}.bak" "${crd_tmp:-}" \
    "${apply_tmp:-}" "${apply_tmp:-}.bak" 2>/dev/null || true' RETURN
  with_loading "Downloading CRD for $version" curl -fsSL --location \
    --retry 3 --retry-delay 2 --connect-timeout 10 \
    "$BASE_URL/$version/deploy/crd.yaml" -o "$crd_tmp" || return 1
  with_loading "Applying CRD" kubectl apply -f "$crd_tmp" >/dev/null ||
    return 1
  with_loading "Waiting for CRD readiness" kubectl wait \
    --for=condition=Established crd/kwatchconfigs.kwatch.abahmed.dev \
    --timeout=60s >/dev/null || return 1
  preflight_config_resource
  ensure_config_resource
  with_loading "Downloading deployment for $version" curl -fsSL --location \
    --retry 3 --retry-delay 2 --connect-timeout 10 \
    "$BASE_URL/$version/deploy/deploy.yaml" -o "$tmp" || return 1
  grep -q '^kind: Deployment$' "$tmp" || return 1
  sed -i.bak \
    -e "/^kind: Namespace$/,/^---$/ s/^  name: kwatch$/  name: __KWATCH_NAMESPACE__/" \
    -e "s/^\( *name: \)kwatch$/\1$RELEASE/g" \
    -e "s/^\( *name: \)kwatch-configmap-manager$/\1${RELEASE}-configmap-manager/g" \
    -e "s/namespace: kwatch/namespace: $NAMESPACE/g" \
    -e "s/^\( *app.kubernetes.io\/instance: \)kwatch$/\1$RELEASE/g" \
    -e "s#ghcr.io/abahmed/kwatch:[^[:space:]]*#ghcr.io/abahmed/kwatch:$version#g" \
    -e "s/secretName: kwatch/secretName: $CONFIG_SECRET_NAME/g" \
    -e "s/__KWATCH_NAMESPACE__/$NAMESPACE/g" \
    "$tmp"
  manifest_to_apply="$tmp"
  if [ -n "$existing_deployment" ]; then
    # Deployment selectors are immutable. Omit the selector on updates so
    # Kubernetes preserves the selector used by an older kwatch release.
    apply_tmp=$(mktemp)
    cp "$tmp" "$apply_tmp" || return 1
    sed -i.bak \
      -e '/^  selector:$/,/^  template:$/ { /^  template:$/!d; }' \
      "$apply_tmp"
    manifest_to_apply="$apply_tmp"
  fi
  if ! with_loading "Applying kwatch Deployment" kubectl apply -f \
    "$manifest_to_apply"; then
    if [ -n "$existing_deployment" ] && recreate_deployment \
      "$existing_deployment" "$tmp"; then
      ui_success \
        "🛠️ Recreated the kwatch Deployment" \
        "while preserving configuration."
    else
      ui_error \
        "❌ Could not apply the kwatch Deployment." \
        "Existing configuration and Secrets were preserved."
      return 1
    fi
  fi
  if [ "${TLS_MONITOR_ENABLED:-false}" = true ]; then
    enable_initial_tls_monitor
  elif [ "$(config_value tlsMonitor.enabled)" = true ]; then
    verify_runtime_tls_access
  fi
  deployment=$(deployment_name)
  [ -n "$deployment" ] || deployment="$RELEASE"
  with_loading "Waiting for kwatch rollout" \
    kubectl -n "$NAMESPACE" rollout status "deployment/$deployment" \
    --timeout=5m
}

recreate_deployment() {
  local deployment="$1" manifest="$2"
  ui_warn \
    "⚠️ Existing Deployment could not be reconciled; recreating it" \
    "while preserving KwatchConfig and Secrets."
  with_loading "Removing invalid kwatch Deployment" kubectl -n "$NAMESPACE" \
    delete deployment "$deployment" --ignore-not-found --wait=true || return 1
  with_loading "Recreating kwatch Deployment" kubectl apply -f "$manifest" || {
    ui_error \
      "❌ Deployment recreation failed." \
      "KwatchConfig and Secrets were not removed."
    return 1
  }
}

verify_operational_security() {
  local deployment enforce non_root read_only no_escalation seccomp dropped secret_mode
  deployment=$(deployment_name)
  [ -n "$deployment" ] || deployment="$RELEASE"
  enforce=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.labels.pod-security\.kubernetes\.io/enforce}')
  non_root=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.containers[0].securityContext.runAsNonRoot}')
  read_only=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}')
  no_escalation=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}')
  seccomp=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.containers[0].securityContext.seccompProfile.type}')
  dropped=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.containers[0].securityContext.capabilities.drop[0]}')
  secret_mode=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.volumes[0].secret.defaultMode}')
  [ "$enforce" = restricted ] || {
    echo "namespace Pod Security enforcement is not restricted" >&2
    return 1
  }
  [ "$non_root" = true ] || {
    echo "kwatch deployment is not configured as non-root" >&2
    return 1
  }
  [ "$read_only" = true ] || {
    echo "kwatch deployment root filesystem is writable" >&2
    return 1
  }
  [ "$no_escalation" = false ] || {
    echo "kwatch deployment allows privilege escalation" >&2
    return 1
  }
  [ "$seccomp" = RuntimeDefault ] || {
    echo "kwatch deployment lacks RuntimeDefault seccomp" >&2
    return 1
  }
  [ "$dropped" = ALL ] || {
    echo "kwatch deployment does not drop all capabilities" >&2
    return 1
  }
  [ "$secret_mode" = 256 ] || {
    echo "kwatch Secret volume is not mode 0400" >&2
    return 1
  }
  echo "🛡️ Kubernetes operational protection verified."
}

apply_operational_namespace_labels() {
  local enforce audit warn managed existing_workload existing_config
  enforce=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.labels.pod-security\.kubernetes\.io/enforce}' \
    2>/dev/null || true)
  managed=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.annotations.kwatch\.dev/managed-namespace}' \
    2>/dev/null || true)
  audit=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.labels.pod-security\.kubernetes\.io/audit}' \
    2>/dev/null || true)
  warn=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.labels.pod-security\.kubernetes\.io/warn}' \
    2>/dev/null || true)
  existing_workload=$(deployment_name || true)
  existing_config=false
  if kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" >/dev/null 2>&1; then
    existing_config=true
  fi
  if { [ "$enforce" != restricted ] || [ "$audit" != restricted ] ||
    [ "$warn" != restricted ]; } && [ "$managed" != true ] &&
    [ "$NAMESPACE_CREATED" != true ] &&
    [ -z "$existing_workload" ] && [ "$existing_config" != true ] &&
    [ "${KWATCH_ALLOW_NAMESPACE_LABELS:-false}" != true ]; then
    die "namespace '$NAMESPACE' already exists without restricted Pod Security labels; set KWATCH_ALLOW_NAMESPACE_LABELS=true only after reviewing the shared namespace"
  fi
  if { [ -n "$existing_workload" ] || [ "$existing_config" = true ]; } &&
    { [ "$enforce" != restricted ] || [ "$audit" != restricted ] ||
      [ "$warn" != restricted ]; }; then
    ui_info "🔐 Existing kwatch resources found; applying restricted Pod Security labels."
  fi
  with_loading "Applying namespace security labels" kubectl label namespace \
    "$NAMESPACE" pod-security.kubernetes.io/enforce=restricted \
    pod-security.kubernetes.io/audit=restricted \
    pod-security.kubernetes.io/warn=restricted --overwrite >/dev/null ||
    die "could not apply namespace security labels"
  if [ "$NAMESPACE_CREATED" = true ]; then
    with_loading "Marking managed namespace" kubectl annotate namespace \
      "$NAMESPACE" kwatch.dev/managed-namespace=true --overwrite >/dev/null ||
      die "could not mark the managed namespace"
  fi
}

clear_managed_namespace_labels() {
  local managed enforce audit warn
  managed=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.annotations.kwatch\.dev/managed-namespace}' \
    2>/dev/null || true)
  [ "$managed" = true ] || return 0
  enforce=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.labels.pod-security\.kubernetes\.io/enforce}' \
    2>/dev/null || true)
  audit=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.labels.pod-security\.kubernetes\.io/audit}' \
    2>/dev/null || true)
  warn=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.labels.pod-security\.kubernetes\.io/warn}' \
    2>/dev/null || true)
  [ "$enforce" = restricted ] && [ "$audit" = restricted ] && \
    [ "$warn" = restricted ] || return 0
  kubectl label namespace "$NAMESPACE" \
    pod-security.kubernetes.io/enforce- \
    pod-security.kubernetes.io/audit- \
    pod-security.kubernetes.io/warn- >/dev/null 2>&1 || true
  kubectl annotate namespace "$NAMESPACE" \
    kwatch.dev/managed-namespace- >/dev/null 2>&1 || true
}

install_flow() {
  with_loading "Checking Kubernetes cluster" kubectl cluster-info >/dev/null ||
    die "cannot reach the Kubernetes cluster"
  confirm_resume
  local version
  version=$(select_release_version) || die "could not determine kwatch release from GitHub"
  maybe_load_catalog "$version" ||
    die "release catalogs are unavailable; installation cannot continue"
  require_config_catalog
  require_provider_catalog
  if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    NAMESPACE_CREATED=false
  else
    with_loading "Creating namespace $NAMESPACE" kubectl create namespace \
      "$NAMESPACE" >/dev/null || die "could not create namespace $NAMESPACE"
    NAMESPACE_CREATED=true
  fi
  apply_operational_namespace_labels
  preflight_access install
  # Adopt a legacy Deployment's mounted Secret before writing configuration so
  # upgrades modify the Secret the workload actually uses.
  adopt_existing_config_secret
  record_state preflight "$version" "cluster selected and reachable"
  ui_info "🚀 Installing kwatch $version..."
  record_state backup "$version" "creating notification Secret"
  choose_tls_monitor
  write_config_secret
  record_state apply "$version" "applying CRD and Deployment"
  if ! apply_manifests "$version" || ! verify_operational_security; then
    record_state failed "$version" "installation failed; workload cleanup attempted"
    ui_error "Installation failed; removing the workload resources that were created."
    remove_namespaced_workload
    die "installation failed; the CRD and any configuration resource were preserved"
  fi
  record_state complete "$version" "installation verified"
  ui_success "✅ kwatch is ready."
  configure_after_install
}

upgrade_flow() {
  local version
  confirm_resume
  version=$(select_release_version) || die "could not determine kwatch release from GitHub"
  maybe_load_catalog "$version" ||
    die "release catalogs are unavailable; upgrade cannot continue"
  ui_info "⬆️ Upgrading kwatch to $version..."
  apply_operational_namespace_labels
  record_state preflight "$version" "upgrade started"
  ensure_crd "$version"
  preflight_access upgrade
  preflight_config_resource
  ensure_config_resource
  backup_config
  record_state backup "$version" "configuration backup created"
  if ! migrate_legacy_silences; then
    echo "Legacy configuration migration failed; restoring the previous configuration." >&2
    restore_backup
    record_state failed "$version" "legacy configuration migration failed"
    die "upgrade migration failed"
  fi
  record_state apply "$version" "applying upgraded Deployment"
  if ! apply_manifests "$version" || ! verify_operational_security; then
    echo "Upgrade failed; restoring the previous configuration." >&2
    restore_backup
    rollback_deployment
    record_state failed "$version" "deployment rollout failed; rollback attempted"
    die "upgrade failed"
  fi
  record_state complete "$version" "upgrade verified"
  ui_success "✅ kwatch upgraded successfully."
}

status_flow() {
  echo "Context: $SELECTED_CONTEXT"
  echo "Namespace: $NAMESPACE"
  echo "Configuration catalog: $CATALOG_SOURCE"
  kubectl -n "$NAMESPACE" get deployment,pod \
    -l "app.kubernetes.io/instance=$RELEASE,app.kubernetes.io/managed-by=kwatch.sh" \
    2>/dev/null || \
    kubectl -n "$NAMESPACE" get deployment,pod \
      -l 'app=kwatch,app.kubernetes.io/managed-by=kwatch.sh' 2>/dev/null || true
  kubectl -n "$NAMESPACE" get configmap "$STATE_CONFIGMAP_NAME" \
    -o 'custom-columns=PHASE:.data.phase,VERSION:.data.version,MESSAGE:.data.message' \
    --no-headers 2>/dev/null || echo "Manager state: not available"
}

uninstall_flow() {
  local confirm secret_owner
  confirm=$(ask "Type uninstall to remove kwatch" "")
  [ "$confirm" = uninstall ] || { echo "Cancelled."; return; }
  echo "🧹 Removing kwatch resources from namespace '$NAMESPACE'; other namespace resources will be preserved." >&2
  remove_namespaced_workload
  secret_owner=$(kubectl -n "$NAMESPACE" get secret "$CONFIG_SECRET_NAME" \
    -o 'jsonpath={.metadata.labels.app\.kubernetes\.io/managed-by}' \
    2>/dev/null || true)
  if [ "$secret_owner" = kwatch.sh ]; then
    kubectl -n "$NAMESPACE" delete secret "$CONFIG_SECRET_NAME" \
      --ignore-not-found
  else
    echo "Preserving unowned Secret '$CONFIG_SECRET_NAME'." >&2
  fi
  clear_managed_namespace_labels
  echo "✅ kwatch workload removed. KwatchConfig, backups, namespace, and CRD were preserved." >&2
}

main() {
  local action="${1:-}" installed
  case "$action" in
    --help|-h)
      echo "Usage: kwatch.sh [install|configure-alert|configure|upgrade|status|features|uninstall]"
      echo "🧭 Interactive kubectl manager with operational security checks."
      exit 0
      ;;
    --version|-v)
      echo "kwatch manager catalog $CATALOG_VERSION"
      exit 0
      ;;
  esac
  require_tools
  select_context
  if [ -z "$action" ]; then
    installed=$(deployment_name || true)
    if managed_install_present; then
      if ! maybe_load_catalog; then
        ui_warn "⚠️ Catalogs are unavailable; configuration actions will require a retry."
      fi
      migration_notice
      if [ -n "$installed" ]; then
        ui_success "✅ kwatch installation detected."
      else
        ui_info "🧭 kwatch configuration detected without a running Deployment."
      fi
      cat >&2 <<'EOF'

kwatch manager:
  1) Configure notification providers
  2) Configure settings
  3) Upgrade or repair workload
  4) Show status
  5) Show capabilities
  6) Uninstall
  7) Exit
EOF
      while true; do
        action=$(ask "Choice" "1")
        case "$action" in
          1) action=configure-alert; break ;;
          2) action=configure; break ;;
          3) action=upgrade; break ;;
          4) action=status; break ;;
          5) action=features; break ;;
          6) action=uninstall; break ;;
          7) exit 0 ;;
          *) ui_warn "⚠️ Choose a number from 1 to 7." ;;
        esac
      done
    else
      action=install
    fi
  else
    action=$(resolve_action "$action")
    case "$action" in
      install|upgrade|uninstall) ;;
      *)
        if ! maybe_load_catalog; then
          ui_warn "⚠️ Catalogs are unavailable; configuration actions will require a retry."
        fi
        migration_notice
        ;;
    esac
  fi
  case "$action" in
    install) install_flow ;; configure-alert) configure_alert_flow ;; configure) configure_flow ;; upgrade) upgrade_flow ;;
    status) status_flow ;; features) features_flow ;; uninstall) uninstall_flow ;;
    *) die "usage: $0 [install|configure-alert|configure|upgrade|status|features|uninstall]" ;;
  esac
}

if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
