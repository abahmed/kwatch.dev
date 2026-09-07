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
SUPPORTED_CATALOG_VERSION=1
SUPPORTED_FEATURE_CATALOG_VERSION=1
SUPPORTED_PROVIDER_CATALOG_VERSION=1
MAX_KUBECTL_ATTEMPTS=3
SELECTED_CONTEXT=""
INSTALL_STATE=""
INSTALL_DEPLOYMENT=""
INSTALL_VERSION=""
INSTALL_REASON=""
LAST_COMMAND_ERROR=""
FRESH_INSTALL=false
MIGRATION_TARGET_VERSION=""
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
back_hint() { printf '%s(↩️ type back)%s' "$UI_DIM" "$UI_RESET"; }
back_label() { printf '%s↩️ Back%s' "$UI_CYAN" "$UI_RESET"; }
exit_label() { printf '%s🚪 Exit%s' "$UI_DIM" "$UI_RESET"; }
ui_heading() {
  printf '\n%s%s%s\n' "$UI_BOLD$UI_CYAN" "$*" "$UI_RESET" >&2
}
ui_menu() {
  local item
  for item in "$@"; do
    printf '%s%s%s\n' "$UI_CYAN" "$item" "$UI_RESET" >&2
  done
}
ui_detail() { printf '%s%s%s\n' "$UI_DIM" "$*" "$UI_RESET" >&2; }

with_loading() {
  local label="$1"; shift
  local command_name="${1:-command}"
  local output_file error_file pid frame=0 index char rc diagnostic
  local -a spinner_frames=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
  LAST_COMMAND_ERROR=""
  if [ ! -t 2 ] || [ "${KWATCH_PLAIN_UI:-false}" = true ]; then
    error_file=$(mktemp)
    if "$@" 2>"$error_file"; then
      cat "$error_file" >&2
      rm -f "$error_file"
      return 0
    else
      rc=$?
      diagnostic=$(cat "$error_file" || true)
      LAST_COMMAND_ERROR=$(printf '%s\n' "$diagnostic" |
        sed '/^[[:space:]]*$/d' | tail -20 || true)
      [ -n "$LAST_COMMAND_ERROR" ] ||
        LAST_COMMAND_ERROR="$label failed (exit status $rc) while running $command_name; no diagnostic was returned."
      cat "$error_file" >&2
      rm -f "$error_file"
      return "$rc"
    fi
  fi
  output_file=$(mktemp)
  error_file=$(mktemp)
  "$@" >"$output_file" 2>"$error_file" &
  pid=$!
  trap 'kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; \
    rm -f "$output_file" "$error_file"; \
    printf "%s" "$UI_CLEAR_LINE" >&2; exit 130' INT
  trap 'kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; \
    rm -f "$output_file" "$error_file"; \
    printf "%s" "$UI_CLEAR_LINE" >&2; exit 143' TERM
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
  trap - INT TERM
  if [ "$rc" -eq 0 ]; then
    printf '%s%s✅ %s%s%s\n' "$UI_CLEAR_LINE" "$UI_GREEN" "$label" "$UI_RESET" "$UI_CLEAR" >&2
    cat "$output_file"
    cat "$error_file" >&2
    rm -f "$output_file" "$error_file"
    return 0
  fi
  printf '%s%s❌ %s%s%s\n' "$UI_CLEAR_LINE" "$UI_RED" "$label" "$UI_RESET" "$UI_CLEAR" >&2
  LAST_COMMAND_ERROR=$(cat "$error_file" "$output_file" |
    sed '/^[[:space:]]*$/d' | tail -20 || true)
  if [ -z "$LAST_COMMAND_ERROR" ]; then
    LAST_COMMAND_ERROR="$label failed (exit status $rc) while running $command_name; no diagnostic was returned."
  fi
  cat "$output_file"
  cat "$error_file" >&2
  rm -f "$output_file" "$error_file"
  return "$rc"
}

die() { ui_error "Error: $*"; exit 1; }
need() { type -P "$1" >/dev/null 2>&1 || die "'$1' is required"; }
require_tools() { need kubectl; need curl; }
ask() {
  local prompt="$1" default="${2:-}" answer
  [ -n "$default" ] && prompt="$prompt [$default]"
  printf '%s%s%s%s: ' "$UI_BOLD" "$UI_CYAN" "$prompt" "$UI_RESET" >&2
  if ! IFS= read -r answer; then
    printf '\n' >&2
    die "input ended before the operation was complete"
  fi
  printf '%s' "${answer:-$default}"
}
ask_secret() {
  local prompt="$1" answer
  printf '%s%s%s%s: ' "$UI_BOLD" "$UI_CYAN" "$prompt" "$UI_RESET" >&2
  if ! IFS= read -r -s answer; then
    printf '\n' >&2
    die "input ended before the operation was complete"
  fi
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

is_back_choice() {
  case "$1" in
    b|B|back|Back|BACK) return 0 ;;
    *) return 1 ;;
  esac
}

ask_yes_no_or_back() {
  local prompt="$1" default="$2" answer
  while true; do
    answer=$(ask "$prompt $(back_hint)" "$default")
    is_back_choice "$answer" && return 2
    case "$answer" in
      y|Y|yes|Yes) printf 'true'; return 0 ;;
      n|N|no|No) printf 'false'; return 0 ;;
      *) ui_warn "⚠️ Please answer yes, no, or back." ;;
    esac
  done
}

confirm_action() {
  local prompt="$1" default="${2:-n}"
  [ "$(ask_yes_no "$prompt" "$default")" = true ]
}

confirm_change() {
  local title="$1" details="$2" answer
  ui_heading "⚠️ Confirmation required"
  ui_warn "$title"
  ui_detail "$details"
  if answer=$(ask_yes_no_or_back "Do you want to continue" "n"); then
    [ "$answer" = true ]
    return
  fi
  return 1
}

confirm_repair() {
  local action="$1" details="$2"
  confirm_change "🛠️ The manager can $action." \
    "$details No changes will be made unless you answer yes."
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

failure_hint() {
  local diagnostic
  diagnostic=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$diagnostic" in
    *forbidden*|*unauthorized*|*permission*denied*)
      printf '%s' "Kubernetes denied this operation. Check your account and RBAC permissions." ;;
    *immutable*|*field\ is\ immutable*|*invalid\ value*)
      printf '%s' "Kubernetes rejected a field that cannot be changed in place. Review the resources." ;;
    *imagepullbackoff*|*errimagepull*|*pull\ access\ denied*)
      printf '%s' "The cluster could not pull the kwatch image. Check registry access and network policy." ;;
    *timeout*|*timed\ out*|*connection\ refused*|*unavailable*)
      printf '%s' "The Kubernetes API or rollout did not respond in time. Check connectivity and nodes." ;;
    *admission*|*webhook*|*podsecurity*|*violat*)
      printf '%s' "An admission or Pod Security policy rejected the resource. Review that policy." ;;
    *)
      printf '%s' "Review the Kubernetes details below; no safe automatic fix was identified." ;;
  esac
}

failure_fix() {
  local diagnostic
  diagnostic=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$diagnostic" in
    *forbidden*|*unauthorized*|*permission*denied*)
      printf '%s' "Use a Kubernetes identity allowed to create, patch, and delete kwatch resources; the manager will not grant cluster-admin automatically." ;;
    *immutable*|*field\ is\ immutable*)
      printf '%s' "Approve Deployment recreation when offered; KwatchConfig and Secrets are preserved." ;;
    *imagepullbackoff*|*errimagepull*|*pull\ access\ denied*)
      printf '%s' "Make the kwatch image reachable from the cluster or configure the required imagePullSecret, then retry." ;;
    *timeout*|*timed\ out*|*connection\ refused*|*unavailable*|*too\ many\ requests*|*rate\ limit*)
      printf '%s' "Check API/network health; the manager can safely retry this operation after you approve it." ;;
    *admission*|*webhook*|*podsecurity*|*violat*)
      printf '%s' "Ask the cluster administrator to allow the kwatch manifest or namespace policy, then retry." ;;
    *)
      printf '%s' "Review the details and events, correct the named resource or permission, then run the manager again." ;;
  esac
}

failure_is_retryable() {
  local diagnostic
  diagnostic=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$diagnostic" in
    *timeout*|*timed\ out*|*connection\ refused*|*connection\ reset*|*unavailable*|*too\ many\ requests*|*rate\ limit*) return 0 ;;
  esac
  return 1
}

show_failure_diagnostics() {
  local operation="$1" reason="$2" deployment pod pods
  ui_heading "🔎 $operation diagnostics"
  ui_error "❌ Kubernetes reported: $reason"
  ui_info "💡 Likely cause: $(failure_hint "$reason")"
  ui_info "🛠️ Recommended fix: $(failure_fix "$reason")"
  ui_detail "The following read-only checks help identify the exact cause."
  deployment=$(deployment_name || true)
  if [ -z "$deployment" ]; then
    deployment=$(kubectl -n "$NAMESPACE" get deployment "$RELEASE" \
      -o jsonpath='{.metadata.name}' 2>/dev/null || true)
  fi
  if [ -n "$deployment" ]; then
    ui_detail "📦 Deployment: $NAMESPACE/$deployment"
    kubectl -n "$NAMESPACE" describe deployment "$deployment" 2>/dev/null ||
      ui_detail "Deployment details are unavailable."
    pods=$(kubectl -n "$NAMESPACE" get pods \
      -l "app.kubernetes.io/instance=$RELEASE" \
      -o 'jsonpath={range .items[*]}{.metadata.name}{"\n"}{end}' \
      2>/dev/null || true)
    [ -n "$pods" ] || pods=$(kubectl -n "$NAMESPACE" get pods \
      -l app=kwatch \
      -o 'jsonpath={range .items[*]}{.metadata.name}{"\n"}{end}' \
      2>/dev/null || true)
    while IFS= read -r pod; do
      [ -n "$pod" ] || continue
      ui_detail "🧩 Pod: $NAMESPACE/$pod"
      kubectl -n "$NAMESPACE" describe pod "$pod" 2>/dev/null || true
    done <<< "$pods"
  fi
  ui_detail "🕒 Recent namespace events:"
  kubectl -n "$NAMESPACE" get events --sort-by=.lastTimestamp \
    2>/dev/null | tail -20 || ui_detail "Namespace events are unavailable."
}

kubectl() {
  local attempt=1 diagnostic rc retryable=true stdout_file stderr_file
  [ -t 0 ] || retryable=false
  stdout_file=$(mktemp)
  stderr_file=$(mktemp)
  while [ "$attempt" -le "$MAX_KUBECTL_ATTEMPTS" ]; do
    : >"$stdout_file"
    : >"$stderr_file"
    if command kubectl --context "$SELECTED_CONTEXT" "$@" \
      >"$stdout_file" 2>"$stderr_file"; then
      cat "$stdout_file"
      cat "$stderr_file" >&2
      rm -f "$stdout_file" "$stderr_file"
      return 0
    else
      rc=$?
    fi
    diagnostic=$(cat "$stderr_file" "$stdout_file")
    cat "$stdout_file"
    cat "$stderr_file" >&2
    if ! is_transient_kubectl_error "$diagnostic" ||
      [ "$attempt" = "$MAX_KUBECTL_ATTEMPTS" ] ||
      [ "$retryable" = false ]; then
      rm -f "$stdout_file" "$stderr_file"
      return "$rc"
    fi
    ui_warn \
      "⚠️ Temporary Kubernetes error; retrying" \
      "($((attempt + 1))/$MAX_KUBECTL_ATTEMPTS)..."
    sleep $((attempt * 2))
    attempt=$((attempt + 1))
  done
  rm -f "$stdout_file" "$stderr_file"
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
    ui_heading "🧭 Select the Kubernetes cluster to manage"
    for index in "${!contexts[@]}"; do
      if [ "${contexts[$index]}" = "$current" ]; then
        ui_menu "  $((index + 1))) ${contexts[$index]} ${UI_GREEN}(current)${UI_RESET}"
        default_choice=$((index + 1))
      else
        ui_menu "  $((index + 1))) ${contexts[$index]}"
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
  for entry in "${CATALOG[@]-}"; do
    IFS='|' read -r path type default category description status replacement <<<"$entry"
    [ "$path" = "$wanted" ] && { printf '%s\n' "$entry"; return; }
  done
}

load_catalog_file() {
  local file="$1" entry path type default category description status replacement
  local catalog_version="" seen="|"
  local -a loaded=()
  while IFS= read -r entry || [ -n "$entry" ]; do
    if [[ "$entry" =~ ^#\ kwatch\ config\ catalog\ v([0-9]+)$ ]]; then
      catalog_version="${BASH_REMATCH[1]}"
      continue
    fi
    [[ -z "$entry" || "$entry" = \#* ]] && continue
    IFS='|' read -r path type default category description status replacement <<<"$entry"
    [ -n "$path" ] && [ -n "$type" ] && [ -n "$category" ] && [ -n "$description" ] || return 1
    case "$type" in
      boolean|float|integer|json|list|string) ;;
      *) return 1 ;;
    esac
    case "$status" in
      active|deprecated|secret) ;;
      *) return 1 ;;
    esac
    case "$seen" in
      *"|$path|"*) return 1 ;;
    esac
    seen="${seen}${path}|"
    loaded+=("$entry")
  done < "$file"
  [ "$catalog_version" = "$SUPPORTED_CATALOG_VERSION" ] || return 1
  [ "${#loaded[@]}" -gt 0 ] || return 1
  CATALOG_VERSION="$catalog_version"
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

download_catalog_artifact() {
  local url="$1" destination="$2"
  curl -fsSL --location --retry 2 --retry-delay 1 --connect-timeout 8 \
    "$url" -o "$destination" 2>/dev/null
}

load_catalog_for_version() {
  local version="${1:-}" tmp cached cached_source
  tmp=$(mktemp)
  trap 'if [ -n "${tmp:-}" ]; then rm -f "$tmp"; fi' RETURN
  if [ -n "$version" ] && with_loading "Loading configuration catalog" \
      download_catalog_artifact \
      "$BASE_URL/$version/deploy/config-catalog.tsv" "$tmp" \
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
  local catalog_version="" seen="|"
  local -a loaded=()
  while IFS= read -r entry || [ -n "$entry" ]; do
    if [[ "$entry" =~ ^#\ kwatch\ feature\ catalog\ v([0-9]+)$ ]]; then
      catalog_version="${BASH_REMATCH[1]}"
      continue
    fi
    [[ -z "$entry" || "$entry" = \#* ]] && continue
    IFS='|' read -r id lifecycle description dependencies <<<"$entry"
    [ -n "$id" ] && \
      [ "$lifecycle" = startup -o "$lifecycle" = runtime ] && \
      [ -n "$description" ] || return 1
    case "$seen" in
      *"|$id|"*) return 1 ;;
    esac
    seen="${seen}${id}|"
    loaded+=("$entry")
  done < "$file"
  [ "$catalog_version" = "$SUPPORTED_FEATURE_CATALOG_VERSION" ] || return 1
  [ "${#loaded[@]}" -gt 0 ] || return 1
  FEATURE_CATALOG_VERSION="$catalog_version"
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
      download_catalog_artifact \
      "$BASE_URL/$version/deploy/feature-catalog.tsv" "$tmp" \
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
  local catalog_version="" seen="|"
  local -a loaded=()
  while IFS= read -r entry || [ -n "$entry" ]; do
    if [[ "$entry" =~ ^#\ kwatch\ provider\ catalog\ v([0-9]+)$ ]]; then
      catalog_version="${BASH_REMATCH[1]}"
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
    case "$validation" in
      ""|boolean|integer|json|list|port|signed-integer|url) ;;
      one-of:*) [ -n "${validation#one-of:}" ] || return 1 ;;
      *) return 1 ;;
    esac
    case "$seen" in
      *"|$provider.$field|"*) return 1 ;;
    esac
    seen="${seen}${provider}.${field}|"
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
  [ "$catalog_version" = "$SUPPORTED_PROVIDER_CATALOG_VERSION" ] || return 1
  [ "${#loaded[@]}" -gt 0 ] || return 1
  PROVIDER_CATALOG_VERSION="$catalog_version"
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
      download_catalog_artifact \
      "$BASE_URL/$version/deploy/provider-catalog.tsv" "$tmp" \
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
LEGACY_BACKUP_NAME=""
backup_config() {
  local resource timestamp
  resource=$(kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" -o json)
  timestamp=$(date -u +%Y%m%d%H%M%S)
  BACKUP_NAME="${RELEASE}-config-$timestamp"
  kubectl -n "$NAMESPACE" create secret generic "$BACKUP_NAME" \
    --from-literal=resource.json="$resource" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

backup_legacy_install() {
  local timestamp tmp_dir metadata_file cache_path
  local -a files=()
  timestamp=$(date -u +%Y%m%d%H%M%S)
  LEGACY_BACKUP_NAME="${RELEASE}-legacy-backup-$timestamp"
  tmp_dir=$(mktemp -d)
  trap 'if [ -n "${tmp_dir:-}" ]; then rm -rf "$tmp_dir"; fi' RETURN
  metadata_file="$tmp_dir/metadata.txt"
  cat >"$metadata_file" <<EOF
context=$SELECTED_CONTEXT
namespace=$NAMESPACE
release=$RELEASE
installed-version=${INSTALL_VERSION:-unknown}
target-version=${MIGRATION_TARGET_VERSION:-unknown}
created-at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
  files+=(--from-file=metadata.txt="$metadata_file")

  if kubectl -n "$NAMESPACE" get deployment "${INSTALL_DEPLOYMENT:-$RELEASE}" \
    -o yaml >"$tmp_dir/deployment.yaml" 2>/dev/null; then
    files+=(--from-file=deployment.yaml="$tmp_dir/deployment.yaml")
  fi
  if kubectl -n "$NAMESPACE" get configmap "$RELEASE" \
    -o yaml >"$tmp_dir/legacy-configmap.yaml" 2>/dev/null; then
    files+=(--from-file=legacy-configmap.yaml="$tmp_dir/legacy-configmap.yaml")
  fi
  if kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" \
    -o yaml >"$tmp_dir/kwatchconfig.yaml" 2>/dev/null; then
    files+=(--from-file=kwatchconfig.yaml="$tmp_dir/kwatchconfig.yaml")
  fi
  if kubectl -n "$NAMESPACE" get secret "$CONFIG_SECRET_NAME" \
    -o yaml >"$tmp_dir/config-secret.yaml" 2>/dev/null; then
    files+=(--from-file=config-secret.yaml="$tmp_dir/config-secret.yaml")
  fi
  if kubectl -n "$NAMESPACE" get configmap "$STATE_CONFIGMAP_NAME" \
    -o yaml >"$tmp_dir/manager-state.yaml" 2>/dev/null; then
    files+=(--from-file=manager-state.yaml="$tmp_dir/manager-state.yaml")
  fi
  if kubectl -n "$NAMESPACE" get configmap "$CATALOG_CACHE_NAME" \
    -o yaml >"$tmp_dir/config-catalog-cache.yaml" 2>/dev/null; then
    files+=(
      --from-file=config-catalog-cache.yaml="$tmp_dir/config-catalog-cache.yaml"
    )
  fi
  if kubectl -n "$NAMESPACE" get configmap "$FEATURE_CATALOG_CACHE_NAME" \
    -o yaml >"$tmp_dir/feature-catalog-cache.yaml" 2>/dev/null; then
    cache_path="$tmp_dir/feature-catalog-cache.yaml"
    files+=("--from-file=feature-catalog-cache.yaml=$cache_path")
  fi
  if kubectl -n "$NAMESPACE" get configmap "$PROVIDER_CATALOG_CACHE_NAME" \
    -o yaml >"$tmp_dir/provider-catalog-cache.yaml" 2>/dev/null; then
    cache_path="$tmp_dir/provider-catalog-cache.yaml"
    files+=("--from-file=provider-catalog-cache.yaml=$cache_path")
  fi

  [ "${#files[@]}" -gt 1 ] ||
    die "could not collect legacy kwatch configuration"
  kubectl -n "$NAMESPACE" create secret generic "$LEGACY_BACKUP_NAME" \
    "${files[@]}" \
    --from-literal=backup-kind=legacy-install \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null ||
    die "could not create the legacy kwatch backup"
  kubectl -n "$NAMESPACE" label secret "$LEGACY_BACKUP_NAME" \
    app.kubernetes.io/instance="$RELEASE" \
    app.kubernetes.io/managed-by=kwatch.sh \
    kwatch.dev/backup-kind=legacy-install --overwrite >/dev/null ||
    die "could not label the legacy kwatch backup"
  ui_success "✅ Legacy configuration backup created."
  ui_info "📦 Backup Secret: $NAMESPACE/$LEGACY_BACKUP_NAME"
  ui_info \
    "🔎 Inspect it with: kubectl -n $NAMESPACE get secret $LEGACY_BACKUP_NAME"
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

restore_backup_after_failure() {
  local details="$1"
  if confirm_repair \
    "restore the previous configuration" \
    "$details The saved backup will be applied and kwatch will be restarted."; then
    restore_backup
    return 0
  fi
  ui_warn "⚠️ Configuration restore skipped; the current state was left in place."
  return 1
}

config_value() {
  local path="$1"
  kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" \
    -o "jsonpath={.spec.$path}" 2>/dev/null || true
}

migrate_legacy_telemetry() {
  local current encoded tmp old_path value
  current=$(config_value telemetry.enabled)
  case "$current" in
    true|false) return 0 ;;
  esac
  encoded=$(secret_data_base64 "$CONFIG_SECRET_NAME" config.yaml || true)
  [ -n "$encoded" ] || return 0
  tmp=$(mktemp)
  trap 'if [ -n "${tmp:-}" ]; then rm -f "$tmp"; fi' RETURN
  decode_base64_file "$encoded" "$tmp" || return 0
  old_path="${OLD_CONFIG_PATH:-}"
  OLD_CONFIG_PATH="$tmp"
  value=$(old_config_value telemetry.enabled || true)
  OLD_CONFIG_PATH="$old_path"
  case "$value" in
    true|false)
      patch_config_value telemetry.enabled boolean "$value" || return 1
      ui_info "🔧 Preserved the existing telemetry setting in KwatchConfig."
      ;;
  esac
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

old_config_value() {
  local path="$1" parent child
  [ -s "${OLD_CONFIG_PATH:-}" ] || return 1
  parent="${path%%.*}"
  child="${path#*.}"
  awk -v parent="$parent:" -v child="  $child:" '
    $0 == parent { in_parent=1; next }
    in_parent && $0 ~ /^[^ ]/ { exit }
    in_parent && index($0, child) == 1 {
      value=substr($0, length(child) + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^"|"$/, "", value)
      print value
      exit
    }
  ' "$OLD_CONFIG_PATH"
}

existing_provider_names() {
  local provider display entry catalog_provider
  [ -s "${OLD_CONFIG_PATH:-}" ] || return 0
  while IFS= read -r provider; do
    display="$provider"
    for entry in "${PROVIDER_CATALOG[@]}"; do
      IFS='|' read -r catalog_provider display _ <<<"$entry"
      [ "$catalog_provider" = "$provider" ] && break
      display="$provider"
    done
    printf '%s|%s\n' "$provider" "$display"
  done < <(awk '
    $0 == "alert:" { in_alert=1; next }
    in_alert && $0 ~ /^[^ ]/ { exit }
    in_alert && $0 ~ /^  [^ ][^:]*:$/ {
      name=$0
      sub(/^  /, "", name)
      sub(/:$/, "", name)
      print name
    }
  ' "$OLD_CONFIG_PATH")
}

preserve_provider_block() {
  local file="$1" provider="$2" tmp_dir="$3" block ref key
  [ -s "${OLD_CONFIG_PATH:-}" ] || return 1
  block=$(awk -v provider="  $provider:" '
    $0 == provider { found=1 }
    found && $0 ~ /^  [^ ]/ && $0 != provider { exit }
    found { print }
  ' "$OLD_CONFIG_PATH")
  [ -n "$block" ] || return 1
  while IFS= read -r ref; do
    key="${ref##*/}"
    key="${key%\}}"
    [ -n "$key" ] || continue
    preserve_secret_file "$key" "$tmp_dir" || return 1
  done < <(printf '%s\n' "$block" | grep -o '\${file:[^}]*}' || true)
  printf '%s\n' "$block" >>"$file"
}

provider_in_catalog() {
  local wanted="$1" entry provider
  for entry in "${PROVIDER_CATALOG[@]}"; do
    IFS='|' read -r provider _ <<<"$entry"
    [ "$provider" = "$wanted" ] && return 0
  done
  return 1
}

old_provider_plain_value() {
  local provider="$1" field="$2" block value
  block=$(old_provider_field_block "$provider" "$field" "$OLD_CONFIG_PATH")
  [ -n "$block" ] || return 1
  value="${block#*:}"
  value="${value#${value%%[![:space:]]*}}"
  value="${value%${value##*[![:space:]]}}"
  case "$value" in
    \$\{file:*) return 1 ;;
    \"*\") value="${value#\"}"; value="${value%\"}" ;;
    \'*\') value="${value#\'}"; value="${value%\'}" ;;
  esac
  [ -n "$value" ] || return 1
  value="${value//\\\"/\"}"
  value="${value//\\\\/\\}"
  printf '%s' "$value"
}

preserve_provider_from_catalog() {
  local file="$1" provider="$2" tmp_dir="$3" entry catalog_provider
  local display field type required secret validation default description
  local group condition value previous_provider
  previous_provider="${PROVIDER:-}"
  PROVIDER="$provider"
  WRITTEN_PROVIDER_SECTIONS="|"
  printf '  %s:\n' "$provider" >>"$file"
  for entry in "${PROVIDER_CATALOG[@]}"; do
    IFS='|' read -r catalog_provider display field type required secret \
      validation default description group condition <<<"$entry"
    [ "$catalog_provider" = "$provider" ] || continue
    if [ "$secret" = true ]; then
      if preserve_provider_secret "$file" "$provider" "$field" "$tmp_dir"; then
        continue
      fi
      value=$(old_provider_plain_value "$provider" "$field" || true)
      [ -n "$value" ] || continue
      write_provider_secret "$file" "$field" "$value" "$tmp_dir"
      continue
    fi
    preserve_provider_optional "$file" "$provider" "$field" "$type" \
      "$tmp_dir" || true
  done
  PROVIDER="$previous_provider"
}

preserve_existing_providers() {
  local file="$1" tmp_dir="$2" only_unselected="${3:-false}"
  local provider display preserved=false
  while IFS='|' read -r provider display; do
    [ -n "$provider" ] || continue
    if [ "$only_unselected" = true ]; then
      case "$CONFIGURED_PROVIDERS" in
        *"|$provider|"*) continue ;;
      esac
    fi
    if provider_in_catalog "$provider"; then
      preserve_provider_from_catalog "$file" "$provider" "$tmp_dir"
    else
      preserve_provider_block "$file" "$provider" "$tmp_dir" ||
        die "could not safely preserve existing provider $display"
    fi
    preserved=true
  done < <(existing_provider_names)
  [ "$preserved" = true ]
}

has_unselected_existing_provider() {
  local provider display
  while IFS='|' read -r provider display; do
    case "$CONFIGURED_PROVIDERS" in
      *"|$provider|"*) ;;
      *) return 0 ;;
    esac
  done < <(existing_provider_names)
  return 1
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
    count=$(ask "Number of custom webhook headers $(back_hint)" "0")
    is_back_choice "$count" && return 2
    [[ "$count" =~ ^[0-9]+$ ]] && break
    ui_warn "⚠️ Header count must be a non-negative integer."
  done
  [ "$count" -gt 0 ] || return 0
  printf '    headers:\n' >>"$file"
  for ((i = 1; i <= count; i++)); do
    while true; do
      name=$(ask "Header $i name $(back_hint)")
      is_back_choice "$name" && return 2
      [ -n "$name" ] && break
      ui_warn "⚠️ Header name cannot be empty."
    done
    while true; do
      value=$(ask_secret "Header $i value $(back_hint)")
      is_back_choice "$value" && return 2
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
    ui_error "❌ Cannot verify TLS access: kwatch deployment was not found."
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
        ui_error \
          "❌ TLS monitoring needs the kwatch ServiceAccount to $verb Secrets; RBAC is missing."
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
    { ui_error "❌ Could not enable TLS monitoring in KwatchConfig."; return 1; }
  verify_runtime_tls_access
}

show_catalog_entry() {
  local entry="$1" path type default category description status replacement current
  IFS='|' read -r path type default category description status replacement <<<"$entry"
  current=$(config_value "$path")
  [ -n "$current" ] || current="default ($default)"
  ui_heading "⚙️ $path"
  ui_detail "$description"
  ui_detail "Type: $type | Current: $current | Default: $default"
  if [ "$status" = deprecated ]; then
    ui_warn "⚠️ Deprecated: use $replacement instead."
  fi
}

migration_notice() {
  local schema entry path type default category description status replacement current
  [ "${#CATALOG[@]}" -gt 0 ] || return 0
  schema=$(kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" \
    -o 'jsonpath={.metadata.labels.kwatch\.dev/config-schema}' 2>/dev/null || true)
  if [ -n "$schema" ] && [ "$schema" -lt "$CATALOG_VERSION" ] 2>/dev/null; then
    ui_warn \
      "⚠️ Configuration schema $schema is older than this manager's schema $CATALOG_VERSION."
    ui_info "ℹ️ New settings use documented defaults; existing settings are preserved."
  fi
  for entry in "${CATALOG[@]-}"; do
    IFS='|' read -r path type default category description status replacement <<<"$entry"
    [ "$status" = deprecated ] || continue
    current=$(config_value "$path")
    [ -n "$current" ] &&
      ui_warn "⚠️ Deprecated config detected: $path (use $replacement)"
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
  ui_success "✅ Legacy ignore settings migrated into scoped silences."
}

configure_flow() {
  local deployment
  require_config_catalog
  confirm_change \
    "⚙️ The manager will prepare the configuration for editing." \
    "It may create the configuration resource and save a backup; the selected setting will be confirmed again before it is changed." || {
    ui_info "↩️ Configuration editing cancelled; no changes were made."
    return 0
  }
  ensure_crd
  preflight_access manage
  preflight_config_resource
  ensure_config_resource
  migrate_legacy_telemetry ||
    die "could not preserve the existing telemetry setting"
  backup_config
  if ! migrate_legacy_silences; then
    ui_error "❌ Legacy configuration migration failed; the previous configuration can be restored."
    restore_backup_after_failure \
      "This reverses the legacy settings migration that just failed." || true
    die "configuration migration failed"
  fi
  while true; do
    ui_heading "⚙️ kwatch configuration"
    ui_menu "1) 🚨 Alerts" "2) 🎯 Scope" "3) ⚡ Performance" \
      "4) 🧠 Incident memory" "5) 🔇 Noise reduction" "6) 🔍 Monitors" \
      "7) 🛠️ Operations" "8) 🔄 Compatibility" "9) 🎛️ Product control" \
      "10) 🔒 Security" "11) $(back_label)"
    local choice category entry path type default category_name description status replacement current value
    choice=$(ask "Category" "1")
    case "$choice" in
      1) category="Alerts" ;; 2) category="Scope" ;; 3) category="Performance" ;;
      4) category="Incident memory" ;; 5) category="Noise reduction" ;; 6) category="Monitors" ;;
      7) category="Operations" ;; 8) category="Compatibility" ;; 9) category="Product control" ;;
      10) category="Security" ;; 11) return ;;
      *) echo "Unknown choice"; continue ;;
    esac
    ui_heading "📋 $category settings"
    local i=1 display_value prompt_default
    for entry in "${CATALOG[@]}"; do
      IFS='|' read -r path type default category_name description status replacement <<<"$entry"
      [ "$category_name" = "$category" ] || continue
      current=$(config_value "$path")
      display_value="$current"
      [ -n "$display_value" ] || display_value="default ($default)"
      ui_menu "$i) ⚙️ $path — $display_value"
      i=$((i + 1))
    done
    choice=$(ask "Setting $(back_hint)" "")
    is_back_choice "$choice" && continue
    [ "$choice" -ge 1 ] 2>/dev/null || { echo "Unknown setting"; continue; }
    i=1
    for entry in "${CATALOG[@]}"; do
      IFS='|' read -r path type default category_name description status replacement <<<"$entry"
      [ "$category_name" = "$category" ] || continue
      if [ "$i" = "$choice" ]; then
        if [ "$status" = secret ]; then
          ui_info "🔐 Secret-backed settings are changed with Edit notification providers."
          break
        fi
        current=$(config_value "$path")
        show_catalog_entry "$entry"
        [ "$status" = deprecated ] &&
          ui_warn "⚠️ Existing values are preserved; migration is not destructive."
        prompt_default="$current"
        [ -n "$prompt_default" ] || prompt_default="$default"
        value=$(ask "New value (Enter keeps current) $(back_hint)" \
          "$prompt_default")
        is_back_choice "$value" && continue
        [ -n "$value" ] || continue
        confirm_change \
          "⚙️ Change $path to '$value'." \
          "The current value is '$current'. kwatch will validate the new value and restart the workload if needed." || {
          ui_info "↩️ Keeping the existing value for $path."
          continue
        }
        backup_config
        if ! patch_config_value "$path" "$type" "$value"; then
          ui_error "❌ Invalid configuration value; the previous configuration can be restored."
          restore_backup_after_failure \
            "The attempted value was rejected by Kubernetes." || true
          continue
        fi
        if [ "$path" = tlsMonitor.enabled ] && [ "$value" = true ]; then
          if ! verify_runtime_tls_access; then
            ui_error "❌ TLS monitoring was not enabled because the deployed ServiceAccount lacks Secret access."
            restore_backup_after_failure \
              "TLS monitoring requires Secret access that is not available." || true
            die "TLS RBAC validation failed"
          fi
        fi
        kubectl -n "$NAMESPACE" annotate kwatchconfig "$RELEASE" \
          "kwatch.dev/config-schema=$CATALOG_VERSION" --overwrite >/dev/null
        deployment=$(deployment_name || true)
        if [ -n "$deployment" ]; then
          if ! restart_kwatch; then
            ui_error "❌ Configuration failed validation; the previous configuration can be restored."
            restore_backup_after_failure \
              "The workload did not become ready after this configuration change." || true
            die "configuration update failed"
          fi
        else
          ui_info "ℹ️ Configuration saved; no kwatch Deployment is currently running."
          ui_info "🛠️ Run the manager again to install or repair the workload."
        fi
        ui_success "✅ Updated $path."
        break
      fi
      i=$((i + 1))
    done
  done
}

configure_alert_flow() {
  local backup deployment had_backup=false rc
  require_provider_catalog
  confirm_change \
    "🔌 The manager will prepare notification provider settings." \
    "It may create the configuration resource and save a backup; no provider values are saved unless you confirm this operation." || {
    ui_info "↩️ Provider editing cancelled; no changes were made."
    return 0
  }
  adopt_existing_config_secret
  ensure_crd
  preflight_config_resource
  ensure_config_resource
  migrate_legacy_telemetry ||
    die "could not preserve the existing telemetry setting"
  preflight_alert_access
  backup=$(mktemp)
  trap 'if [ -n "${backup:-}" ]; then rm -f "$backup"; fi' RETURN
  if kubectl -n "$NAMESPACE" get secret "$CONFIG_SECRET_NAME" \
    -o yaml >"$backup" 2>/dev/null; then
    had_backup=true
  fi
  if write_config_secret; then
    :
  else
    rc=$?
    if [ "$rc" -eq 2 ]; then
      ui_info "↩️ Provider configuration cancelled; no changes were saved."
      return 0
    fi
    die "could not save the notification configuration"
  fi
  deployment=$(deployment_name)
  if [ -n "$deployment" ] && ! restart_kwatch; then
    if [ "$had_backup" = true ]; then
      ui_warn "⚠️ Notification rollout failed; the previous configuration can be restored."
      if confirm_repair \
        "restore the previous notification configuration" \
        "The saved Secret will be applied and kwatch will be restarted."; then
        kubectl apply -f "$backup" >/dev/null 2>&1 || true
        restart_kwatch || true
      else
        ui_warn "⚠️ Notification restore skipped; the current Secret was left in place."
      fi
    else
      ui_warn \
        "⚠️ No previous Secret existed; the new configuration was preserved" \
        "so it can be corrected without re-entering every value."
    fi
    die "could not restart kwatch after changing notification providers"
  fi
  ui_success "✅ Notification providers updated."
}

configure_after_install() {
  local choice
  choice=$(ask_yes_no \
    "🛠️ Configure additional kwatch settings now? This includes all catalog settings" \
    "y")
  [ "$choice" = true ] || return 0
  configure_flow
}

ensure_runtime_config_secret() {
  local encoded tmp
  adopt_existing_config_secret
  encoded=$(secret_data_base64 "$CONFIG_SECRET_NAME" config.yaml)
  if [ -n "$encoded" ]; then
    tmp=$(mktemp)
    if decode_base64_file "$encoded" "$tmp" && [ -s "$tmp" ]; then
      rm -f "$tmp"
      return 0
    fi
    rm -f "$tmp"
    die "existing configuration Secret contains invalid config.yaml data"
  fi
  ui_warn "⚠️ This installation does not yet have a Secret-backed configuration."
  confirm_action \
    "Create it now and migrate any legacy provider configuration" "y" ||
    die "upgrade cancelled before changing the workload"
  write_config_secret
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
  ui_warn "⚠️ A previous kwatch operation stopped during: $phase"
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
  check_access get serviceaccounts namespace
  check_access get configmaps namespace
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
    check_access create serviceaccounts namespace
    check_access patch serviceaccounts namespace
    check_access create configmaps namespace
    check_access patch configmaps namespace
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
      check_access create deployments namespace
      check_access create secrets namespace
      check_access create configmaps namespace
      check_access create roles namespace
      check_access patch roles namespace
      check_access create rolebindings namespace
      check_access patch rolebindings namespace
      check_access create serviceaccounts namespace
      check_access patch serviceaccounts namespace
      check_access create clusterroles
      check_access patch clusterroles
      check_access create clusterrolebindings
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

release_catalog_available() {
  local version="$1" file
  for file in config-catalog.tsv feature-catalog.tsv provider-catalog.tsv; do
    curl -fsSL --location --retry 2 --retry-delay 1 --connect-timeout 8 \
      -o /dev/null "$BASE_URL/$version/deploy/$file" 2>/dev/null || return 1
  done
}

select_release_version() {
  local stable preview choice
  stable=$(latest_version) || return 1
  preview=$(latest_release_candidate || true)
  if [ -z "$preview" ]; then
    printf '%s' "$stable"
    return 0
  fi
  if ! release_catalog_available "$stable" &&
    release_catalog_available "$preview"; then
    ui_warn \
      "⚠️ Stable $stable has no release catalogs; catalog-ready RC $preview is available."
    confirm_action \
      "Use release candidate $preview for this operation" "n" || return 1
    printf '%s' "$preview"
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

installed_version() {
  local image tag deployment
  image=$(kubectl -n "$NAMESPACE" get deployment \
    -l "app.kubernetes.io/instance=$RELEASE,app.kubernetes.io/managed-by=kwatch.sh" \
    -o "jsonpath={.items[0].spec.template.spec.containers[?(@.name==\"$RELEASE\")].image}" \
    2>/dev/null || true)
  if [ -z "$image" ]; then
    image=$(kubectl -n "$NAMESPACE" get deployment \
      -l 'app=kwatch,app.kubernetes.io/managed-by=kwatch.sh' \
      -o "jsonpath={.items[0].spec.template.spec.containers[?(@.name==\"$RELEASE\")].image}" \
      2>/dev/null || true)
  fi
  if [ -z "$image" ]; then
    # Pre-catalog releases did not carry the manager labels. Reuse the same
    # app-labelled compatibility lookup used for upgrades and cleanup.
    deployment=$(deployment_name || true)
    if [ -n "$deployment" ]; then
      image=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
        -o "jsonpath={.spec.template.spec.containers[?(@.name==\"$RELEASE\")].image}" \
        2>/dev/null || true)
    fi
  fi
  image="${image%%@*}"
  tag="${image##*:}"
  valid_release_version "$tag" && printf '%s' "$tag"
}

version_is_legacy() {
  local version="$1" major
  major="${version#v}"
  major="${major%%.*}"
  [ "$major" = 0 ]
}

deployment_is_running() {
  local deployment="$1" available
  available=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.status.availableReplicas}' 2>/dev/null || true)
  [[ "$available" =~ ^[1-9][0-9]*$ ]]
}

assess_installation() {
  INSTALL_STATE=absent
  INSTALL_DEPLOYMENT=""
  INSTALL_VERSION=""
  INSTALL_REASON=""
  INSTALL_DEPLOYMENT=$(deployment_name || true)
  if [ -z "$INSTALL_DEPLOYMENT" ]; then
    INSTALL_REASON="no kwatch Deployment was found"
    return 0
  fi

  INSTALL_VERSION=$(installed_version || true)
  if [ -z "$INSTALL_VERSION" ]; then
    INSTALL_STATE=broken
    INSTALL_REASON="the Deployment image version could not be determined"
    return 0
  fi
  if ! deployment_is_running "$INSTALL_DEPLOYMENT"; then
    INSTALL_STATE=broken
    INSTALL_REASON="the Deployment has no available replicas"
    return 0
  fi
  if version_is_legacy "$INSTALL_VERSION"; then
    INSTALL_STATE=legacy
  else
    INSTALL_STATE=supported
  fi
}

stale_resources_present() {
  kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" \
    >/dev/null 2>&1 && return 0
  kubectl -n "$NAMESPACE" get secret "$CONFIG_SECRET_NAME" \
    >/dev/null 2>&1 && return 0
  kubectl -n "$NAMESPACE" get configmap "$RELEASE" \
    >/dev/null 2>&1
}

confirm_config_secret_replacement() {
  local owner
  if ! kubectl -n "$NAMESPACE" get secret "$CONFIG_SECRET_NAME" \
    >/dev/null 2>&1; then
    return 0
  fi
  owner=$(kubectl -n "$NAMESPACE" get secret "$CONFIG_SECRET_NAME" \
    -o 'jsonpath={.metadata.labels.app\.kubernetes\.io/managed-by}' \
    2>/dev/null || true)
  [ "$owner" = kwatch.sh ] && return 0
  ui_warn "⚠️ An unowned Secret named '$CONFIG_SECRET_NAME' already exists."
  confirm_action \
    "Replace this Secret with the new kwatch configuration" "n" ||
    die "installation cancelled; the existing Secret was preserved"
}

maybe_load_catalog() {
  local version="${1:-}"
  CATALOG=()
  FEATURE_CATALOG=()
  PROVIDER_CATALOG=()
  CATALOG_SOURCE="unavailable"
  FEATURE_CATALOG_SOURCE="unavailable"
  PROVIDER_CATALOG_SOURCE="unavailable"
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
  if load_catalog_bundle "$version" false; then
    return 0
  fi
  ui_error "❌ No usable catalogs were found for $version."
  return 1
}

select_modern_release_version() {
  local version
  while true; do
    version=$(select_release_version) || return 1
    if version_is_legacy "$version"; then
      ui_warn "⚠️ $version is older than v1.0.0; choose a modern release."
      continue
    fi
    printf '%s' "$version"
    return 0
  done
}

compare_release_versions() {
  local left="${1#v}" right="${2#v}"
  local left_base right_base left_rc right_rc
  local left_major left_minor left_patch right_major right_minor right_patch
  local pair left_part right_part
  left_base="${left%%-rc.*}"
  right_base="${right%%-rc.*}"
  IFS=. read -r left_major left_minor left_patch <<<"$left_base"
  IFS=. read -r right_major right_minor right_patch <<<"$right_base"
  for pair in \
    "$left_major:$right_major" "$left_minor:$right_minor" \
    "$left_patch:$right_patch"; do
    left_part="${pair%%:*}"
    right_part="${pair#*:}"
    if [ "$left_part" -gt "$right_part" ]; then
      printf '1'
      return 0
    fi
    if [ "$left_part" -lt "$right_part" ]; then
      printf '%s' '-1'
      return 0
    fi
  done
  if [[ "$left" == *-rc.* ]] && [[ "$right" != *-rc.* ]]; then
    printf '%s' '-1'
    return 0
  fi
  if [[ "$left" != *-rc.* ]] && [[ "$right" == *-rc.* ]]; then
    printf '1'
    return 0
  fi
  if [[ "$left" == *-rc.* ]]; then
    left_rc="${left#*-rc.}"
    right_rc="${right#*-rc.}"
  else
    left_rc=0
    right_rc=0
  fi
  if [ "$left_rc" -gt "$right_rc" ]; then
    printf '1'
  elif [ "$left_rc" -lt "$right_rc" ]; then
    printf '%s' '-1'
  else
    printf '0'
  fi
}

select_upgrade_version() {
  local current="$1" target comparison
  while true; do
    target=$(select_modern_release_version) || return 1
    comparison=$(compare_release_versions "$target" "$current")
    if [ "$comparison" = 1 ]; then
      printf '%s' "$target"
      return 0
    fi
    ui_warn "⚠️ Choose a release newer than the installed version $current."
  done
}

load_catalog_bundle() {
  local version="$1" report="${2:-true}" ok=true
  if load_catalog_for_version "$version"; then
    ui_success "📚 Configuration catalog: $CATALOG_SOURCE ($version)"
  else
    [ "$report" = true ] &&
      ui_error "❌ Configuration catalog unavailable for $version."
    ok=false
  fi
  if load_feature_catalog_for_version "$version"; then
    ui_success "🧩 Feature catalog: $FEATURE_CATALOG_SOURCE ($version)"
  else
    [ "$report" = true ] &&
      ui_error "❌ Feature catalog unavailable for $version."
    ok=false
  fi
  if load_provider_catalog_for_version "$version"; then
    ui_success "🔌 Provider catalog: $PROVIDER_CATALOG_SOURCE ($version)"
  else
    [ "$report" = true ] &&
      ui_error "❌ Provider catalog unavailable for $version."
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
  ui_heading "🧩 kwatch capabilities"
  local entry id lifecycle description dependencies line
  for entry in "${FEATURE_CATALOG[@]}"; do
    IFS='|' read -r id lifecycle description dependencies <<<"$entry"
    if [ -n "$dependencies" ]; then
      printf -v line '%-42s %-7s %s (needs: %s)' \
        "$id" "$lifecycle" "$description" "$dependencies"
    else
      printf -v line '%-42s %-7s %s' "$id" "$lifecycle" "$description"
    fi
    ui_detail "$line"
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
      check_access delete "$kind" namespace
      kubectl -n "$NAMESPACE" delete "$kind" "$name" \
        --ignore-not-found >/dev/null
    else
      check_access delete "$kind"
      kubectl delete "$kind" "$name" --ignore-not-found >/dev/null
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

remove_legacy_install() {
  local secret_name="${CONFIG_SECRET_NAME:-${RELEASE}-config}"
  local secret_owner
  ui_info "🧹 Uninstalling the legacy kwatch installation."
  remove_namespaced_workload
  check_access delete configmaps namespace
  kubectl -n "$NAMESPACE" delete configmap "$RELEASE" \
    --ignore-not-found >/dev/null
  kubectl -n "$NAMESPACE" delete configmap "$STATE_CONFIGMAP_NAME" \
    --ignore-not-found >/dev/null
  if kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" \
    >/dev/null 2>&1; then
    check_access delete kwatchconfigs namespace
    kubectl -n "$NAMESPACE" delete kwatchconfig "$RELEASE" \
      --ignore-not-found >/dev/null
  fi
  if kubectl -n "$NAMESPACE" get secret "$secret_name" \
    >/dev/null 2>&1; then
    secret_owner=$(kubectl -n "$NAMESPACE" get secret "$secret_name" \
      -o 'jsonpath={.metadata.labels.app\.kubernetes\.io/managed-by}' \
      2>/dev/null || true)
    if [ "$secret_owner" = kwatch.sh ]; then
      check_access delete secrets namespace
      kubectl -n "$NAMESPACE" delete secret "$secret_name" \
        --ignore-not-found >/dev/null
    else
      ui_info "🔐 Preserving unowned Secret '$secret_name'."
    fi
  fi
  ui_success \
    "✅ Legacy kwatch workload and configuration removed; the backup was preserved."
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
    ui_heading "📣 Where should kwatch send alerts?"
    query=$(ask \
      "🔎 Provider name, number, or search (Enter to browse) $(back_hint)" \
      "")
    is_back_choice "$query" && return 2
    if [ -z "$query" ]; then
      for i in "${!providers[@]}"; do
        ui_menu "  $((i + 1))) 🔌 ${displays[$i]}"
      done
      query=$(ask "🎯 Choose provider number or name $(back_hint)" "")
      is_back_choice "$query" && return 2
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
      ui_info "🔎 Matching providers for '$query':"
      local match_number=1
      for i in "${matches[@]}"; do
        ui_menu "  $match_number) 🔌 ${displays[$i]} (${providers[$i]})"
        match_number=$((match_number + 1))
      done
      choice=$(ask "🎯 Choose a matching provider number $(back_hint)" "")
      is_back_choice "$choice" && return 2
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
    ui_heading "🔐 Choose $group"
    i=1
    for value in "${values[@]}"; do
      IFS='|' read -r selected field description <<<"$value"
      ui_menu "  $i) 🔑 $selected ($field)"
      i=$((i + 1))
    done
    while true; do
      choice=$(ask "🎯 $group option $(back_hint)" "1")
      is_back_choice "$choice" && return 2
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
  local default="$5" description="$6" value allowed
  case "$validation" in
    one-of:*)
      allowed="${validation#one-of:}"
      ui_info "🎯 Allowed values for $field: ${allowed//,/ · }"
      ;;
  esac
  while true; do
    if [ "$secret" = true ]; then
      value=$(ask_secret "$description $(back_hint)")
    else
      value=$(ask "$description $(back_hint)" "$default")
    fi
    is_back_choice "$value" && return 2
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
      signed-integer)
        [[ "$value" =~ ^-?[0-9]+$ ]] || {
          ui_warn "⚠️ $field must be a signed integer."; continue;
        }
        ;;
      port)
        [[ "$value" =~ ^[0-9]+$ ]] &&
          [ "$value" -ge 1 ] && [ "$value" -le 65535 ] || {
          ui_warn "⚠️ $field must be a port from 1 to 65535."; continue;
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
      one-of:*)
        allowed="${validation#one-of:}"
        case ",$allowed," in
          *",$value,"*) ;;
          *)
            ui_warn "⚠️ $field must be one of: ${allowed//,/, }."
            continue
            ;;
        esac
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
  local secret_name="$1" config_tmp="$2"
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
  local group condition field_description value field_required field_priority rc
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
    if value=$(prompt_provider_value "$field" "$type" "$secret" \
      "$validation" "$default" "$field_description"); then
      :
    else
      rc=$?
      return "$rc"
    fi
    if [ -z "$value" ]; then
      if [ "$secret" = true ] &&
        preserve_provider_secret "$config_tmp" "$provider" "$field" "$tmp_dir"; then
        mark_provider_group_present "$group"
        break
      fi
      if [ "$secret" = true ]; then
        value=$(old_provider_plain_value "$provider" "$field" || true)
        if [ -n "$value" ]; then
          write_provider_secret "$config_tmp" "$field" "$value" "$tmp_dir"
          mark_provider_group_present "$group"
          break
        fi
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
  local entry mode configure_optional priority rc
  WRITTEN_PROVIDER_SECTIONS="|"
  PROVIDER_GROUP_PRESENCE="|"
  printf '  %s:\n' "$PROVIDER" >>"$config_tmp"
  # Authentication and other required fields are collected before optional
  # presentation settings, regardless of catalog row order.
  ui_info "🔐 Required settings for $PROVIDER"
  configure_optional=true
  for priority in 1 2 3; do
    for entry in "${PROVIDER_CATALOG[@]}"; do
      write_provider_field "$entry" required "$configure_optional" \
        "$priority" || { rc=$?; return "$rc"; }
    done
  done
  # Keep at-least-one destination groups in catalog order. This lets the user
  # choose the first destination without being forced into the last row.
  for entry in "${PROVIDER_CATALOG[@]}"; do
    write_provider_field "$entry" group true 3 || { rc=$?; return "$rc"; }
  done
  ui_info "⚙️ Optional settings for $PROVIDER"
  if configure_optional=$(ask_yes_no_or_back \
    "Configure optional settings for $PROVIDER too?" "n"); then
    :
  else
    rc=$?
    return "$rc"
  fi
  for priority in 1 2 3; do
    for entry in "${PROVIDER_CATALOG[@]}"; do
      write_provider_field "$entry" optional "$configure_optional" \
        "$priority" || { rc=$?; return "$rc"; }
    done
  done
}

choose_provider_config_action() {
  local choice provider display result rc
  local -a existing=()
  while IFS='|' read -r provider display; do
    [ -n "$provider" ] && existing+=("$display")
  done < <(existing_provider_names)
  if [ "${#existing[@]}" -eq 0 ]; then
    if result=$(ask_yes_no_or_back \
      "📣 Configure notification providers now?" "y"); then
      :
    else
      rc=$?
      return "$rc"
    fi
    if [ "$result" = true ]; then
      printf 'edit'
    else
      printf 'empty'
    fi
    return
  fi
  ui_info "📣 Existing providers: ${existing[*]}"
  ui_menu \
    "  1) Edit or add providers" \
    "  2) Keep providers unchanged" \
    "  3) Remove all providers" \
    "  4) $(back_label)"
  while true; do
    choice=$(ask "Provider configuration action" "1")
    case "$choice" in
      1) printf 'edit'; return ;;
      2) printf 'keep'; return ;;
      3)
        confirm_action "Remove all configured notification providers" "n" ||
          continue
        printf 'empty'
        return
        ;;
      4) printf 'back'; return ;;
      *) ui_warn "⚠️ Choose a number from 1 to 4." ;;
    esac
  done
}

write_config_secret() {
  local secret_name="${CONFIG_SECRET_NAME:-${RELEASE}-config}"
  local tmp_dir config_tmp provider_action provider_snapshot rc
  local add_provider keep_existing
  local entry path type default category description status replacement value
  local old_value
  local encoded legacy_config
  local -a secret_args_before=()
  SECRET_ARGS=()
  WRITTEN_CONFIG_SECTIONS="|"
  CONFIGURED_PROVIDERS="|"
  tmp_dir=$(mktemp -d)
  config_tmp="$tmp_dir/config.yaml"
  trap 'if [ -n "${tmp_dir:-}" ]; then rm -rf "$tmp_dir"; fi' RETURN
  OLD_CONFIG_PATH="$tmp_dir/old-config.yaml"
  if [ "$FRESH_INSTALL" != true ]; then
    encoded=$(secret_data_base64 "$CONFIG_SECRET_NAME" config.yaml)
    if [ -n "$encoded" ]; then
      if ! decode_base64_file "$encoded" "$OLD_CONFIG_PATH"; then
        die "existing configuration Secret contains invalid config.yaml data"
      fi
    else
      legacy_config=$(kubectl -n "$NAMESPACE" get configmap "$RELEASE" \
        -o 'go-template={{index .data "config.yaml"}}' 2>/dev/null || true)
      if [ -n "$legacy_config" ] && [ "$legacy_config" != '<no value>' ]; then
        printf '%s\n' "$legacy_config" >"$OLD_CONFIG_PATH"
        ui_info \
          "🔐 Migrating the legacy ConfigMap configuration into a Secret."
      fi
    fi
  fi
  if provider_action=$(choose_provider_config_action); then
    :
  else
    rc=$?
    return "$rc"
  fi
  case "$provider_action" in
  edit)
    printf 'crd:\n  enabled: true\nalert:\n' >"$config_tmp"
    while true; do
      if choose_provider; then
        :
      else
        rc=$?
        return "$rc"
      fi
      provider_snapshot="$tmp_dir/provider-before.yaml"
      cp "$config_tmp" "$provider_snapshot"
      secret_args_before=()
      if [ "${#SECRET_ARGS[@]}" -gt 0 ]; then
        secret_args_before=("${SECRET_ARGS[@]}")
      fi
      if select_provider_groups; then
        :
      else
        rc=$?
        if [ "$rc" -eq 2 ]; then
          cp "$provider_snapshot" "$config_tmp"
          SECRET_ARGS=()
          if [ "${#secret_args_before[@]}" -gt 0 ]; then
            SECRET_ARGS=("${secret_args_before[@]}")
          fi
          ui_info "↩️ Returning to provider selection."
          continue
        fi
        return "$rc"
      fi
      if write_provider_block; then
        :
      else
        rc=$?
        if [ "$rc" -eq 2 ]; then
          cp "$provider_snapshot" "$config_tmp"
          SECRET_ARGS=()
          if [ "${#secret_args_before[@]}" -gt 0 ]; then
            SECRET_ARGS=("${secret_args_before[@]}")
          fi
          ui_info "↩️ Returning to provider selection."
          continue
        fi
        return "$rc"
      fi
      CONFIGURED_PROVIDERS="${CONFIGURED_PROVIDERS}${PROVIDER}|"
      provider_available || break
      if add_provider=$(ask_yes_no_or_back \
        "➕ Add another notification provider?" "n"); then
        :
      else
        rc=$?
        if [ "$rc" -eq 2 ]; then
          ui_info "↩️ Provider configuration cancelled."
        fi
        return "$rc"
      fi
      if [ "$add_provider" != true ]; then
        break
      fi
    done
    if has_unselected_existing_provider; then
      if keep_existing=$(ask_yes_no_or_back \
        "Keep existing providers you did not edit unchanged?" "y"); then
        :
      else
        rc=$?
        return "$rc"
      fi
      if [ "$keep_existing" = true ]; then
        preserve_existing_providers "$config_tmp" "$tmp_dir" true || true
      else
        ui_warn "⚠️ Existing providers not selected above will be removed."
        confirm_action "Continue and remove the unselected providers" "n" ||
          die "provider configuration cancelled; no changes were saved"
      fi
    fi
    ;;
  back)
    ui_info "↩️ Provider configuration cancelled."
    return 2
    ;;
  keep)
    printf 'crd:\n  enabled: true\nalert:\n' >"$config_tmp"
    preserve_existing_providers "$config_tmp" "$tmp_dir" ||
      die "could not preserve the existing notification providers"
    ;;
  empty)
    printf 'crd:\n  enabled: true\nalert: {}\n' >"$config_tmp"
    ;;
  esac
  for entry in "${CATALOG[@]}"; do
    IFS='|' read -r path type default category description status replacement <<<"$entry"
    [ "$status" = secret ] || continue
    while true; do
      value=$(ask_secret \
        "$description (leave empty to skip) $(back_hint)")
      is_back_choice "$value" && return 2
      if [ -z "$value" ]; then
        if preserve_config_secret "$config_tmp" "$path" "$tmp_dir"; then
          break
        fi
        old_value=$(old_config_value "$path" || true)
        case "$old_value" in
          ""|\$\{file:*) ;;
          *)
            if write_config_secret_value "$config_tmp" "$path" \
              "$old_value" "$tmp_dir"; then
              ui_success "🔐 Migrated $path into the configuration Secret."
            fi
            ;;
        esac
        break
      fi
      if write_config_secret_value "$config_tmp" "$path" "$value" "$tmp_dir"; then
        break
      fi
      ui_warn "⚠️ $path must be a valid single-line secret value. Try again."
    done
  done
  with_loading "Saving notification configuration" apply_config_secret \
    "$secret_name" "$config_tmp" ||
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
  if ! grep -q '^kind: Deployment$' "$tmp"; then
    LAST_COMMAND_ERROR="Downloaded deployment manifest for $version does not contain a Deployment."
    return 1
  fi
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
    if [ -n "$existing_deployment" ] && confirm_action \
      "The Deployment update failed. Recreate it while preserving config and Secrets" \
      "n" && recreate_deployment "$existing_deployment" "$tmp"; then
      ui_success \
        "🛠️ Recreated the kwatch Deployment" \
        "while preserving configuration."
    else
      [ -n "$LAST_COMMAND_ERROR" ] ||
        LAST_COMMAND_ERROR="Kubernetes rejected the kwatch Deployment manifest."
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
  check_access delete deployments namespace
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
    -o "jsonpath={.spec.template.spec.containers[?(@.name==\"$RELEASE\")].securityContext.runAsNonRoot}")
  read_only=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o "jsonpath={.spec.template.spec.containers[?(@.name==\"$RELEASE\")].securityContext.readOnlyRootFilesystem}")
  no_escalation=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o "jsonpath={.spec.template.spec.containers[?(@.name==\"$RELEASE\")].securityContext.allowPrivilegeEscalation}")
  seccomp=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o "jsonpath={.spec.template.spec.containers[?(@.name==\"$RELEASE\")].securityContext.seccompProfile.type}")
  dropped=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o "jsonpath={.spec.template.spec.containers[?(@.name==\"$RELEASE\")].securityContext.capabilities.drop[0]}")
  secret_mode=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.volumes[?(@.name=="config-volume")].secret.defaultMode}')
  [ "$enforce" = restricted ] || {
    ui_error "❌ Namespace Pod Security enforcement is not restricted."
    return 1
  }
  [ "$non_root" = true ] || {
    ui_error "❌ kwatch deployment is not configured as non-root."
    return 1
  }
  [ "$read_only" = true ] || {
    ui_error "❌ kwatch deployment root filesystem is writable."
    return 1
  }
  [ "$no_escalation" = false ] || {
    ui_error "❌ kwatch deployment allows privilege escalation."
    return 1
  }
  [ "$seccomp" = RuntimeDefault ] || {
    ui_error "❌ kwatch deployment lacks RuntimeDefault seccomp."
    return 1
  }
  [ "$dropped" = ALL ] || {
    ui_error "❌ kwatch deployment does not drop all capabilities."
    return 1
  }
  [ "$secret_mode" = 256 ] || {
    ui_error "❌ kwatch Secret volume is not mode 0400."
    return 1
  }
  ui_success "🛡️ Kubernetes operational protection verified."
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
    confirm_action \
      "Apply restricted Pod Security labels to namespace $NAMESPACE" "n" ||
      die "namespace security labels were not approved"
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

retry_install_apply() {
  local version="$1" failure=""
  confirm_repair \
    "retry applying kwatch $version" \
    "This repeats the failed Kubernetes apply and rollout checks; no additional configuration is requested." ||
    return 1
  record_state apply "$version" "retrying failed installation"
  if apply_manifests "$version"; then
    if verify_operational_security; then
      record_state complete "$version" "installation verified after retry"
      FRESH_INSTALL=false
      ui_success "✅ kwatch is ready after the retry."
      configure_after_install
      return 0
    fi
    failure="operational security verification failed"
  else
    failure="${LAST_COMMAND_ERROR:-kwatch resources could not be applied}"
  fi
  LAST_COMMAND_ERROR="$failure"
  ui_error "❌ Retry failed."
  ui_error "Reason: $failure"
  show_failure_diagnostics "Installation retry" "$failure"
  return 1
}

retry_upgrade_apply() {
  local version="$1" failure=""
  confirm_repair \
    "retry upgrading kwatch to $version" \
    "This repeats the failed Kubernetes apply and rollout checks using the existing backup." ||
    return 1
  record_state apply "$version" "retrying failed upgrade"
  if apply_manifests "$version"; then
    if verify_operational_security; then
      record_state complete "$version" "upgrade verified after retry"
      ui_success "✅ kwatch upgraded successfully after the retry."
      return 0
    fi
    failure="operational security verification failed"
  else
    failure="${LAST_COMMAND_ERROR:-kwatch resources could not be applied}"
  fi
  LAST_COMMAND_ERROR="$failure"
  ui_error "❌ Upgrade retry failed."
  ui_error "Reason: $failure"
  show_failure_diagnostics "Upgrade retry" "$failure"
  return 1
}

install_flow() {
  with_loading "Checking Kubernetes cluster" kubectl cluster-info >/dev/null ||
    die "cannot reach the Kubernetes cluster"
  local version="${1:-}" skip_resume="${2:-false}"
  local catalogs_ready="${3:-false}"
  local change_confirmed="${4:-false}"
  local write_rc install_failure=""
  [ "$skip_resume" = true ] || confirm_resume
  if [ -z "$version" ]; then
    version=$(select_modern_release_version) ||
      die "could not determine a modern kwatch release from GitHub"
  fi
  version_is_legacy "$version" &&
    die "a fresh installation requires a kwatch release >= v1.0.0"
  if [ "$catalogs_ready" != true ]; then
    maybe_load_catalog "$version" ||
      die "release catalogs are unavailable; installation cannot continue"
  fi
  require_config_catalog
  require_provider_catalog
  if [ "$change_confirmed" != true ]; then
    confirm_change \
      "🚀 The manager will install kwatch $version on '$SELECTED_CONTEXT'." \
      "It will create or update resources in namespace '$NAMESPACE' and may create a configuration Secret." || {
      ui_info "↩️ Installation cancelled; no changes were made."
      return 0
    }
  fi
  confirm_config_secret_replacement
  if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    NAMESPACE_CREATED=false
  else
    with_loading "Creating namespace $NAMESPACE" kubectl create namespace \
      "$NAMESPACE" >/dev/null || die "could not create namespace $NAMESPACE"
    NAMESPACE_CREATED=true
  fi
  apply_operational_namespace_labels
  preflight_access install
  # Reuse the mounted Secret name when applying an existing workload.
  adopt_existing_config_secret
  FRESH_INSTALL=true
  record_state preflight "$version" "cluster selected and reachable"
  ui_info "🚀 Installing kwatch $version..."
  record_state backup "$version" "creating notification Secret"
  if write_config_secret; then
    :
  else
    write_rc=$?
    if [ "$write_rc" -eq 2 ]; then
      FRESH_INSTALL=false
      ui_info \
        "↩️ Installation cancelled before notification configuration was saved."
      return 0
    fi
    die "could not save the notification configuration"
  fi
  choose_tls_monitor
  record_state apply "$version" "applying CRD and Deployment"
  if apply_manifests "$version"; then
    if ! verify_operational_security; then
      install_failure="operational security verification failed"
    fi
  else
    install_failure="${LAST_COMMAND_ERROR:-kwatch resources could not be applied}"
  fi
  if [ -n "$install_failure" ]; then
    record_state failed "$version" "installation failed; cleanup requires confirmation"
    ui_error "❌ Installation failed; the created workload can be cleaned up."
    ui_error "Reason: $install_failure"
    show_failure_diagnostics "Installation" "$install_failure"
    if failure_is_retryable "$install_failure"; then
      if retry_install_apply "$version"; then
        return 0
      fi
      install_failure="${LAST_COMMAND_ERROR:-$install_failure}"
    fi
    if confirm_repair \
      "remove the kwatch workload resources created by this failed install" \
      "The CRD and configuration resource will be preserved; only manager-owned workload resources will be removed."; then
      remove_namespaced_workload
      ui_info "🧹 Failed-install workload cleanup completed."
    else
      ui_warn "⚠️ Cleanup skipped; the failed workload resources were left in place."
    fi
    die "installation failed; review the reason above"
  fi
  record_state complete "$version" "installation verified"
  FRESH_INSTALL=false
  ui_success "✅ kwatch is ready."
  configure_after_install
}

upgrade_flow() {
  local version upgrade_failure="" change_confirmed="${1:-false}"
  confirm_resume
  if [ -n "$INSTALL_VERSION" ]; then
    version=$(select_upgrade_version "$INSTALL_VERSION") ||
      die "could not determine a newer kwatch release from GitHub"
  else
    version=$(select_modern_release_version) ||
      die "could not determine a modern kwatch release from GitHub"
  fi
  maybe_load_catalog "$version" ||
    die "release catalogs are unavailable; upgrade cannot continue"
  if [ "$change_confirmed" != true ]; then
    confirm_change \
      "⬆️ The manager will upgrade kwatch to $version on '$SELECTED_CONTEXT'." \
      "It will update the CRD and Deployment. A configuration backup will be created first." || {
      ui_info "↩️ Upgrade cancelled; no changes were made."
      return 0
    }
  fi
  ui_info "⬆️ Upgrading kwatch to $version..."
  apply_operational_namespace_labels
  record_state preflight "$version" "upgrade started"
  ensure_crd "$version"
  preflight_access upgrade
  preflight_config_resource
  ensure_config_resource
  ensure_runtime_config_secret
  migrate_legacy_telemetry ||
    die "could not preserve the existing telemetry setting"
  backup_config
  record_state backup "$version" "configuration backup created"
  if ! migrate_legacy_silences; then
    ui_error "❌ Legacy configuration migration failed; the previous configuration can be restored."
    restore_backup_after_failure \
      "This reverses the legacy settings migration that just failed." || true
    record_state failed "$version" "legacy configuration migration failed"
    die "upgrade migration failed"
  fi
  record_state apply "$version" "applying upgraded Deployment"
  if apply_manifests "$version"; then
    if ! verify_operational_security; then
      upgrade_failure="operational security verification failed"
    fi
  else
    upgrade_failure="${LAST_COMMAND_ERROR:-kwatch resources could not be applied}"
  fi
  if [ -n "$upgrade_failure" ]; then
    ui_error "❌ Upgrade failed; the previous configuration can be restored."
    ui_error "Reason: $upgrade_failure"
    show_failure_diagnostics "Upgrade" "$upgrade_failure"
    if failure_is_retryable "$upgrade_failure"; then
      if retry_upgrade_apply "$version"; then
        return 0
      fi
      upgrade_failure="${LAST_COMMAND_ERROR:-$upgrade_failure}"
    fi
    if confirm_repair \
      "restore the previous configuration and roll back the Deployment" \
      "The backup created before this upgrade will be applied, then Kubernetes will roll back the Deployment."; then
      restore_backup
      rollback_deployment
      record_state failed "$version" "deployment rollout failed; rollback completed"
    else
      ui_warn "⚠️ Rollback skipped; the failed upgrade state was left in place."
      record_state failed "$version" "deployment rollout failed; rollback skipped"
    fi
    die "upgrade failed"
  fi
  record_state complete "$version" "upgrade verified"
  ui_success "✅ kwatch upgraded successfully."
}

legacy_reinstall_flow() {
  local target confirmation
  target=$(select_modern_release_version) ||
    die "could not determine a modern kwatch release from GitHub"
  MIGRATION_TARGET_VERSION="$target"
  maybe_load_catalog "$target" ||
    die "release catalogs are unavailable; legacy replacement cannot continue"
  require_config_catalog
  require_provider_catalog
  adopt_existing_config_secret
  ui_heading "🔁 Replace legacy kwatch"
  ui_warn "⚠️ This is a legacy kwatch replacement, not an in-place upgrade."
  ui_detail "Installed version: ${INSTALL_VERSION:-unknown}"
  ui_detail "Target version:    $target"
  ui_detail "The old configuration will be backed up before uninstalling."
  ui_detail "A fresh installation will configure providers again."
  ui_detail "No legacy settings migration will be attempted."
  confirm_change \
    "🔁 The manager will uninstall the legacy workload and install kwatch $target." \
    "The old configuration will be backed up first; the legacy workload will then be removed." || {
    ui_info "↩️ Legacy replacement cancelled; no changes were made."
    return 0
  }
  confirmation=$(ask "Type uninstall to continue" "")
  [ "$confirmation" = uninstall ] || {
    ui_warn "↩️ Cancelled. The legacy installation was not changed."
    return 0
  }
  backup_legacy_install
  record_state backup "$target" "legacy installation backup created"
  remove_legacy_install
  CONFIG_SECRET_NAME="${RELEASE}-config"
  ui_info "🚀 Starting a fresh kwatch installation."
  install_flow "$target" true true true
  MIGRATION_TARGET_VERSION=""
}

show_absent_menu() {
  ui_heading "🚀 Install kwatch"
  ui_info "No running kwatch installation was found on '$SELECTED_CONTEXT'."
  if stale_resources_present; then
    ui_info "Existing kwatch configuration resources were found, but no" \
      "kwatch workload is running; they are not treated as an installation."
    ui_info \
      "Settings are preserved where possible; provider setup starts fresh."
  fi
  ui_menu "  1) 🚀 Install kwatch" "  2) $(exit_label)"
  while true; do
    case "$(ask "Choice" "1")" in
      1) install_flow; return ;;
      2) return ;;
      *) ui_warn "⚠️ Choose 1 to install or 2 to exit." ;;
    esac
  done
}

show_legacy_menu() {
  ui_heading "⚠️ Legacy kwatch detected"
  ui_warn "kwatch $INSTALL_VERSION is running on '$SELECTED_CONTEXT'."
  ui_detail "This release predates the guided configuration catalogs."
  ui_detail "Configuration editing is unavailable until it is replaced."
  ui_menu \
    "  1) 🔁 Uninstall legacy kwatch and fresh-install" \
    "  2) $(exit_label)"
  while true; do
    case "$(ask "Choice" "1")" in
      1) legacy_reinstall_flow; return ;;
      2) return ;;
      *) ui_warn "⚠️ Choose 1 or 2." ;;
    esac
  done
}

show_supported_menu() {
  ui_heading "✅ kwatch is ready"
  ui_success "✅ kwatch $INSTALL_VERSION is running on '$SELECTED_CONTEXT'."
  ui_menu \
    "  1) ⬆️ Upgrade kwatch" \
    "  2) 🔌 Edit notification providers" \
    "  3) ⚙️ Edit settings" \
    "  4) 📊 View status" \
    "  5) 🧩 View capabilities" \
    "  6) 🧹 Uninstall kwatch" \
    "  7) $(exit_label)"
  while true; do
    case "$(ask "Choice" "4")" in
      1) upgrade_flow; return ;;
      2)
        maybe_load_catalog "$INSTALL_VERSION" ||
          die \
            "release catalogs are unavailable; provider editing cannot continue"
        migration_notice
        configure_alert_flow
        return
        ;;
      3)
        maybe_load_catalog "$INSTALL_VERSION" ||
          die \
            "release catalogs are unavailable; settings editing cannot continue"
        migration_notice
        configure_flow
        return
        ;;
      4) status_flow; return ;;
      5)
        maybe_load_catalog "$INSTALL_VERSION" ||
          die \
            "release catalogs are unavailable; capabilities cannot be displayed"
        features_flow
        return
        ;;
      6) uninstall_flow; return ;;
      7) return ;;
      *) ui_warn "⚠️ Choose a number from 1 to 7." ;;
    esac
  done
}

show_broken_menu() {
  ui_heading "🩺 kwatch needs attention"
  ui_warn "⚠️ A kwatch Deployment was found, but it is not healthy."
  ui_detail "Deployment: ${INSTALL_DEPLOYMENT:-unknown}"
  ui_detail "Version: ${INSTALL_VERSION:-unknown}"
  ui_detail "Reason: $INSTALL_REASON"
  ui_menu \
    "  1) 🛠️ Repair by upgrading kwatch" \
    "  2) 📊 View status" \
    "  3) 🧹 Uninstall kwatch" \
    "  4) $(exit_label)"
  while true; do
    case "$(ask "Choice" "2")" in
      1)
        if confirm_repair \
          "repair kwatch by upgrading it" \
          "This will let you choose a release, then update the Deployment and roll back if the rollout fails."; then
          upgrade_flow true
          return
        fi
        ui_info "↩️ Repair cancelled; no changes were made."
        ;;
      2) status_flow; return ;;
      3) uninstall_flow; return ;;
      4) return ;;
      *) ui_warn "⚠️ Choose a number from 1 to 4." ;;
    esac
  done
}

status_flow() {
  local deployment version pod_instance
  ui_heading "📊 kwatch status"
  ui_detail "📍 Context: $SELECTED_CONTEXT"
  ui_detail "📦 Namespace: $NAMESPACE"
  version=$(installed_version || true)
  ui_detail "🏷️ Version: ${version:-unknown}"
  if [ "$CATALOG_SOURCE" != unavailable ]; then
    ui_detail "📚 Configuration catalog: $CATALOG_SOURCE"
  fi
  deployment=$(deployment_name || true)
  if [ -n "$deployment" ]; then
    kubectl -n "$NAMESPACE" get deployment "$deployment" 2>/dev/null || true
    pod_instance=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
      -o 'jsonpath={.spec.template.metadata.labels.app\.kubernetes\.io/instance}' \
      2>/dev/null || true)
    if [ -n "$pod_instance" ]; then
      kubectl -n "$NAMESPACE" get pods \
        -l "app.kubernetes.io/instance=$pod_instance" 2>/dev/null || true
    else
      kubectl -n "$NAMESPACE" get pods -l app=kwatch 2>/dev/null || true
    fi
  else
    ui_warn "⚠️ No kwatch Deployment was found."
  fi
  kubectl -n "$NAMESPACE" get configmap "$STATE_CONFIGMAP_NAME" \
    -o 'custom-columns=PHASE:.data.phase,VERSION:.data.version,MESSAGE:.data.message' \
    --no-headers 2>/dev/null || ui_detail "🧭 Manager state: not available"
}

uninstall_flow() {
  local confirm secret_owner
  adopt_existing_config_secret
  ui_warn \
    "⚠️ This removes the kwatch workload and its manager-owned configuration Secret."
  ui_detail "KwatchConfig, backups, namespace, and CRD are preserved."
  confirm=$(ask "Type uninstall to remove kwatch" "")
  [ "$confirm" = uninstall ] || { ui_warn "↩️ Cancelled."; return; }
  ui_info \
    "🧹 Removing kwatch resources from namespace '$NAMESPACE'; other resources remain."
  remove_namespaced_workload
  secret_owner=$(kubectl -n "$NAMESPACE" get secret "$CONFIG_SECRET_NAME" \
    -o 'jsonpath={.metadata.labels.app\.kubernetes\.io/managed-by}' \
    2>/dev/null || true)
  if [ "$secret_owner" = kwatch.sh ]; then
    kubectl -n "$NAMESPACE" delete secret "$CONFIG_SECRET_NAME" \
      --ignore-not-found
  else
    ui_info "🔐 Preserving unowned Secret '$CONFIG_SECRET_NAME'."
  fi
  clear_managed_namespace_labels
  ui_success \
    "✅ kwatch workload removed. KwatchConfig, backups, namespace, and CRD remain."
}

main() {
  local action="${1:-}"
  case "$action" in
    --help|-h)
      echo "🧭 Usage: kwatch.sh"
      echo "Interactive kubectl manager with operational security checks."
      exit 0
      ;;
    --version|-v)
      echo "🏷️ kwatch manager catalog $CATALOG_VERSION"
      exit 0
      ;;
    "") ;;
    *) die "kwatch.sh is interactive; run it without an action argument" ;;
  esac
  require_tools
  ui_heading "🧭 kwatch interactive manager"
  select_context
  with_loading "Checking Kubernetes cluster" kubectl cluster-info >/dev/null ||
    die "cannot reach the Kubernetes cluster"
  assess_installation
  case "$INSTALL_STATE" in
    absent) show_absent_menu ;;
    legacy) show_legacy_menu ;;
    supported) show_supported_menu ;;
    broken) show_broken_menu ;;
    *) die "could not assess the kwatch installation" ;;
  esac
}

if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
