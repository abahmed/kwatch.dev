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
ROLLOUT_TIMEOUT="${KWATCH_ROLLOUT_TIMEOUT:-5m}"
SELECTED_CONTEXT=""
INSTALL_STATE=""
INSTALL_DEPLOYMENT=""
INSTALL_VERSION=""
INSTALL_REASON=""
LAST_COMMAND_ERROR=""
PROVIDER_EDIT_INTENT=false
INJECTOR_OPT_OUT_PROFILE=""
MENU_EXIT=false
HEADER_HEALTH=unknown
SESSION_CACHE_DIR=""
FRESH_INSTALL=false
MIGRATION_TARGET_VERSION=""
FEATURE_CATALOG_SOURCE="unavailable"
FEATURE_CATALOG=()
PROVIDER_CATALOG_SOURCE="unavailable"
CATALOG_SOURCE="unavailable"
CATALOG=()
PROVIDER_CATALOG=()
CONFIG_MOUNT_PATH="/config"



# Brand palette taken from the kwatch logo: #00ACD7 (Go cyan) and #326CE5
# (Kubernetes blue), with #E8F0FE as the pale highlight. Rendered as 24-bit
# colour where the terminal advertises it, as the nearest xterm-256 entries
# otherwise, and as plain ANSI on everything else.
UI_COLOR=false
if [ "${BASH_VERSINFO[0]:-3}" -ge 4 ]; then
  UI_ESC_TIMEOUT=0.05
else
  UI_ESC_TIMEOUT=1
fi
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != dumb ]; then
  UI_COLOR=true
  UI_RESET=$'\033[0m'
  UI_BOLD=$'\033[1m'
  UI_CYAN=$'\033[36m'
  UI_GREEN=$'\033[32m'
  UI_YELLOW=$'\033[33m'
  UI_RED=$'\033[31m'
  UI_DIM=$'\033[2m'
  UI_BLUE=$'\033[34m'
  UI_MAGENTA=$'\033[35m'
  UI_CLEAR=$'\033[K'
  UI_CLEAR_LINE=$'\033[2K\r'
  UI_HIDE_CURSOR=$'\033[?25l'
  UI_SHOW_CURSOR=$'\033[?25h'
  case "${COLORTERM:-}" in
    truecolor|24bit)
      UI_BRAND=$'\033[38;2;0;172;215m'
      UI_BRAND_ALT=$'\033[38;2;50;108;229m'
      UI_BRAND_PALE=$'\033[38;2;232;240;254m'
      UI_BRAND_BG=$'\033[48;2;50;108;229m'
      ;;
    *)
      if [ "$(tput colors 2>/dev/null || echo 8)" -ge 256 ]; then
        UI_BRAND=$'\033[38;5;38m'
        UI_BRAND_ALT=$'\033[38;5;62m'
        UI_BRAND_PALE=$'\033[38;5;255m'
        UI_BRAND_BG=$'\033[48;5;62m'
      else
        UI_BRAND="$UI_CYAN"
        UI_BRAND_ALT="$UI_BLUE"
        UI_BRAND_PALE="$UI_BOLD"
        UI_BRAND_BG=$'\033[44m'
      fi
      ;;
  esac
else
  UI_RESET=""
  UI_BOLD=""
  UI_CYAN=""
  UI_GREEN=""
  UI_YELLOW=""
  UI_RED=""
  UI_DIM=""
  UI_BLUE=""
  UI_MAGENTA=""
  UI_CLEAR=""
  UI_CLEAR_LINE=""
  UI_HIDE_CURSOR=""
  UI_SHOW_CURSOR=""
  UI_BRAND=""
  UI_BRAND_ALT=""
  UI_BRAND_PALE=""
  UI_BRAND_BG=""
fi

ui_info() { printf '%s%s%s\n' "$UI_BRAND" "$*" "$UI_RESET" >&2; }
ui_success() { printf '%s%s%s\n' "$UI_GREEN" "$*" "$UI_RESET" >&2; }
ui_warn() { printf '%s%s%s\n' "$UI_YELLOW" "$*" "$UI_RESET" >&2; }
ui_error() { printf '%s%s%s\n' "$UI_RED" "$*" "$UI_RESET" >&2; }
back_hint() { printf '%s(↩️ type back)%s' "$UI_DIM" "$UI_RESET"; }
ui_heading() {
  printf '\n%s%s%s\n' "$UI_BOLD$UI_BRAND" "$*" "$UI_RESET" >&2
}
ui_detail() { printf '%s%s%s\n' "$UI_DIM" "$*" "$UI_RESET" >&2; }

# Selection lists are drawn in a fixed window: kwatch has a settings category
# with 89 entries, and a list longer than the terminal cannot be redrawn in
# place. The window scrolls with the cursor, and a list that needs scrolling
# also accepts typing to narrow it -- the only practical way through 89 items.
UI_SELECT_LABELS=()
UI_SELECT_MATCHES=()

# Indices of the entries matching the current filter, in order.
ui_select_filter() {
  local filter="$1" index label lower
  UI_SELECT_MATCHES=()
  lower=$(printf '%s' "$filter" | tr '[:upper:]' '[:lower:]')
  for index in "${!UI_SELECT_LABELS[@]}"; do
    if [ -z "$lower" ]; then
      UI_SELECT_MATCHES+=("$index")
      continue
    fi
    label=$(printf '%s' "${UI_SELECT_LABELS[$index]}" | tr '[:upper:]' '[:lower:]')
    case "$label" in
      *"$lower"*) UI_SELECT_MATCHES+=("$index") ;;
    esac
  done
}

ui_select_render() {
  local current="$1" top="$2" visible="$3" filter="$4" total row index hint
  total=${#UI_SELECT_MATCHES[@]}
  hint="  ↑/↓ move · ⏎ choose · esc back"
  [ "$total" -gt "$visible" ] &&
    hint="  ↑/↓ move · ⏎ choose · type to filter · esc back"
  [ -n "$filter" ] && hint="  filter: ${filter}_"
  printf '%s%s%s%s%s\n' "$UI_CLEAR_LINE" "$UI_DIM" "$hint" "$UI_RESET" "$UI_CLEAR" >&2
  for ((row = 0; row < visible; row++)); do
    index=$((top + row))
    if [ "$index" -ge "$total" ]; then
      printf '%s%s\n' "$UI_CLEAR_LINE" "$UI_CLEAR" >&2
      continue
    fi
    if [ "$index" -eq "$current" ]; then
      printf '%s%s%s ❯ %s%s%s\n' "$UI_CLEAR_LINE" "$UI_BOLD" "$UI_BRAND" \
        "${UI_SELECT_LABELS[${UI_SELECT_MATCHES[$index]}]}" "$UI_RESET" "$UI_CLEAR" >&2
    else
      printf '%s   %s%s%s%s\n' "$UI_CLEAR_LINE" "$UI_DIM" \
        "${UI_SELECT_LABELS[${UI_SELECT_MATCHES[$index]}]}" "$UI_RESET" "$UI_CLEAR" >&2
    fi
  done
  if [ "$total" -eq 0 ]; then
    # Filtering to nothing leaves an empty frame; say why rather than looking
    # broken, and keep the filter on screen so it can be edited back.
    printf '%s%s  no matches — backspace to edit the filter%s%s\n' \
      "$UI_CLEAR_LINE" "$UI_YELLOW" "$UI_RESET" "$UI_CLEAR" >&2
  elif [ "$total" -gt "$visible" ]; then
    printf '%s%s  %s of %s%s%s\n' "$UI_CLEAR_LINE" "$UI_DIM" \
      "$((current + 1))" "$total" "$UI_RESET" "$UI_CLEAR" >&2
  else
    printf '%s%s\n' "$UI_CLEAR_LINE" "$UI_CLEAR" >&2
  fi
}

# Clears the window plus the hint line above it and the counter below.
ui_select_erase() {
  local visible="$1" index total
  total=$((visible + 2))
  printf '\033[%sA' "$total" >&2
  for ((index = 0; index < total; index++)); do
    printf '%s\n' "$UI_CLEAR_LINE" >&2
  done
  printf '\033[%sA' "$total" >&2
}

# Prints the chosen entry's 0-based index on stdout; returns 1 when the user
# cancels. Falls back to a numbered prompt when there is no terminal to draw on,
# so pipes and KWATCH_PLAIN_UI still work.
ui_select() {
  local default_index="$1"; shift
  local count="$#" current top visible rows key rest answer index filter=""
  local total
  [ "$count" -gt 0 ] || return 1
  UI_SELECT_LABELS=("$@")
  if ! ui_interactive; then
    for ((index = 0; index < count; index++)); do
      printf '  %s) %s\n' "$((index + 1))" "${UI_SELECT_LABELS[$index]}" >&2
    done
    while true; do
      answer=$(ask "Choice" "$((default_index + 1))") || exit_expected
      if [[ "$answer" =~ ^[0-9]+$ ]] && [ "$answer" -ge 1 ] &&
        [ "$answer" -le "$count" ]; then
        printf '%s' "$((answer - 1))"
        return 0
      fi
      is_back_choice "$answer" && return 1
      ui_warn "⚠️ Choose a number from 1 to $count."
    done
  fi
  rows=$(ui_rows)
  visible=$((rows - 8))
  [ "$visible" -lt 5 ] && visible=5
  [ "$visible" -gt "$count" ] && visible="$count"
  ui_select_filter ""
  current="$default_index"
  [ "$current" -ge 0 ] && [ "$current" -lt "$count" ] || current=0
  top=0
  [ "$current" -ge "$visible" ] && top=$((current - visible + 1))
  printf '\n%s' "$UI_HIDE_CURSOR" >&2
  ui_select_render "$current" "$top" "$visible" "$filter"
  while true; do
    IFS= read -rsn1 key || {
      ui_select_erase "$visible"
      printf '%s' "$UI_SHOW_CURSOR" >&2
      input_ended
    }
    total=${#UI_SELECT_MATCHES[@]}
    case "$key" in
      $'\x1b')
        # An arrow arrives as ESC [ A; a bare Escape has nothing after it. bash
        # 3.2, still the default on macOS, rejects a fractional -t.
        IFS= read -rsn2 -t "$UI_ESC_TIMEOUT" rest || rest=""
        case "$rest" in
          '[A') [ "$total" -gt 0 ] && current=$(((current - 1 + total) % total)) ;;
          '[B') [ "$total" -gt 0 ] && current=$(((current + 1) % total)) ;;
          '')
            ui_select_erase "$visible"
            printf '%s' "$UI_SHOW_CURSOR" >&2
            return 1
            ;;
          *) ;;
        esac
        ;;
      '')
        [ "$total" -gt 0 ] || continue
        ui_select_erase "$visible"
        printf '%s' "$UI_SHOW_CURSOR" >&2
        printf '%s' "${UI_SELECT_MATCHES[$current]}"
        return 0
        ;;
      $'\x7f'|$'\b')
        if [ -n "$filter" ]; then
          filter="${filter%?}"
          ui_select_filter "$filter"
          current=0
          top=0
        fi
        ;;
      *)
        if [ "$count" -le "$visible" ]; then
          # Short list: keep the familiar shortcuts rather than filtering.
          case "$key" in
            k|K) [ "$total" -gt 0 ] && current=$(((current - 1 + total) % total)) ;;
            j|J) [ "$total" -gt 0 ] && current=$(((current + 1) % total)) ;;
            q|Q|b|B)
              ui_select_erase "$visible"
              printf '%s' "$UI_SHOW_CURSOR" >&2
              return 1
              ;;
            [1-9])
              if [ "$key" -le "$total" ]; then
                current=$((key - 1))
                ui_select_erase "$visible"
                printf '%s' "$UI_SHOW_CURSOR" >&2
                printf '%s' "${UI_SELECT_MATCHES[$current]}"
                return 0
              fi
              ;;
          esac
        else
          case "$key" in
            [[:print:]])
              filter="$filter$key"
              ui_select_filter "$filter"
              current=0
              top=0
              ;;
          esac
        fi
        ;;
    esac
    total=${#UI_SELECT_MATCHES[@]}
    [ "$current" -ge "$total" ] && current=$((total > 0 ? total - 1 : 0))
    [ "$current" -lt "$top" ] && top="$current"
    [ "$current" -ge $((top + visible)) ] && top=$((current - visible + 1))
    [ "$top" -lt 0 ] && top=0
    # The render writes the hint, the window and the counter: rewind over all
    # of them, not just the window.
    printf '\033[%sA' "$((visible + 2))" >&2
    ui_select_render "$current" "$top" "$visible" "$filter"
  done
}

# Every screen is drawn as a frame: the wordmark, one line that always says
# which cluster and workload is being managed and whether it is healthy, then
# the screen's own content. Menus clear first so the frame stays at the top;
# result screens append and end with a pause, so nothing is wiped before it has
# been read.
ui_screen_clear() {
  ui_interactive || return 0
  printf '\033[H\033[2J' >&2
}

ui_header() {
  local title="$1" health="${HEADER_HEALTH:-unknown}" dot detail
  case "$health" in
    healthy) dot=$(ui_dot ok) ;;
    absent) dot=$(ui_dot warn) ;;
    *) dot=$(ui_dot bad) ;;
  esac
  printf '\n  %s%skwatch%s %s%s%s\n' "$UI_BOLD" "$UI_BRAND" "$UI_RESET" \
    "$UI_DIM" "${title:+· $title}" "$UI_RESET" >&2
  detail="$(context_label "${SELECTED_CONTEXT:-}") · ns ${NAMESPACE:-kwatch}"
  [ -n "${INSTALL_VERSION:-}" ] && detail="$detail · ${INSTALL_VERSION}"
  printf '  %s %s%s%s\n' "$dot" "$UI_DIM" "$detail" "$UI_RESET" >&2
  ui_rule
}

ui_screen() {
  ui_screen_clear
  ui_header "$1"
}

# Result screens would otherwise be erased by the next menu redraw.
ui_pause() {
  ui_interactive || return 0
  printf '\n' >&2
  ui_detail "  Press Enter to return to the menu"
  IFS= read -r _ || true
}

ui_rows() {
  local rows
  rows=$(tput lines 2>/dev/null || true)
  [[ "$rows" =~ ^[0-9]+$ ]] || rows="${LINES:-24}"
  [[ "$rows" =~ ^[0-9]+$ ]] || rows=24
  printf '%s' "$rows"
}

ui_columns() {
  local columns
  columns=$(tput cols 2>/dev/null || true)
  # tput needs a terminal on stdout; fall back to the shell's own idea of the
  # width before giving up on 80.
  [[ "$columns" =~ ^[0-9]+$ ]] || columns="${COLUMNS:-80}"
  [[ "$columns" =~ ^[0-9]+$ ]] || columns=80
  printf '%s' "$columns"
}

# Selection rows are counted in lines, so a row that wraps would break the
# window arithmetic. Everything that goes in one is cut to fit first.
ui_truncate() {
  local text="$1" width="$2"
  if [ "$width" -le 1 ] || [ "${#text}" -le "$width" ]; then
    printf '%s' "$text"
    return
  fi
  printf '%s…' "${text:0:$((width - 1))}"
}

ui_rule() {
  printf '  %s%s%s\n' "$UI_DIM" \
    "────────────────────────────────────────────────────" "$UI_RESET" >&2
}

# An emoji built from a variation selector (⬆️, ⚙️, 🏷️) renders one column wide
# in most terminals while a plain emoji (🚀, 📦) renders two, so labels drift out
# of line when they are simply concatenated. Pass the icon separately and pad the
# label to a fixed width instead.
ui_kv() {
  local icon="$1" label="$2" value="$3"
  printf '  %s  %s%-11s%s %s%s%s\n' "$icon" "$UI_DIM" "$label" "$UI_RESET" \
    "$UI_BRAND_PALE" "$value" "$UI_RESET" >&2
}

# Green when healthy, red when not: the state is readable before the words are.
ui_dot() {
  case "$1" in
    ok) printf '%s●%s' "$UI_GREEN" "$UI_RESET" ;;
    bad) printf '%s●%s' "$UI_RED" "$UI_RESET" ;;
    *) printf '%s●%s' "$UI_YELLOW" "$UI_RESET" ;;
  esac
}

# The banner is drawn one line at a time so the manager opens with a visible
# beat rather than a wall of text. It is skipped whenever the output is not an
# interactive terminal, so logs and pipes stay clean.
# The kwatch mark drawn from its own SVG: the Kubernetes hexagon, the radar
# scope sweeping the upper-right quadrant with a detection blip, the eight
# resource dots, and the K letterform at the centre. Revealed a row at a time,
# and replaced by a plain heading wherever colour is not available.
# A small wordmark rather than a drawn logo: the manager opens on the cluster
# and the menu, and the header should not push them down the screen.
ui_banner() {
  if [ "$UI_COLOR" != true ] || [ "${KWATCH_PLAIN_UI:-false}" = true ]; then
    ui_heading "kwatch interactive manager"
    return 0
  fi
  printf '\n' >&2
  printf '  %s%skwatch%s %s·%s %sinteractive manager%s\n' \
    "$UI_BOLD" "$UI_BRAND" "$UI_RESET" "$UI_BRAND_ALT" "$UI_RESET" \
    "$UI_BRAND_PALE" "$UI_RESET" >&2
  printf '  %s%s%s\n\n' "$UI_DIM" \
    "kubectl · operational security checks" "$UI_RESET" >&2
}

context_label() {
  local context="$1" label
  case "$context" in
    arn:*:cluster/*) label="cluster/${context##*/}" ;;
    *) label="$context" ;;
  esac
  if [ "${#label}" -gt 56 ]; then
    printf '%s…%s' "${label:0:24}" "${label: -28}"
  else
    printf '%s' "$label"
  fi
}

with_loading() {
  local label="$1"; shift
  local command_name="${1:-command}"
  local output_file error_file pid frame=0 index char rc diagnostic
  local started elapsed timer="" hue
  local -a spinner_frames=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
  local -a spinner_hues=( "$UI_BRAND" "$UI_BRAND_ALT" "$UI_BRAND" "$UI_BRAND_ALT" )
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
    printf "%s%s" "$UI_CLEAR_LINE" "$UI_SHOW_CURSOR" >&2; exit 130' INT
  trap 'kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; \
    rm -f "$output_file" "$error_file"; \
    printf "%s%s" "$UI_CLEAR_LINE" "$UI_SHOW_CURSOR" >&2; exit 143' TERM
  started=$SECONDS
  printf '%s' "$UI_HIDE_CURSOR" >&2
  while kill -0 "$pid" 2>/dev/null; do
    index=$((frame % ${#spinner_frames[@]}))
    char="${spinner_frames[$index]}"
    hue="${spinner_hues[$(((frame / 4) % ${#spinner_hues[@]}))]}"
    elapsed=$((SECONDS - started))
    # Only time the waits that are long enough to make someone wonder.
    if [ "$elapsed" -ge 3 ]; then
      timer=" ${UI_DIM}${elapsed}s${UI_RESET}"
    fi
    printf '%s%s%s %s%s%s%s%s' "$UI_CLEAR_LINE" "$hue" "$char" \
      "$UI_CYAN" "$label" "$UI_RESET" "$timer" "$UI_CLEAR" >&2
    sleep 0.1
    frame=$((frame + 1))
  done
  if wait "$pid"; then
    rc=0
  else
    rc=$?
  fi
  install_signal_traps
  ui_restore_terminal
  elapsed=$((SECONDS - started))
  [ "$elapsed" -ge 3 ] && timer=" ${UI_DIM}(${elapsed}s)${UI_RESET}" || timer=""
  if [ "$rc" -eq 0 ]; then
    printf '%s%s✅ %s%s%s%s\n' "$UI_CLEAR_LINE" "$UI_GREEN" "$label" "$UI_RESET" \
      "$timer" "$UI_CLEAR" >&2
    cat "$output_file"
    cat "$error_file" >&2
    rm -f "$output_file" "$error_file"
    return 0
  fi
  printf '%s%s❌ %s%s%s%s\n' "$UI_CLEAR_LINE" "$UI_RED" "$label" "$UI_RESET" \
    "$timer" "$UI_CLEAR" >&2
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

# The spinner and the selection list hide the cursor. Without these traps, a
# Ctrl-C at the wrong moment left the terminal with no cursor until `reset`.
ui_restore_terminal() { printf '%s' "$UI_SHOW_CURSOR" >&2; }
cleanup_session() {
  local rc=$?
  ui_restore_terminal
  report_unexpected_exit "$rc"
  [ -n "$SESSION_CACHE_DIR" ] && rm -rf "$SESSION_CACHE_DIR" 2>/dev/null
  return 0
}
# Only INT is trapped. A TERM handler would catch the signal that input_ended
# sends to end the session, and bash defers it until the command substitution
# the prompt runs in has returned -- by which time the calling loop has already
# asked again, so the session never ended. TERM stays fatal by default; the
# cursor is restored before the signal is sent instead.
install_signal_traps() {
  trap 'ui_restore_terminal; exit 130' INT
  trap - TERM
}
install_signal_traps
trap cleanup_session EXIT

die() { EXPECTED_EXIT=true; ui_error "Error: $*"; exit 1; }

# `set -e` ends the manager wherever a command fails, which used to leave the
# user with a bare kubectl line and no idea what was in progress. Reported from
# the exit trap rather than from an ERR trap: an ERR trap needs errtrace to see
# failures inside functions, and errtrace also carries it into every command
# substitution, where a deliberate "cancelled" return looked like a crash.
EXPECTED_EXIT=false
exit_expected() {
  EXPECTED_EXIT=true
  exit "${1:-1}"
}
report_unexpected_exit() {
  local rc="$1"
  [ "$rc" -ne 0 ] || return 0
  [ "$EXPECTED_EXIT" != true ] || return 0
  ui_error "❌ The manager stopped unexpectedly (exit status $rc)."
  [ -n "${LAST_COMMAND_ERROR:-}" ] &&
    ui_detail "$(compact_reason "$LAST_COMMAND_ERROR")"
  ui_info \
    "ℹ️ No further changes were made. Re-run kwatch.sh and choose View status to inspect the installation."
  return 0
}

need() { type -P "$1" >/dev/null 2>&1 || die "'$1' is required"; }
require_tools() { need kubectl; need curl; }

# The manager relies on server-side dry run and on Pod Security admission, both
# of which need a reasonably recent cluster. Warn once rather than failing later
# in a way that looks like a kwatch problem.
check_cluster_version() {
  local version minor
  # "Server Version: v1.35.6-eks-bca9cf6" is one stable line across kubectl
  # versions; the JSON form splits the field across lines and needs a parser.
  version=$(command kubectl --context "$SELECTED_CONTEXT" version 2>/dev/null |
    sed -n 's/^Server Version: v\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -1 ||
    true)
  minor="${version#*.}"
  [ -n "$minor" ] && [[ "$minor" =~ ^[0-9]+$ ]] || return 0
  if [ "$minor" -lt 25 ] 2>/dev/null; then
    ui_warn \
      "⚠️ Kubernetes 1.$minor predates built-in Pod Security admission (1.25);" \
      "the manager's security verification may not apply."
  fi
}
# Every prompt is read inside a command substitution, so `die` would end only
# that subshell: the menu loop around it would then re-prompt on a closed stdin
# for ever, spinning on end-of-file. Signal the manager itself so the session
# ends when input is gone -- a closed stdin or Ctrl-D at any prompt.
# End of input is reported by exit status, not by a signal. Signalling the main
# shell left the subshell that owns the asking loop running as an orphan, and it
# span on the closed stdin for ever; every prompt site propagates this status
# instead. The ERR trap is cleared first: this exit is deliberate.
input_ended() {
  printf '\n' >&2
  ui_error "Error: input ended before the operation was complete"
  ui_restore_terminal
  exit_expected 1
}
ask() {
  local prompt="$1" default="${2:-}" answer
  [ -n "$default" ] && prompt="$prompt [$default]"
  printf '%s%s%s%s: ' "$UI_BOLD" "$UI_CYAN" "$prompt" "$UI_RESET" >&2
  IFS= read -r answer || input_ended
  printf '%s' "${answer:-$default}"
}
ask_secret() {
  local prompt="$1" answer
  printf '%s%s%s%s: ' "$UI_BOLD" "$UI_CYAN" "$prompt" "$UI_RESET" >&2
  IFS= read -r -s answer || input_ended
  printf '\n' >&2
  printf '%s' "$answer"
}
# True when the terminal can draw an interactive selection list.
ui_interactive() {
  [ -t 0 ] && [ -t 2 ] && [ "$UI_COLOR" = true ] &&
    [ "${KWATCH_PLAIN_UI:-false}" != true ]
}

ask_yes_no() {
  local prompt="$1" default="$2" answer index
  if ui_interactive; then
    printf '%s%s%s%s\n' "$UI_BOLD" "$UI_BRAND" "$prompt" "$UI_RESET" >&2
    case "$default" in
      y|Y|yes|Yes|true) index=0 ;;
      *) index=1 ;;
    esac
    # The list is erased on selection, so echo the answer: the question would
    # otherwise be left on screen with nothing under it.
    if index=$(ui_select "$index" "✅ Yes" "🚫 No"); then
      if [ "$index" = 0 ]; then
        ui_detail "  ✅ Yes"
        printf 'true'
      else
        ui_detail "  🚫 No"
        printf 'false'
      fi
    else
      ui_detail "  🚫 No"
      printf 'false'
    fi
    return 0
  fi
  while true; do
    answer=$(ask "$prompt" "$default") || exit_expected
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
  local prompt="$1" default="$2" answer index
  if ui_interactive; then
    printf '%s%s%s%s\n' "$UI_BOLD" "$UI_BRAND" "$prompt" "$UI_RESET" >&2
    case "$default" in
      y|Y|yes|Yes|true) index=0 ;;
      *) index=1 ;;
    esac
    # Cancelling the list means the same thing as choosing Back.
    index=$(ui_select "$index" "✅ Yes" "🚫 No" "↩️  Back") || {
      ui_detail "  ↩️  Back"
      return 2
    }
    case "$index" in
      0) ui_detail "  ✅ Yes"; printf 'true'; return 0 ;;
      1) ui_detail "  🚫 No"; printf 'false'; return 0 ;;
      *) ui_detail "  ↩️  Back"; return 2 ;;
    esac
  fi
  while true; do
    answer=$(ask "$prompt $(back_hint)" "$default") || exit_expected
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
    *podsecurity*|*restricted*|*hostpath*|*violat*)
      printf '%s' "A Pod Security policy rejected a volume added by the workload or an admission injector." ;;
    *admission*|*webhook*)
      printf '%s' "An admission controller rejected or changed the resource. Review the webhook or policy named in the event." ;;
    *serviceaccount*not\ found*|*service\ account*not\ found*|*serviceaccount*missing*|*service\ account*missing*|*configuration\ secret*missing*)
      printf '%s' "The workload references a missing ServiceAccount or configuration Secret. Re-run with permission to create it, then retry." ;;
    *forbidden*|*unauthorized*|*permission*denied*)
      printf '%s' "Kubernetes denied this operation. Check your account and RBAC permissions." ;;
    *immutable*|*field\ is\ immutable*|*invalid\ value*)
      printf '%s' "Kubernetes rejected a field that cannot be changed in place. Review the resources." ;;
    *imagepullbackoff*|*errimagepull*|*pull\ access\ denied*)
      printf '%s' "The cluster could not pull the kwatch image. Check registry access and network policy." ;;
    *timeout*|*timed\ out*|*connection\ refused*|*unavailable*)
      printf '%s' "The Kubernetes API or rollout did not respond in time. Check connectivity and nodes." ;;
    *)
      printf '%s' "Review the Kubernetes details below; no safe automatic fix was identified." ;;
  esac
}

failure_fix() {
  local diagnostic
  diagnostic=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$diagnostic" in
    *podsecurity*|*restricted*|*hostpath*|*violat*)
      printf '%s' "Use a workload-only injector opt-out when the manager identifies a supported injector. Do not weaken Pod Security." ;;
    *admission*|*webhook*)
      printf '%s' "Ask the cluster administrator to review the named webhook or policy, then retry." ;;
    *serviceaccount*not\ found*|*service\ account*not\ found*|*serviceaccount*missing*|*service\ account*missing*|*configuration\ secret*missing*)
      printf '%s' "Grant create/get access for the named ServiceAccount or Secret, or ask the cluster administrator to create it, then retry." ;;
    *forbidden*|*unauthorized*|*permission*denied*)
      printf '%s' "Use a Kubernetes identity allowed to create, patch, and delete kwatch resources; the manager will not grant cluster-admin automatically." ;;
    *immutable*|*field\ is\ immutable*)
      printf '%s' "Approve Deployment recreation when offered; KwatchConfig and Secrets are preserved." ;;
    *imagepullbackoff*|*errimagepull*|*pull\ access\ denied*)
      printf '%s' "Make the kwatch image reachable from the cluster or configure the required imagePullSecret, then retry." ;;
    *timeout*|*timed\ out*|*connection\ refused*|*unavailable*|*too\ many\ requests*|*rate\ limit*)
      printf '%s' "Check API/network health; the manager can safely retry this operation after you approve it." ;;
    *)
      printf '%s' "Review the details and events, correct the named resource or permission, then run the manager again." ;;
  esac
}

failure_is_retryable() {
  local diagnostic
  diagnostic=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$diagnostic" in
    *timeout*|*timed\ out*|*connection\ refused*|*connection\ reset*|*unavailable*|*too\ many\ requests*|*rate\ limit*|*serviceaccount*not\ found*|*service\ account*not\ found*|*serviceaccount*missing*|*service\ account*missing*|*configuration\ secret*missing*) return 0 ;;
  esac
  return 1
}

# Known Pod-level opt-outs for admission injectors. The keyword is matched
# against the injected volume or container named in a rejection, and against the
# names of the mutating webhooks installed in the cluster.
injector_keywords() {
  printf '%s\n' datadog istio linkerd vault kuma opentelemetry
}

provider_profile_for_keyword() {
  case "$1" in
    datadog)
      printf '%s' "Datadog|labels|admission.datadoghq.com/enabled|false" ;;
    istio)
      printf '%s' "Istio|labels|sidecar.istio.io/inject|false" ;;
    linkerd)
      printf '%s' "Linkerd|annotations|linkerd.io/inject|disabled" ;;
    vault)
      printf '%s' "Vault Agent|annotations|vault.hashicorp.com/agent-inject|false" ;;
    kuma)
      printf '%s' "Kuma|annotations|kuma.io/sidecar-injection|disabled" ;;
    opentelemetry)
      printf '%s' "OpenTelemetry|annotations|instrumentation.opentelemetry.io/inject-sdk|false" ;;
    *) return 1 ;;
  esac
}

namespace_warning_events() {
  kubectl -n "$NAMESPACE" get events --field-selector=type=Warning \
    -o custom-columns='REASON:.reason,MESSAGE:.message' --no-headers \
    2>/dev/null || true
}

# Scan every Warning event for an admission rejection instead of trusting the
# newest one. A later unrelated warning -- FailedScheduling, FailedMount, a
# failing probe on a previous ReplicaSet -- would otherwise hide the rejection
# and skip the repair. Ordering is not dependable either: lastTimestamp is unset
# on events written through events.k8s.io, which sorts them unpredictably.
admission_rejection_event() {
  namespace_warning_events |
    grep -Ei 'violates PodSecurity|restricted volume types|is forbidden' |
    tail -1 || true
}

latest_warning_event() {
  namespace_warning_events | tail -1 || true
}

installed_injector_webhooks() {
  kubectl get mutatingwebhookconfigurations \
    -o 'jsonpath={range .items[*]}{.metadata.name}{" "}{range .webhooks[*]}{.name}{" "}{.clientConfig.service.namespace}{" "}{.clientConfig.service.name}{" "}{end}{"\n"}{end}' \
    2>/dev/null | tr '[:upper:]' '[:lower:]' || true
}

# Every Pod Security rejection of a kwatch Pod comes from content the manager did
# not submit: the shipped workload runs non-root and read-only, drops all
# capabilities, and sets RuntimeDefault seccomp. Classify the whole family rather
# than hostPath alone, because an injector that adds a privileged container, a
# host namespace, or extra capabilities breaks the install in the same way and is
# repaired by the same Pod-level opt-out.
is_injected_admission_failure() {
  local diagnostic
  diagnostic=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$diagnostic" in
    *"violates podsecurity"*) return 0 ;;
  esac
  case "$diagnostic" in
    *hostpath*|*privileged*|*"unrestricted capabilities"*|*"host namespaces"*|*hostport*)
      case "$diagnostic" in
        *podsecurity*|*restricted*|*baseline*|*violates*) return 0 ;;
      esac
      ;;
  esac
  return 1
}

# Identify the injector from the rejection first, since it names the injected
# volume or container and some vendors put their name there. Vendors whose
# injected names do not carry it -- an Istio sidecar rejected for NET_ADMIN, a
# Linkerd proxy rejected for runAsUser -- are identifiable only from the webhooks
# installed in the cluster, and then only when exactly one candidate exists. The
# manager never chooses between two possible injectors.
injection_opt_out_profile() {
  local diagnostic webhooks keyword profile chosen="" matches=0
  diagnostic=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  webhooks=$(installed_injector_webhooks)
  [ -n "$webhooks" ] || return 1
  while IFS= read -r keyword; do
    [ -n "$keyword" ] || continue
    case "$diagnostic" in *"$keyword"*) ;; *) continue ;; esac
    case "$webhooks" in *"$keyword"*) ;; *) continue ;; esac
    profile=$(provider_profile_for_keyword "$keyword") || continue
    printf '%s' "$profile"
    return 0
  done < <(injector_keywords)
  while IFS= read -r keyword; do
    [ -n "$keyword" ] || continue
    case "$webhooks" in *"$keyword"*) ;; *) continue ;; esac
    profile=$(provider_profile_for_keyword "$keyword") || continue
    matches=$((matches + 1))
    chosen="$profile"
  done < <(injector_keywords)
  [ "$matches" -eq 1 ] || return 1
  printf '%s' "$chosen"
}

show_injector_candidates() {
  local candidates
  candidates=$(kubectl get mutatingwebhookconfigurations \
    -o 'jsonpath={range .items[*]}{.metadata.name}{"\n"}{end}' \
    2>/dev/null |
    grep -Ei 'datadog|istio|linkerd|vault|kuma|telemetry|inject|sidecar|mesh' \
    | head -6 || true)
  [ -n "$candidates" ] || return 0
  ui_detail "🔌 Possible injection webhooks (read-only):"
  while IFS= read -r candidate; do
    [ -n "$candidate" ] && printf '  %s\n' "$candidate"
  done <<< "$candidates"
}

# True when the workload already carries this opt-out, so an upgrade of an
# installation that was repaired earlier does not ask the same question again.
injection_opt_out_present() {
  local profile="$1" deployment provider target key value current
  IFS='|' read -r provider target key value <<< "$profile"
  deployment=$(deployment_name || true)
  [ -n "$deployment" ] || return 1
  current=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o "jsonpath={.spec.template.metadata.$target}" 2>/dev/null || true)
  case "$current" in
    *"\"$key\":\"$value\""*) return 0 ;;
  esac
  return 1
}

# Add the vendor's documented Pod-level opt-out to the kwatch Pod template only.
apply_injection_opt_out() {
  local deployment="$1" profile="$2" provider target key value patch
  IFS='|' read -r provider target key value <<< "$profile"
  check_access patch deployments namespace
  if [ "$target" = labels ]; then
    patch='{"spec":{"template":{"metadata":{"labels":{'
  else
    patch='{"spec":{"template":{"metadata":{"annotations":{'
  fi
  patch+="\"$key\":\"$value\"}}}}}"
  with_loading "Excluding kwatch from $provider injection" \
    kubectl -n "$NAMESPACE" patch deployment "$deployment" \
    --type=merge -p "$patch"
}

# Ask the API server what the cluster's admission stack will do to a compliant
# kwatch Pod before anything is applied. A server-side dry run executes the real
# mutating webhooks and the real Pod Security check, so an injector that would
# make the workload unschedulable is found in one round trip instead of after a
# five-minute rollout timeout. The probe Pod is never persisted.
#
# The probe carries the workload's own security context, so it is admissible
# under restricted on its own: any rejection is caused by injected content. It
# prints the rejection and returns non-zero; a clean or unevaluable cluster
# returns zero and the install proceeds untouched.
admission_preflight_probe() {
  local image="$1" output
  # The status has to be taken from the assignment: a `|| rc=$?` inside the
  # command substitution would set rc in its subshell and lose it here.
  if output=$(kubectl -n "$NAMESPACE" create --dry-run=server -o name -f - 2>&1 <<EOF
apiVersion: v1
kind: Pod
metadata:
  generateName: $RELEASE-admission-preflight-
  namespace: $NAMESPACE
  labels:
    app: $RELEASE
    app.kubernetes.io/instance: $RELEASE
    app.kubernetes.io/managed-by: kwatch.sh
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: probe
      image: $image
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
EOF
  ); then
    return 0
  fi
  printf '%s' "$output"
  return 1
}

# Decide the opt-out before the Deployment is applied. Nothing here can fail the
# install: an unidentified injector, a cluster that refuses the dry run, and a
# declined prompt all leave the previous behaviour in place, and the reactive
# repair still runs if the rollout then fails.
plan_injection_opt_out() {
  local image="$1" failure profile provider target key value details
  INJECTOR_OPT_OUT_PROFILE=""
  [ "${KWATCH_SKIP_ADMISSION_PREFLIGHT:-false}" = true ] && return 0
  if failure=$(admission_preflight_probe "$image"); then
    return 0
  fi
  [ -n "$failure" ] || return 0
  # A missing permission or an unsupported dry run is not a rejection; the
  # manager stays out of the way rather than reporting a cluster problem.
  is_injected_admission_failure "$failure" || return 0
  ui_warn "⚠️ An admission injector adds content that Pod Security rejects in $NAMESPACE."
  ui_detail "$(compact_reason "$failure")"
  if ! profile=$(injection_opt_out_profile "$failure"); then
    ui_warn "⚠️ The injector was not identified."
    show_injector_candidates
    ui_info "ℹ️ The manager will not guess an opt-out label or change cluster policy."
    return 0
  fi
  # Already repaired on an earlier run: re-assert it after the manifest is
  # applied so it cannot be lost, but do not ask the same question again.
  if injection_opt_out_present "$profile"; then
    INJECTOR_OPT_OUT_PROFILE="$profile"
    return 0
  fi
  IFS='|' read -r provider target key value <<< "$profile"
  details="$provider injection adds content to Pods in $NAMESPACE that Pod"
  details+=" Security rejects, so the workload could never start. This adds"
  details+=" $key=$value to the kwatch Pod template as it is created. It does not"
  details+=" change the injector, Pod Security, namespace policy, or any other"
  details+=" workload."
  if confirm_repair \
    "exclude only the kwatch Pod from $provider injection" \
    "$details"; then
    INJECTOR_OPT_OUT_PROFILE="$profile"
  fi
  return 0
}

# A rollout can also fail because no node will take the Pod. That is a different
# problem from admission and has a different repair, so classify it separately.
is_scheduling_failure() {
  local diagnostic
  diagnostic=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$diagnostic" in
    *"untolerated taint"*|*"didn't tolerate"*) return 0 ;;
  esac
  return 1
}

# Node conditions (unschedulable, not-ready, pressure) and control-plane roles
# are deliberate exclusions, not placement policy: tolerating them would put
# kwatch on a cordoned or reserved node. Only a cluster's own taints are
# offered.
is_placement_taint() {
  case "$1" in
    node.kubernetes.io/*|node-role.kubernetes.io/*|node.cloudprovider.kubernetes.io/*)
      return 1 ;;
  esac
  return 0
}

cluster_placement_taints() {
  kubectl get nodes \
    -o 'jsonpath={range .items[*]}{range .spec.taints[*]}{.key}{"="}{.value}{":"}{.effect}{"\n"}{end}{end}' \
    2>/dev/null | sort -u || true
}

# Build one toleration object per taint. A taint with no value is tolerated with
# operator Exists, which is what an empty value means on the node.
tolerations_json() {
  local taint key value effect json="" entry
  while IFS= read -r taint; do
    [ -n "$taint" ] || continue
    key="${taint%%=*}"
    value="${taint#*=}"
    effect="${value##*:}"
    value="${value%:*}"
    if [ -n "$value" ]; then
      entry="{\"key\":\"$key\",\"operator\":\"Equal\",\"value\":\"$value\",\"effect\":\"$effect\"}"
    else
      entry="{\"key\":\"$key\",\"operator\":\"Exists\",\"effect\":\"$effect\"}"
    fi
    [ -n "$json" ] && json="$json,"
    json="$json$entry"
  done
  printf '%s' "$json"
}

repair_scheduling() {
  local deployment details json taint
  local -a taints=()
  while IFS= read -r taint; do
    [ -n "$taint" ] || continue
    is_placement_taint "${taint%%=*}" || continue
    taints+=("$taint")
  done < <(cluster_placement_taints)
  if [ "${#taints[@]}" -eq 0 ]; then
    ui_warn "⚠️ No kwatch Pod can be scheduled, and no tolerable node taint was found."
    ui_info \
      "ℹ️ The cluster may have no schedulable node. The manager will not change node policy."
    return 1
  fi
  ui_detail "🏷️ Node taints blocking the Pod:"
  for taint in "${taints[@]}"; do
    printf '  %s\n' "$taint"
  done
  deployment=$(deployment_name || true)
  [ -n "$deployment" ] || deployment="$RELEASE"
  details="No node accepts the kwatch Pod because of the taints above. This adds"
  details+=" a matching toleration to the kwatch Pod template only. It does not"
  details+=" change any node, taint, or other workload."
  confirm_repair "tolerate those node taints for the kwatch Pod" "$details" ||
    return 1
  json=$(printf '%s\n' "${taints[@]}" | tolerations_json)
  [ -n "$json" ] || return 1
  check_access patch deployments namespace
  with_loading "Adding node tolerations" \
    kubectl -n "$NAMESPACE" patch deployment "$deployment" --type=merge \
    -p "{\"spec\":{\"template\":{\"spec\":{\"tolerations\":[$json]}}}}" ||
    return 1
  with_loading "Waiting for corrected kwatch rollout" \
    kubectl -n "$NAMESPACE" rollout status "deployment/$deployment" \
    --timeout="$ROLLOUT_TIMEOUT" || return 1
  ui_success "✅ kwatch is ready. The tolerations apply only to this Pod."
  return 0
}

repair_injected_hostpath() {
  local failure="$1" deployment profile provider target key value details
  if ! profile=$(injection_opt_out_profile "$failure"); then
    ui_warn "⚠️ An injector added content rejected by Pod Security, but it was not identified."
    show_injector_candidates
    ui_info "ℹ️ The manager will not guess an opt-out label or change cluster policy."
    return 1
  fi
  IFS='|' read -r provider target key value <<< "$profile"
  deployment=$(deployment_name || true)
  [ -n "$deployment" ] || deployment="$RELEASE"
  details="$provider injection added content rejected by restricted Pod"
  details+=" Security. This adds $key=$value to the kwatch Pod template, then"
  details+=" waits for a replacement Pod. It does not change the injector, Pod"
  details+=" Security, namespace policy, or any other workload."
  confirm_repair \
    "exclude only the kwatch Pod from $provider injection" \
    "$details" ||
    return 1
  if ! apply_injection_opt_out "$deployment" "$profile"; then
    return 1
  fi
  if ! with_loading "Waiting for corrected kwatch rollout" \
    kubectl -n "$NAMESPACE" rollout status "deployment/$deployment" \
    --timeout="$ROLLOUT_TIMEOUT"; then
    return 1
  fi
  if ! verify_operational_security; then
    LAST_COMMAND_ERROR="kwatch rolled out, but its operational security check failed"
    return 1
  fi
  ui_success "✅ kwatch is ready. $provider injection is disabled only for this Pod."
  return 0
}

compact_reason() {
  local compact
  compact=$(printf '%s' "$1" | sed -E \
    's#https?://[^ ]+#<url-redacted>#g; s/((token|password|secret)[=:])[[:space:]]*[^[:space:]]+/\1<redacted>/Ig; s/[[:space:]]+/ /g')
  printf '%s' "${compact:0:500}"
}

show_failure_diagnostics() {
  local operation="$1" reason="$2" safe_reason deployment pod pods summary events
  safe_reason=$(compact_reason "$reason")
  ui_heading "🔎 $operation diagnostics"
  ui_error "❌ Kubernetes reported: $safe_reason"
  ui_info "💡 Likely cause: $(failure_hint "$safe_reason")"
  ui_info "🛠️ Recommended fix: $(failure_fix "$safe_reason")"
  ui_detail "The following read-only checks help identify the exact cause."
  deployment=$(deployment_name || true)
  if [ -z "$deployment" ]; then
    deployment=$(kubectl -n "$NAMESPACE" get deployment "$RELEASE" \
      -o jsonpath='{.metadata.name}' 2>/dev/null || true)
  fi
  if [ -n "$deployment" ]; then
    ui_detail "📦 Deployment: $NAMESPACE/$deployment"
    summary=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
      -o custom-columns='READY:.status.readyReplicas,DESIRED:.spec.replicas,UPDATED:.status.updatedReplicas,AVAILABLE:.status.availableReplicas,REASON:.status.conditions[-1].reason' \
      --no-headers 2>/dev/null || true)
    [ -n "$summary" ] && printf '  %s\n' "$summary" ||
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
      summary=$(kubectl -n "$NAMESPACE" get pod "$pod" \
        -o custom-columns='PHASE:.status.phase,READY:.status.containerStatuses[0].ready,REASON:.status.containerStatuses[0].state.waiting.reason' \
        --no-headers 2>/dev/null || true)
      [ -n "$summary" ] && printf '  %s\n' "$summary" ||
        ui_detail "Pod details are unavailable."
    done <<< "$pods"
  fi
  ui_detail "🕒 Recent namespace events:"
  events=$(namespace_warning_events | tail -8 || true)
  if [ -n "$events" ]; then
    while IFS= read -r summary; do
      summary=$(printf '%s' "$summary" | sed -E \
        's#https?://[^ ]+#<url-redacted>#g; s/((token|password|secret)[=:])[[:space:]]*[^[:space:]]+/\1<redacted>/Ig')
      printf '  %s\n' "${summary:0:320}"
    done <<< "$events"
  else
    ui_detail "No warning events were found or events are unavailable."
  fi
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

  # An explicit context makes a command usable from a script or a pipeline,
  # where the manager cannot ask which cluster is meant. It is still named
  # explicitly: the manager never falls back to the current context on its own.
  if [ -n "${KWATCH_CONTEXT:-}" ]; then
    for context in "${contexts[@]}"; do
      if [ "$context" = "$KWATCH_CONTEXT" ]; then
        SELECTED_CONTEXT="$context"
        break
      fi
    done
    [ -n "$SELECTED_CONTEXT" ] ||
      die "context '$KWATCH_CONTEXT' was not found in kubeconfig"
  elif [ "${#contexts[@]}" -eq 1 ]; then
    SELECTED_CONTEXT="${contexts[0]}"
  else
    [ -t 0 ] || die "multiple Kubernetes contexts found; choose one with KWATCH_CONTEXT=<name> or run in an interactive terminal"
    ui_heading "🧭 Select the Kubernetes cluster to manage"
    local -a labels=()
    for index in "${!contexts[@]}"; do
      if [ "${contexts[$index]}" = "$current" ]; then
        labels+=("$(context_label "${contexts[$index]}") ${UI_GREEN}(current)${UI_RESET}")
        default_choice="$index"
      else
        labels+=("$(context_label "${contexts[$index]}")")
      fi
    done
    [ -n "$default_choice" ] || default_choice=0
    # Cancelling the picker is a decision, not a failure.
    choice=$(ui_select "$default_choice" "${labels[@]}") || {
      ui_info "↩️ No cluster selected; nothing was changed."
      exit_expected 0
    }
    SELECTED_CONTEXT="${contexts[$choice]}"
  fi

  server=$(command kubectl --context "$SELECTED_CONTEXT" config view --minify \
    -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true)
  [ -n "$server" ] || die "could not read the Kubernetes server for the selected context"
  ui_detail "  Selected cluster: $(context_label "$SELECTED_CONTEXT")"
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
  if [ -n "$version" ] && with_loading "Loading settings catalog" \
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
  if [ -n "$version" ] && with_loading "Loading capability catalog" \
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
  kubectl -n "$NAMESPACE" label secret "$BACKUP_NAME" \
    app.kubernetes.io/instance="$RELEASE" \
    app.kubernetes.io/managed-by=kwatch.sh --overwrite >/dev/null 2>&1 || true
  prune_config_backups
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
    for entry in ${PROVIDER_CATALOG[@]+"${PROVIDER_CATALOG[@]}"}; do
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
  for entry in ${PROVIDER_CATALOG[@]+"${PROVIDER_CATALOG[@]}"}; do
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
  for entry in ${PROVIDER_CATALOG[@]+"${PROVIDER_CATALOG[@]}"}; do
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
    count=$(ask "Number of custom webhook headers $(back_hint)" "0") || exit_expected
    is_back_choice "$count" && return 2
    [[ "$count" =~ ^[0-9]+$ ]] && break
    ui_warn "⚠️ Header count must be a non-negative integer."
  done
  [ "$count" -gt 0 ] || return 0
  printf '    headers:\n' >>"$file"
  for ((i = 1; i <= count; i++)); do
    while true; do
      name=$(ask "Header $i name $(back_hint)") || exit_expected
      is_back_choice "$name" && return 2
      [ -n "$name" ] && break
      ui_warn "⚠️ Header name cannot be empty."
    done
    while true; do
      value=$(ask_secret "Header $i value $(back_hint)") || exit_expected
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

# Reading each setting with its own API call meant ten round trips to draw one
# category. jsonpath can emit several fields in one response, one per line.
config_values_for_paths() {
  local path jsonpath=""
  for path in "$@"; do
    jsonpath="${jsonpath}{.spec.${path}}{\"\\n\"}"
  done
  [ -n "$jsonpath" ] || return 0
  kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" \
    -o "jsonpath=$jsonpath" 2>/dev/null || true
}

configure_flow() {
  local deployment choice category entry path type default category_name
  local description status replacement current value display_value prompt_default
  local decision index row path_width value_width description_width
  local -a categories=() category_labels=() entries=() labels=() values=() paths=()
  require_config_catalog
  # No confirmation to reach the list: nothing is written by browsing it, and
  # each individual change is confirmed on its own below.
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
  categories=("Alerts" "Scope" "Performance" "Incident memory" "Noise reduction"
    "Monitors" "Operations" "Compatibility" "Product control" "Security")
  category_labels=("🚨 Alerts" "🎯 Scope" "⚡ Performance" "🧠 Incident memory"
    "🔇 Noise reduction" "🔍 Monitors" "🛠️  Operations" "🔄 Compatibility"
    "🎛️  Product control" "🔒 Security" "↩️  Back")
  while true; do
    ui_heading "⚙️  kwatch configuration"
    choice=$(ui_select 0 "${category_labels[@]}") || return 0
    [ "$choice" -lt "${#categories[@]}" ] || return 0
    category="${categories[$choice]}"

    entries=()
    paths=()
    for entry in ${CATALOG[@]+"${CATALOG[@]}"}; do
      IFS='|' read -r path type default category_name description status replacement <<<"$entry"
      [ "$category_name" = "$category" ] || continue
      entries+=("$entry")
      paths+=("$path")
    done
    if [ "${#entries[@]}" -eq 0 ]; then
      ui_info "ℹ️ No settings in $category."
      continue
    fi
    values=()
    while IFS= read -r current; do
      values+=("$current")
    done < <(config_values_for_paths "${paths[@]}")
    # Three columns: the setting, what it is set to, and what it does. The
    # description comes straight from the release catalog, so it always matches
    # the version installed.
    path_width=0
    for path in "${paths[@]}"; do
      [ "${#path}" -gt "$path_width" ] && path_width="${#path}"
    done
    [ "$path_width" -gt 34 ] && path_width=34
    # Size the value column to the values actually present so the description
    # keeps the rest of the line, and leave room for the row marker or the
    # numbered prefix the plain fallback adds.
    value_width=8
    for index in "${!entries[@]}"; do
      IFS='|' read -r path type default category_name description status replacement <<<"${entries[$index]}"
      display_value="${values[$index]:-default: $default}"
      [ "${#display_value}" -gt "$value_width" ] && value_width="${#display_value}"
    done
    [ "$value_width" -gt 16 ] && value_width=16
    description_width=$(($(ui_columns) - path_width - value_width - 12))
    [ "$description_width" -lt 16 ] && description_width=0
    labels=()
    for index in "${!entries[@]}"; do
      IFS='|' read -r path type default category_name description status replacement <<<"${entries[$index]}"
      display_value="${values[$index]:-}"
      [ -n "$display_value" ] || display_value="default: $default"
      printf -v row '%-*s  %-*s' \
        "$path_width" "$(ui_truncate "$path" "$path_width")" \
        "$value_width" "$(ui_truncate "$display_value" "$value_width")"
      if [ "$description_width" -gt 0 ] && [ -n "$description" ]; then
        row="$row  ${UI_DIM}$(ui_truncate "$description" "$description_width")${UI_RESET}"
      fi
      labels+=("$row")
    done
    labels+=("↩️  Back")
    ui_heading "📋  $category settings"
    choice=$(ui_select 0 "${labels[@]}") || continue
    [ "$choice" -lt "${#entries[@]}" ] || continue

    entry="${entries[$choice]}"
    IFS='|' read -r path type default category_name description status replacement <<<"$entry"
    if [ "$status" = secret ]; then
      ui_info "🔐 Secret-backed settings are changed with Edit notification providers."
      continue
    fi
    current="${values[$choice]:-}"
    show_catalog_entry "$entry"
    [ "$status" = deprecated ] &&
      ui_warn "⚠️ Existing values are preserved; migration is not destructive."
    case "$type" in
      boolean)
        # A true/false setting is a choice, not something to spell out.
        if [ "${current:-$default}" = true ]; then
          decision=$(ask_yes_no_or_back "Enable ${path%.enabled}?" "y") || continue
        else
          decision=$(ask_yes_no_or_back "Enable ${path%.enabled}?" "n") || continue
        fi
        value="$decision"
        ;;
      *)
        prompt_default="$current"
        [ -n "$prompt_default" ] || prompt_default="$default"
        value=$(ask "New value (Enter keeps current) $(back_hint)" \
          "$prompt_default") || exit_expected
        is_back_choice "$value" && continue
        [ -n "$value" ] || continue
        ;;
    esac
    [ "$value" = "$current" ] && {
      ui_info "↩️ $path is already $value."
      continue
    }
    confirm_change \
      "⚙️ Change $path to '$value'." \
      "The current value is '${current:-default ($default)}'. kwatch will validate the new value and restart the workload if needed." || {
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
  done
}

configure_alert_flow() {
  local backup deployment had_backup=false rc
  require_provider_catalog
  # No confirmation here: reaching this flow is already a deliberate choice, and
  # nothing is written until the save step. Every prompt below accepts "back".
  PROVIDER_EDIT_INTENT=true
  ui_detail "Nothing is saved until the end; type back at any prompt to leave."
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
  version=$(printf '%s' "$response" |
    sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
    head -1 || true)
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
  choice=$(ui_select 0 \
    "✅ Stable ($stable) ${UI_DIM}[recommended]${UI_RESET}" \
    "🧪 Release candidate ($preview)") || return 1
  case "$choice" in
    0) printf '%s' "$stable" ;;
    *) printf '%s' "$preview" ;;
  esac
}

# Discovering the Deployment costs up to five API calls, and it is asked for by
# the status screen, the menus, the diagnostics and every health check. Resolve
# it once per action and invalidate whenever the workload itself changes.
# The cache lives in a file, not a variable: almost every caller asks for the
# name inside a command substitution, and a variable set there would be lost
# with the subshell.
deployment_name() {
  local file="" name
  [ -n "$SESSION_CACHE_DIR" ] && file="$SESSION_CACHE_DIR/deployment-name"
  if [ -n "$file" ] && [ -f "$file" ]; then
    cat "$file"
    return 0
  fi
  name=$(deployment_name_uncached || true)
  if [ -n "$file" ]; then
    printf '%s' "$name" >"$file" 2>/dev/null || true
  fi
  printf '%s' "$name"
}

# Everything derived from the workload is invalidated together: they all go
# stale for the same reasons.
invalidate_deployment_name() {
  [ -n "$SESSION_CACHE_DIR" ] || return 0
  rm -f "$SESSION_CACHE_DIR/deployment-name" \
    "$SESSION_CACHE_DIR/workload-selector" \
    "$SESSION_CACHE_DIR/failed-components" 2>/dev/null || true
  return 0
}

deployment_name_uncached() {
  local name app template_app service_account
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
  [ "$app" = kwatch ] && {
    kubectl -n "$NAMESPACE" get deployment "$RELEASE" \
      -o jsonpath='{.metadata.name}' 2>/dev/null || true
    return 0
  }
  # Some legacy manifests put the app label only on the Pod template and
  # leave Deployment metadata unlabeled. The exact release name plus this
  # template identity is sufficient to recognize kwatch safely.
  template_app=$(kubectl -n "$NAMESPACE" get deployment "$RELEASE" \
    -o 'jsonpath={.spec.template.metadata.labels.app}' 2>/dev/null || true)
  service_account=$(kubectl -n "$NAMESPACE" get deployment "$RELEASE" \
    -o 'jsonpath={.spec.template.spec.serviceAccountName}' 2>/dev/null || true)
  if [ "$template_app" = kwatch ] || [ "$service_account" = "$RELEASE" ]; then
    kubectl -n "$NAMESPACE" get deployment "$RELEASE" \
      -o jsonpath='{.metadata.name}' 2>/dev/null || true
  fi
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
    rollout status "deployment/$deployment" --timeout="$ROLLOUT_TIMEOUT" || return 1
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
  HEADER_HEALTH=unknown
  INSTALL_DEPLOYMENT=""
  INSTALL_VERSION=""
  INSTALL_REASON=""
  INSTALL_DEPLOYMENT=$(deployment_name || true)
  if [ -z "$INSTALL_DEPLOYMENT" ]; then
    INSTALL_REASON="no kwatch Deployment was found"
    HEADER_HEALTH=absent
    return 0
  fi

  INSTALL_VERSION=$(installed_version || true)
  if [ -z "$INSTALL_VERSION" ]; then
    INSTALL_STATE=broken
    INSTALL_REASON="the Deployment image version could not be determined"
    return 0
  fi
  if version_is_legacy "$INSTALL_VERSION"; then
    INSTALL_STATE=legacy
    return 0
  fi
  if ! deployment_is_running "$INSTALL_DEPLOYMENT"; then
    INSTALL_STATE=broken
    INSTALL_REASON="the Deployment has no available replicas"
    return 0
  fi
  INSTALL_STATE=supported
  HEADER_HEALTH=healthy
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

# Ask once. Retrying here cannot help: the picker offers the same two releases
# every time, so a legacy-only choice repeated the warning for ever -- and once
# input ran out, `die` inside the command substitution ended only that subshell
# while this loop kept calling GitHub.
select_modern_release_version() {
  local version
  version=$(select_release_version) || return 1
  if version_is_legacy "$version"; then
    ui_warn "⚠️ $version is older than v1.0.0 and cannot be managed by this manager."
    return 1
  fi
  printf '%s' "$version"
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

# A repair re-applies the release that is already installed, so the equal case is
# accepted when the caller asks for it. Without that, a broken installation on
# the newest release had no way forward: every offered release compares as "not
# newer", and the prompt repeated for ever.
# Compare before prompting. The channel question used to come first, so an
# installation already on the newest release was asked to pick a channel, told
# to confirm the release candidate, and only then informed there was nothing to
# upgrade to.
select_upgrade_version() {
  local current="$1" allow_same="${2:-false}" stable preview version comparison
  local choice label
  local -a versions=() labels=()
  stable=$(latest_version || true)
  preview=$(latest_release_candidate || true)
  for version in "$stable" "$preview"; do
    [ -n "$version" ] || continue
    version_is_legacy "$version" && continue
    case " ${versions[*]-} " in
      *" $version "*) continue ;;
    esac
    comparison=$(compare_release_versions "$version" "$current")
    case "$comparison" in
      1) label="newer" ;;
      0)
        [ "$allow_same" = true ] || continue
        label="reinstall the running release"
        ;;
      *) continue ;;
    esac
    versions+=("$version")
    if [ "$version" = "$preview" ]; then
      labels+=("🧪 $version  ${UI_DIM}release candidate · $label${UI_RESET}")
    else
      labels+=("✅ $version  ${UI_DIM}stable · $label${UI_RESET}")
    fi
  done
  if [ "${#versions[@]}" -eq 0 ]; then
    ui_success "✅ kwatch $current is the newest available release; nothing to upgrade."
    return 1
  fi
  if [ "${#versions[@]}" -eq 1 ]; then
    printf '%s' "${versions[0]}"
    return 0
  fi
  ui_info "📦 Releases newer than $current:"
  choice=$(ui_select 0 "${labels[@]}") || return 2
  printf '%s' "${versions[$choice]}"
}

# Three catalogs load before most screens. Announcing each one cost six lines
# every time a configuration screen was opened, and said the same thing each
# time. Report only what the operator cannot infer: a failure, or a catalog
# served from cache rather than the release.
load_catalog_bundle() {
  local version="$1" report="${2:-true}" ok=true
  if load_catalog_for_version "$version"; then
    case "$CATALOG_SOURCE" in
      release:*) ;;
      *) ui_detail "📚 Configuration catalog served from $CATALOG_SOURCE." ;;
    esac
  else
    [ "$report" = true ] &&
      ui_error "❌ Configuration catalog unavailable for $version."
    ok=false
  fi
  if load_feature_catalog_for_version "$version"; then
    case "$FEATURE_CATALOG_SOURCE" in
      release:*) ;;
      *) ui_detail "🧩 Feature catalog served from $FEATURE_CATALOG_SOURCE." ;;
    esac
  else
    [ "$report" = true ] &&
      ui_error "❌ Feature catalog unavailable for $version."
    ok=false
  fi
  if load_provider_catalog_for_version "$version"; then
    case "$PROVIDER_CATALOG_SOURCE" in
      release:*) ;;
      *) ui_detail "🔌 Provider catalog served from $PROVIDER_CATALOG_SOURCE." ;;
    esac
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

# Seventy-odd capabilities printed at once is a wall, not a screen. They are
# already namespaced by area, so browse by area and print one area at a time.
feature_areas() {
  printf '%s\n' "${FEATURE_CATALOG[@]}" | cut -d'|' -f1 | cut -d. -f1 | sort -u
}

show_feature_area() {
  local area="$1" entry id lifecycle description dependencies line shown=0
  for entry in ${FEATURE_CATALOG[@]+"${FEATURE_CATALOG[@]}"}; do
    IFS='|' read -r id lifecycle description dependencies <<<"$entry"
    case "$area" in
      "") ;;
      *) case "$id" in "$area".*|"$area") ;; *) continue ;; esac ;;
    esac
    if [ -n "$dependencies" ]; then
      printf -v line '%-42s %-7s %s (needs: %s)' \
        "$id" "$lifecycle" "$description" "$dependencies"
    else
      printf -v line '%-42s %-7s %s' "$id" "$lifecycle" "$description"
    fi
    ui_detail "  $line"
    shown=$((shown + 1))
  done
  printf '\n' >&2
  ui_detail "  $shown capabilities"
}

features_flow() {
  local area choice count
  local -a areas=() labels=()
  [ "${#FEATURE_CATALOG[@]}" -gt 0 ] || die "feature catalog is unavailable; retry while the release artifact is reachable"
  while IFS= read -r area; do
    [ -n "$area" ] && areas+=("$area")
  done < <(feature_areas)
  while true; do
    ui_screen "capabilities"
    labels=()
    for area in "${areas[@]}"; do
      count=$(printf '%s\n' "${FEATURE_CATALOG[@]}" | cut -d'|' -f1 |
        grep -c "^$area\." || true)
      labels+=("🧩 $area  ${UI_DIM}$count${UI_RESET}")
    done
    labels+=("📋 Everything" "↩️  Back")
    choice=$(ui_select 0 "${labels[@]}") || return 0
    if [ "$choice" -lt "${#areas[@]}" ]; then
      ui_screen "capabilities · ${areas[$choice]}"
      show_feature_area "${areas[$choice]}"
      ui_pause
    elif [ "$choice" -eq "${#areas[@]}" ]; then
      ui_screen "capabilities · all"
      show_feature_area ""
      ui_pause
    else
      return 0
    fi
  done
}

provider_available() {
  local entry provider display field type required secret validation default
  local description group condition
  for entry in ${PROVIDER_CATALOG[@]+"${PROVIDER_CATALOG[@]}"}; do
    IFS='|' read -r provider display field type required secret validation default \
      description group condition <<<"$entry"
    case "${CONFIGURED_PROVIDERS:-|}" in
      *"|$provider|"*) continue ;;
    esac
    return 0
  done
  return 1
}

# Defined at top level: nesting it meant the helper was redefined on every call
# and leaked into the global scope anyway.
delete_owned() {
    local scope="$1" kind="$2" name="$3" owner app service_account
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
      if [ "$app" = kwatch ]; then
        owner=kwatch.sh
      else
        app=$(kubectl -n "$NAMESPACE" get deployment "$name" \
          -o 'jsonpath={.spec.template.metadata.labels.app}' \
          2>/dev/null || true)
        service_account=$(kubectl -n "$NAMESPACE" get deployment "$name" \
          -o 'jsonpath={.spec.template.spec.serviceAccountName}' \
          2>/dev/null || true)
        if [ "$app" = kwatch ] || [ "$service_account" = "$RELEASE" ]; then
          owner=kwatch.sh
        fi
      fi
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

remove_namespaced_workload() {
  invalidate_deployment_name
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
  kubectl -n "$NAMESPACE" rollout status "deployment/$deployment" --timeout="$ROLLOUT_TIMEOUT" >/dev/null 2>&1 || true
}

# Fifty-six providers: too many to read, and the old prompt asked for "name,
# number, or search" without saying which the input would be treated as. The
# selection list filters as you type, so one list replaces the search, the
# browse listing, the numeric match and the disambiguation prompt.
choose_provider() {
  local entry provider display field type required secret validation default
  local description group condition seen="|" choice
  local -a providers=() displays=()
  for entry in ${PROVIDER_CATALOG[@]+"${PROVIDER_CATALOG[@]}"}; do
    IFS='|' read -r provider display field type required secret validation default \
      description group condition <<<"$entry"
    case "${CONFIGURED_PROVIDERS:-|}" in
      *"|$provider|"*) continue ;;
    esac
    case "$seen" in
      *"|$provider|"*) continue ;;
    esac
    providers+=("$provider")
    displays+=("🔌 $display")
    seen="${seen}${provider}|"
  done
  if [ "${#PROVIDER_CATALOG[@]}" -eq 0 ]; then
    ui_error "❌ The provider catalog is unavailable; provider selection cannot continue."
    return 2
  fi
  if [ "${#providers[@]}" -eq 0 ]; then
    ui_warn "⚠️ Every provider in the catalog is already configured."
    return 2
  fi
  ui_heading "📣  Where should kwatch send alerts?"
  displays+=("↩️  Back")
  choice=$(ui_select 0 "${displays[@]}") || return 2
  [ "$choice" -lt "${#providers[@]}" ] || return 2
  PROVIDER="${providers[$choice]}"
  ui_success "✅ Provider selected: ${displays[$choice]#🔌 }"
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
  for entry in ${PROVIDER_CATALOG[@]+"${PROVIDER_CATALOG[@]}"}; do
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
  local description group condition choice value selected
  local seen="|"
  local -a groups=() values=() labels=()
  PROVIDER_GROUP_SELECTIONS="|"
  for entry in ${PROVIDER_CATALOG[@]+"${PROVIDER_CATALOG[@]}"}; do
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
    for entry in ${PROVIDER_CATALOG[@]+"${PROVIDER_CATALOG[@]}"}; do
      IFS='|' read -r provider display field type required secret validation default \
        description entry_group condition <<<"$entry"
      [ "$provider" = "$PROVIDER" ] || continue
      [ "$entry_group" = "$group" ] || continue
      case "$condition" in
        choice:*) values+=("${condition#choice:}|$field|$description") ;;
      esac
    done
    [ "${#values[@]}" -gt 0 ] || continue
    ui_heading "🔐  Choose $group"
    labels=()
    for value in "${values[@]}"; do
      IFS='|' read -r selected field description <<<"$value"
      labels+=("🔑 $(printf '%-10s' "$selected") ${UI_DIM}$description${UI_RESET}")
    done
    labels+=("↩️  Back")
    choice=$(ui_select 0 "${labels[@]}") || return 2
    [ "$choice" -lt "${#values[@]}" ] || return 2
    value="${values[$choice]}"
    IFS='|' read -r selected field description <<<"$value"
    set_provider_group_value "$group" "$selected"
    ui_detail "  🔑 $selected"
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
      value=$(ask_secret "$description $(back_hint)") || exit_expected
    else
      value=$(ask "$description $(back_hint)" "$default") || exit_expected
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
    for entry in ${PROVIDER_CATALOG[@]+"${PROVIDER_CATALOG[@]}"}; do
      write_provider_field "$entry" required "$configure_optional" \
        "$priority" || { rc=$?; return "$rc"; }
    done
  done
  # Keep at-least-one destination groups in catalog order. This lets the user
  # choose the first destination without being forced into the last row.
  for entry in ${PROVIDER_CATALOG[@]+"${PROVIDER_CATALOG[@]}"}; do
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
    for entry in ${PROVIDER_CATALOG[@]+"${PROVIDER_CATALOG[@]}"}; do
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
    if [ "${PROVIDER_EDIT_INTENT:-false}" = true ]; then
      # The caller asked for provider editing; asking again answers itself.
      printf 'edit'
      return
    fi
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
  while true; do
    choice=$(ui_select 0 \
      "✏️  Edit or add providers" \
      "✅ Keep providers unchanged" \
      "🗑️  Remove all providers" \
      "↩️  Back") || { printf 'back'; return; }
    case "$choice" in
      0) printf 'edit'; return ;;
      1) printf 'keep'; return ;;
      2)
        confirm_action "Remove all configured notification providers" "n" ||
          continue
        printf 'empty'
        return
        ;;
      *) printf 'back'; return ;;
    esac
  done
}

write_config_secret() {
  local secret_name="${CONFIG_SECRET_NAME:-${RELEASE}-config}"
  local tmp_dir config_tmp provider_action provider_snapshot rc
  local add_provider keep_existing
  local entry path type default category description status replacement value
  local old_value
  local encoded legacy_config configure_secrets
  local -a secret_args_before=() secret_paths=()
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
  # These are Secret-backed extras unrelated to providers -- a heartbeat URL and
  # a diagnostics token. Asking for each one on every provider edit was two
  # prompts that are almost always answered with Enter, so ask once whether they
  # are wanted at all; declining keeps whatever is already stored.
  secret_paths=()
  for entry in ${CATALOG[@]+"${CATALOG[@]}"}; do
    IFS='|' read -r path type default category description status replacement <<<"$entry"
    [ "$status" = secret ] || continue
    secret_paths+=("$path")
  done
  configure_secrets=false
  if [ "${#secret_paths[@]}" -gt 0 ] &&
    [ "$(ask_yes_no "🔐 Set the Secret-backed extras (${secret_paths[*]}) now?" "n")" = true ]; then
    configure_secrets=true
  fi
  for entry in ${CATALOG[@]+"${CATALOG[@]}"}; do
    IFS='|' read -r path type default category description status replacement <<<"$entry"
    [ "$status" = secret ] || continue
    if [ "$configure_secrets" != true ]; then
      if ! preserve_config_secret "$config_tmp" "$path" "$tmp_dir"; then
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
      fi
      continue
    fi
    while true; do
      value=$(ask_secret \
        "$description (leave empty to skip) $(back_hint)") || exit_expected
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

# A Secret volume is written root:root with exactly the mode the manifest asks
# for, and Kubernetes group-owns it only when the Pod sets fsGroup. The workload
# mounts its configuration with defaultMode 0400 and runs as a non-root user, so
# without fsGroup the container cannot read /config/config.yaml: the rollout
# succeeds and the Pod then crash-loops on "permission denied". Add fsGroup when
# the release manifest omits it, matching the group the container already runs
# as. The Secret keeps mode 0400 in the manifest, and the volume becomes
# readable by that group only.
ensure_config_volume_readable() {
  local manifest="$1" gid rewritten
  grep -q '^        fsGroup:' "$manifest" && return 0
  grep -q 'defaultMode: 0*400$' "$manifest" || return 0
  gid=$(awk '/^[[:space:]]*runAsGroup:[[:space:]]*[0-9]+[[:space:]]*$/ {
    print $2; exit }' "$manifest")
  [ -n "$gid" ] || return 0
  rewritten=$(mktemp)
  # Add fsGroup to the Pod security context, creating that block before the
  # container list when the release does not declare one at all.
  if ! awk -v gid="$gid" '
    /^      securityContext:[[:space:]]*$/ && inserted == 0 {
      print
      print "        fsGroup: " gid
      inserted = 1
      next
    }
    /^      containers:[[:space:]]*$/ && inserted == 0 {
      print "      securityContext:"
      print "        fsGroup: " gid
      inserted = 1
    }
    { print }
  ' "$manifest" >"$rewritten"; then
    rm -f "$rewritten"
    return 0
  fi
  grep -q '^        fsGroup: ' "$rewritten" || { rm -f "$rewritten"; return 0; }
  mv "$rewritten" "$manifest" || { rm -f "$rewritten"; return 0; }
  ui_detail \
    "🔑 Added fsGroup $gid so the non-root workload can read its 0400 configuration Secret."
}

# Updating a workload someone else may have hand-edited is easier to agree to
# when the change is visible first. Offered only when there is something to
# compare against, and never on a fresh install.
preview_manifest_changes() {
  local manifest="$1" existing="$2" answer diff_output
  [ -n "$existing" ] || return 0
  ui_interactive || return 0
  answer=$(ask_yes_no "🔍 Show what this will change in the cluster first?" n)
  [ "$answer" = true ] || return 0
  diff_output=$(kubectl diff -f "$manifest" 2>&1 || true)
  if [ -z "$diff_output" ]; then
    ui_info "ℹ️ No differences: the cluster already matches this release."
    return 0
  fi
  ui_rule
  printf '%s\n' "$diff_output" | head -120 |
    sed -E 's#https?://[^ ]+#<url-redacted>#g;
      s/((token|password|secret)[=:])[[:space:]]*[^[:space:]]+/\1<redacted>/Ig'
  ui_rule
}

# kwatch's readiness self-check asks the API server whether it may update and
# patch configmaps in its namespace *without* naming one, and the Role the
# release ships scopes those verbs with resourceNames, which can never answer
# yes. The security component then reports rbacDenied, /readyz stays 503, and the
# Pod never becomes Ready even though every write it makes succeeds. Add the
# unnamed rule the check needs; it is a no-op once the release grants it.
# kwatch's readiness self-check asks the API server whether it may update and
# patch configmaps in its namespace *without* naming one, which a
# resourceNames-scoped rule can never answer yes to. Rather than assume every
# release has that mismatch and widen the Role on every install, ask the same
# question the component asks. A release that fixes the check, or a Role that
# already grants it, answers yes and nothing is changed.
self_check_rbac_missing() {
  local subject="system:serviceaccount:$NAMESPACE:$RELEASE" verb answer
  for verb in update patch; do
    answer=$(kubectl auth can-i "$verb" configmaps -n "$NAMESPACE" \
      --as="$subject" 2>/dev/null || true)
    case "$answer" in
      *no*) return 0 ;;
      *yes*) ;;
      # Impersonation is not allowed here, so the question cannot be asked.
      *) return 1 ;;
    esac
  done
  return 1
}

repair_self_check_rbac() {
  local role="${RELEASE}-configmap-manager" details
  kubectl -n "$NAMESPACE" get role "$role" >/dev/null 2>&1 || return 1
  details="kwatch checks this permission without naming a ConfigMap, so the"
  details+=" scoped rule the release ships can never satisfy it and the Pod"
  details+=" never reports ready. This adds get/update/patch on configmaps in"
  details+=" $NAMESPACE to $role. It widens that Role inside this namespace only."
  confirm_repair "grant the permission the readiness check asks for" "$details" ||
    return 1
  check_access patch roles namespace
  with_loading "Updating $role" kubectl -n "$NAMESPACE" patch role "$role" \
    --type=json -p '[{"op":"add","path":"/rules/-","value":{"apiGroups":[""],"resources":["configmaps"],"verbs":["get","update","patch"]}}]' \
    >/dev/null || return 1
  restart_kwatch || return 1
  ui_success "✅ Readiness check permission granted."
  return 0
}

apply_manifests() {
  local version="$1" tmp crd_tmp apply_tmp="" deployment existing_deployment
  local rollout_error event_detail
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
  ensure_config_volume_readable "$tmp"
  preview_manifest_changes "$tmp" "$existing_deployment"
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
  plan_injection_opt_out "ghcr.io/abahmed/kwatch:$version"
  invalidate_deployment_name
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
  if ! verify_runtime_dependencies; then
    return 1
  fi
  if [ "${TLS_MONITOR_ENABLED:-false}" = true ]; then
    enable_initial_tls_monitor
  elif [ "$(config_value tlsMonitor.enabled)" = true ]; then
    verify_runtime_tls_access
  fi
  deployment=$(deployment_name)
  [ -n "$deployment" ] || deployment="$RELEASE"
  if [ -n "$INJECTOR_OPT_OUT_PROFILE" ] &&
    ! apply_injection_opt_out "$deployment" "$INJECTOR_OPT_OUT_PROFILE"; then
    return 1
  fi
  if with_loading "Waiting for kwatch rollout" \
    kubectl -n "$NAMESPACE" rollout status "deployment/$deployment" \
    --timeout="$ROLLOUT_TIMEOUT"; then
    return 0
  fi
  rollout_error="${LAST_COMMAND_ERROR:-rollout did not become ready}"
  event_detail=$(admission_rejection_event)
  [ -n "$event_detail" ] || event_detail=$(latest_warning_event)
  LAST_COMMAND_ERROR="Deployment was applied, but its rollout failed: $rollout_error"
  [ -n "$event_detail" ] &&
    LAST_COMMAND_ERROR="$LAST_COMMAND_ERROR Latest warning event: $event_detail"
  ui_error "❌ Deployment was applied, but the rollout did not become ready."
  return 1
}

recreate_deployment() {
  local deployment="$1" manifest="$2"
  ui_warn \
    "⚠️ Existing Deployment could not be reconciled; recreating it" \
    "while preserving KwatchConfig and Secrets."
  check_access delete deployments namespace
  with_loading "Removing invalid kwatch Deployment" kubectl -n "$NAMESPACE" \
    delete deployment "$deployment" --ignore-not-found --wait=true || return 1
  invalidate_deployment_name
  with_loading "Recreating kwatch Deployment" kubectl apply -f "$manifest" || {
    ui_error \
      "❌ Deployment recreation failed." \
      "KwatchConfig and Secrets were not removed."
    return 1
  }
}

verify_runtime_dependencies() {
  if ! kubectl -n "$NAMESPACE" get serviceaccount "$RELEASE" >/dev/null 2>&1; then
    LAST_COMMAND_ERROR="ServiceAccount $NAMESPACE/$RELEASE is missing; the Deployment cannot create Pods."
    return 1
  fi
  if ! kubectl -n "$NAMESPACE" get secret "$CONFIG_SECRET_NAME" >/dev/null 2>&1; then
    LAST_COMMAND_ERROR="Configuration Secret $NAMESPACE/$CONFIG_SECRET_NAME is missing; the Deployment cannot mount config.yaml."
    return 1
  fi
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
  ui_error "Reason: $(compact_reason "$failure")"
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
  ui_error "Reason: $(compact_reason "$failure")"
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
      "🚀 The manager will install kwatch $version on '$(context_label "$SELECTED_CONTEXT")'." \
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
    ui_error "Reason: $(compact_reason "$install_failure")"
    show_failure_diagnostics "Installation" "$install_failure"
    if is_injected_admission_failure "$install_failure"; then
      if repair_injected_hostpath "$install_failure"; then
        record_state complete "$version" "installation repaired after injector opt-out"
        FRESH_INSTALL=false
        configure_after_install
        return 0
      fi
      install_failure="${LAST_COMMAND_ERROR:-$install_failure}"
    elif self_check_rbac_missing && repair_self_check_rbac; then
      record_state complete "$version" "installation repaired after granting the readiness permission"
      FRESH_INSTALL=false
      configure_after_install
      return 0
    elif [ -n "$(failed_components "$(workload_selector)")" ] &&
      repair_component_from_menu; then
      record_state complete "$version" "installation repaired after disabling a failed component"
      FRESH_INSTALL=false
      configure_after_install
      return 0
    elif is_scheduling_failure "$install_failure"; then
      if repair_scheduling; then
        record_state complete "$version" "installation repaired after adding tolerations"
        FRESH_INSTALL=false
        configure_after_install
        return 0
      fi
      install_failure="${LAST_COMMAND_ERROR:-$install_failure}"
    elif failure_is_retryable "$install_failure"; then
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
  local version upgrade_failure="" change_confirmed="${1:-false}" allow_same=false
  confirm_resume
  # Repairing an unhealthy installation may mean re-applying the release it is
  # already on, which is often the newest one available.
  if [ "$INSTALL_STATE" = broken ]; then
    allow_same=true
  fi
  if [ -n "$INSTALL_VERSION" ]; then
    version=$(select_upgrade_version "$INSTALL_VERSION" "$allow_same") || {
      # 1 means the manager already explained why there is nothing to do.
      [ "$?" -eq 2 ] && ui_info "↩️ Upgrade cancelled; nothing was changed."
      return 0
    }
  elif ! version=$(select_modern_release_version); then
    ui_info "↩️ No release was selected; nothing was changed."
    return 0
  fi
  maybe_load_catalog "$version" ||
    die "release catalogs are unavailable; upgrade cannot continue"
  if [ "$change_confirmed" != true ]; then
    confirm_change \
      "⬆️ The manager will upgrade kwatch to $version on '$(context_label "$SELECTED_CONTEXT")'." \
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
    ui_error "Reason: $(compact_reason "$upgrade_failure")"
    show_failure_diagnostics "Upgrade" "$upgrade_failure"
    if [ -n "$(failed_components "$(workload_selector)")" ] &&
      repair_component_from_menu; then
      record_state complete "$version" "upgrade repaired after disabling a failed component"
      return 0
    fi
    if is_scheduling_failure "$upgrade_failure" && repair_scheduling; then
      record_state complete "$version" "upgrade repaired after adding tolerations"
      return 0
    fi
    if is_injected_admission_failure "$upgrade_failure"; then
      if repair_injected_hostpath "$upgrade_failure"; then
        record_state complete "$version" "upgrade repaired after injector opt-out"
        ui_success "✅ kwatch upgraded successfully after the repair."
        return 0
      fi
      upgrade_failure="${LAST_COMMAND_ERROR:-$upgrade_failure}"
    elif failure_is_retryable "$upgrade_failure"; then
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
  confirmation=$(ask "Type uninstall to continue" "") || exit_expected
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
  ui_screen "not installed"
  ui_info "No running kwatch installation was found."
  if stale_resources_present; then
    ui_info "Existing kwatch configuration resources were found, but no" \
      "kwatch workload is running; they are not treated as an installation."
    ui_info \
      "Settings are preserved where possible; provider setup starts fresh."
  fi
  local choice
  if choice=$(ui_select 0 "🚀 Install kwatch" "🚪 Exit"); then
    case "$choice" in
      0) install_flow; return ;;
    esac
  fi
  MENU_EXIT=true
}

show_legacy_menu() {
  ui_screen "legacy release"
  ui_warn "kwatch $INSTALL_VERSION predates the guided catalogs."
  ui_detail "This release predates the guided configuration catalogs."
  ui_detail "Configuration editing is unavailable until it is replaced."
  local choice
  if choice=$(ui_select 1 \
    "🔁 Uninstall legacy kwatch and fresh-install" \
    "📊 View status" \
    "📜 View recent logs" \
    "🧹 Uninstall kwatch" \
    "🚪 Exit"); then
    case "$choice" in
      0) legacy_reinstall_flow; return ;;
      1) status_flow; return ;;
      2) logs_flow; return ;;
      3) uninstall_flow; return ;;
    esac
  fi
  MENU_EXIT=true
}

show_supported_menu() {
  ui_screen "ready"
  local choice
  local -a actions=() labels=()
  actions+=(status logs upgrade providers settings capabilities)
  labels+=(
    "📊 View status"
    "📜 View recent logs"
    "⬆️  Upgrade kwatch"
    "🔌 Edit notification providers"
    "⚙️  Edit settings"
    "🧩 View capabilities"
  )
  # Restoring is meaningless with nothing to restore from.
  if [ -n "$(config_backups)" ]; then
    actions+=(restore)
    labels+=("♻️  Restore a previous configuration")
  fi
  actions+=(uninstall exit)
  labels+=("🧹 Uninstall kwatch" "🚪 Exit")
  if ! choice=$(ui_select 0 "${labels[@]}"); then
    MENU_EXIT=true
    return
  fi
  case "${actions[$choice]}" in
    status) status_flow ;;
    logs) logs_flow ;;
    upgrade) upgrade_flow ;;
    providers)
      require_catalog_for "provider editing"
      configure_alert_flow
      ;;
    settings)
      require_catalog_for "settings editing"
      configure_flow
      ;;
    capabilities)
      require_catalog_for "capabilities"
      features_flow
      ;;
    restore) restore_flow ;;
    uninstall) uninstall_flow ;;
    *) MENU_EXIT=true ;;
  esac
}

show_broken_menu() {
  local choice
  local -a actions=() labels=()
  ui_screen "needs attention"
  ui_kv "📦" "Deployment" "${INSTALL_DEPLOYMENT:-unknown}"
  ui_kv "🏷️" "Version" "${INSTALL_VERSION:-unknown}"
  ui_kv "❗" "Reason" "$INSTALL_REASON"
  printf '\n' >&2
  show_unready_pods "$(workload_selector)" || true
  # When a component is the cause, offer that repair first: upgrading to the
  # same release cannot clear a component that fails to initialise.
  if [ -n "$(failed_components "$(workload_selector)")" ]; then
    actions+=(component)
    labels+=("🩺 Disable the component that will not start")
  fi
  if self_check_rbac_missing; then
    actions+=(selfcheck)
    labels+=("🔑 Grant the permission the readiness check asks for")
  fi
  actions+=(status logs upgrade settings providers uninstall exit)
  labels+=(
    "📊 View status"
    "📜 View recent logs"
    "🛠️  Repair by upgrading kwatch"
    "⚙️  Edit settings"
    "🔌 Edit notification providers"
    "🧹 Uninstall kwatch"
    "🚪 Exit"
  )
  # A detected repair is worth landing on; otherwise start on a read-only entry
  # rather than on something that changes the cluster.
  if ! choice=$(ui_select 0 "${labels[@]}"); then
    MENU_EXIT=true
    return
  fi
  case "${actions[$choice]}" in
    component) repair_component_from_menu ;;
    selfcheck) repair_self_check_rbac || true ;;
    upgrade)
      if confirm_repair \
        "repair kwatch by upgrading it" \
        "This will let you choose a release, then update the Deployment and roll back if the rollout fails."; then
        upgrade_flow true
      else
        ui_info "↩️ Repair cancelled; no changes were made."
      fi
      ;;
    status) status_flow ;;
    logs) logs_flow ;;
    settings)
      require_catalog_for "settings editing"
      configure_flow
      ;;
    providers)
      require_catalog_for "provider editing"
      configure_alert_flow
      ;;
    uninstall) uninstall_flow ;;
    *) MENU_EXIT=true ;;
  esac
}

# One failing component is the common case; more than one is offered as a list.
repair_component_from_menu() {
  local selector choice
  local -a components=()
  selector=$(workload_selector)
  while IFS= read -r choice; do
    [ -n "$choice" ] && components+=("$choice")
  done < <(failed_components "$selector")
  if [ "${#components[@]}" -eq 0 ]; then
    ui_info "ℹ️ Every component started; readiness is failing for another reason."
    return 0
  fi
  if [ "${#components[@]}" -eq 1 ]; then
    repair_failed_component "${components[0]}" || true
    return 0
  fi
  components+=("↩️  Back")
  choice=$(ui_select 0 "${components[@]}") || return 0
  [ "$choice" -lt $((${#components[@]} - 1)) ] || return 0
  repair_failed_component "${components[$choice]}" || true
}

# kwatch gates its readiness on every component starting cleanly, so one
# optional monitor that fails to initialise leaves the Pod Running but never
# Ready. The component logs the failure on startup, which is the only signal
# available from outside the cluster.
#
# Each entry maps the component name kwatch reports to the setting that turns it
# off, so the manager can offer the same repair it offers for injectors.
component_setting() {
  case "$1" in
    control-plane) printf '%s' "controlPlaneMonitor.enabled" ;;
    status|network-graph|storage-graph) printf '%s' "clusterResourceMonitor.enabled" ;;
    runtime-metrics) printf '%s' "runtimeMetricsMonitor.enabled" ;;
    *) return 1 ;;
  esac
}

# Matched against the message text rather than parsed out of it: the same
# component is reported as "create", "initialize" and "create rest config for",
# and the component name in the message ("generic status monitor") is not the
# name kwatch reports it under ("status").
# Reading 400 log lines is asked for twice on the attention screen -- once to
# decide whether to offer the repair, once to carry it out. Cache it for the
# life of one menu render, alongside the other workload lookups.
failed_components() {
  local selector="$1" file="" result
  [ -n "$SESSION_CACHE_DIR" ] && file="$SESSION_CACHE_DIR/failed-components"
  if [ -n "$file" ] && [ -f "$file" ]; then
    cat "$file"
    return 0
  fi
  result=$(failed_components_uncached "$selector")
  if [ -n "$file" ]; then
    printf '%s' "$result" >"$file" 2>/dev/null || true
  fi
  printf '%s' "$result"
  [ -n "$result" ] && printf '\n'
  return 0
}

failed_components_uncached() {
  local selector="$1" line
  while IFS= read -r line; do
    case "$line" in
      *"control-plane monitor"*) printf 'control-plane\n' ;;
      *"status monitor"*) printf 'status\n' ;;
      *"network graph monitor"*) printf 'network-graph\n' ;;
      *"storage graph monitor"*) printf 'storage-graph\n' ;;
      *"runtime metrics monitor"*) printf 'runtime-metrics\n' ;;
    esac
  done < <(kubectl -n "$NAMESPACE" logs -l "$selector" --tail=400 2>/dev/null |
    grep -F 'failed to' || true) | sort -u
}

component_failure_detail() {
  local component="$1" selector="$2"
  kubectl -n "$NAMESPACE" logs -l "$selector" --tail=400 2>/dev/null |
    grep -F "$component" | grep -F 'failed to' | tail -1 || true
}

# Offer to switch off the component that cannot start. The alternative is a Pod
# that never becomes Ready, so the trade is stated plainly and confirmed.
repair_failed_component() {
  local component="$1" setting details
  setting=$(component_setting "$component") || {
    ui_warn "⚠️ The $component component failed to start and has no setting to disable it."
    return 1
  }
  details="kwatch reports every component healthy or it never becomes Ready, so"
  details+=" the $component failure keeps the Pod out of service. This sets"
  details+=" $setting=false in the KwatchConfig resource and restarts kwatch."
  details+=" Only that component stops; every other monitor keeps running."
  confirm_repair "disable the $component component" "$details" || return 1
  check_access patch kwatchconfigs namespace
  if ! patch_config_value "$setting" boolean false; then
    return 1
  fi
  restart_kwatch || return 1
  ui_success "✅ $component disabled. Re-enable it with Edit settings once it is fixed upstream."
  return 0
}

workload_selector() {
  local file="" selector
  [ -n "$SESSION_CACHE_DIR" ] && file="$SESSION_CACHE_DIR/workload-selector"
  if [ -n "$file" ] && [ -f "$file" ]; then
    cat "$file"
    return 0
  fi
  selector=$(workload_selector_uncached)
  if [ -n "$file" ]; then
    printf '%s' "$selector" >"$file" 2>/dev/null || true
  fi
  printf '%s' "$selector"
}

workload_selector_uncached() {
  local deployment pod_instance
  deployment=$(deployment_name || true)
  if [ -n "$deployment" ]; then
    pod_instance=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
      -o 'jsonpath={.spec.template.metadata.labels.app\.kubernetes\.io/instance}' \
      2>/dev/null || true)
  fi
  if [ -n "${pod_instance:-}" ]; then
    printf 'app.kubernetes.io/instance=%s' "$pod_instance"
  else
    printf 'app=kwatch'
  fi
}

# A Pod that is not ready is the usual reason someone opens the manager, so show
# the container's own explanation instead of leaving them to run kubectl.
show_unready_pods() {
  local selector="$1" pod ready waiting terminated scheduling logs line shown=false
  local phase probe component
  while IFS=' ' read -r pod ready; do
    [ -n "$pod" ] || continue
    [ "$ready" = true ] && continue
    shown=true
    waiting=$(kubectl -n "$NAMESPACE" get pod "$pod" \
      -o 'jsonpath={.status.containerStatuses[0].state.waiting.reason}' \
      2>/dev/null || true)
    terminated=$(kubectl -n "$NAMESPACE" get pod "$pod" \
      -o 'jsonpath={.status.containerStatuses[0].lastState.terminated.reason}' \
      2>/dev/null || true)
    # A Pod that never started a container -- Pending on a full or scaling
    # cluster -- has no container state at all, so fall back to its phase and
    # the scheduler's own explanation.
    scheduling=""
    probe=""
    if [ -z "$waiting" ]; then
      phase=$(kubectl -n "$NAMESPACE" get pod "$pod" \
        -o 'jsonpath={.status.phase}' 2>/dev/null || true)
      if [ "$phase" = Running ]; then
        # "not ready: Running" says nothing. A container that started and stayed
        # up is failing its readiness probe, and the kubelet records why.
        waiting="running, but failing its readiness probe"
        probe=$(kubectl -n "$NAMESPACE" get events \
          --field-selector=involvedObject.name="$pod",reason=Unhealthy \
          -o 'jsonpath={.items[-1:].message}' 2>/dev/null || true)
      else
        waiting="$phase"
        scheduling=$(kubectl -n "$NAMESPACE" get pod "$pod" \
          -o 'jsonpath={.status.conditions[?(@.type=="PodScheduled")].message}' \
          2>/dev/null || true)
      fi
    fi
    ui_warn "$(ui_dot bad) Pod $pod is not ready: ${waiting:-unknown}${terminated:+ (last exit: $terminated)}"
    [ -n "$scheduling" ] && ui_detail "   $(compact_reason "$scheduling")"
    [ -n "$probe" ] && ui_detail "   $(compact_reason "$probe")"
    # kwatch holds readiness down until every component starts, so name the one
    # that did not rather than leaving a healthy-looking process unexplained.
    while IFS= read -r component; do
      [ -n "$component" ] || continue
      ui_detail "   ⚠️ component $component failed to start:"
      ui_detail "      $(compact_reason "$(component_failure_detail "$component" "$selector")")"
    done < <(failed_components "$selector")
    logs=$(kubectl -n "$NAMESPACE" logs "$pod" --tail=3 --previous 2>/dev/null ||
      kubectl -n "$NAMESPACE" logs "$pod" --tail=3 2>/dev/null || true)
    [ -n "$logs" ] || continue
    ui_detail "   Last log lines:"
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      printf '   %s\n' "$(compact_reason "$line")"
    done <<< "$logs"
  done < <(kubectl -n "$NAMESPACE" get pods -l "$selector" \
    -o 'jsonpath={range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[0].ready}{"\n"}{end}' \
    2>/dev/null || true)
  [ "$shown" = true ] && return 0
  return 1
}

status_flow() {
  local deployment version selector state phase state_version message ready desired
  ui_screen "status"
  ui_kv "📍" "Context" "$(context_label "$SELECTED_CONTEXT")"
  ui_kv "📦" "Namespace" "$NAMESPACE"
  version=$(installed_version || true)
  ui_kv "🏷️" "Version" "${version:-unknown}"
  if [ "$CATALOG_SOURCE" != unavailable ]; then
    ui_kv "📚" "Catalog" "$CATALOG_SOURCE"
  fi
  printf '\n' >&2
  deployment=$(deployment_name || true)
  if [ -n "$deployment" ]; then
    ready=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
      -o 'jsonpath={.status.readyReplicas}' 2>/dev/null || true)
    desired=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
      -o 'jsonpath={.spec.replicas}' 2>/dev/null || true)
    [[ "$ready" =~ ^[0-9]+$ ]] || ready=0
    [[ "$desired" =~ ^[0-9]+$ ]] || desired=0
    if [ "$ready" -gt 0 ] && [ "$ready" -eq "$desired" ]; then
      printf '  %s  %sHealthy%s %s%s/%s replicas ready%s\n' "$(ui_dot ok)" \
        "$UI_BOLD$UI_GREEN" "$UI_RESET" "$UI_DIM" "$ready" "$desired" "$UI_RESET" >&2
    else
      printf '  %s  %sUnhealthy%s %s%s/%s replicas ready%s\n' "$(ui_dot bad)" \
        "$UI_BOLD$UI_RED" "$UI_RESET" "$UI_DIM" "$ready" "$desired" "$UI_RESET" >&2
    fi
    ui_rule
    kubectl -n "$NAMESPACE" get deployment "$deployment" 2>/dev/null |
      sed 's/^/  /' || true
    selector=$(workload_selector)
    kubectl -n "$NAMESPACE" get pods -l "$selector" 2>/dev/null |
      sed 's/^/  /' || true
    show_unready_pods "$selector" || true
  else
    ui_warn "⚠️ No kwatch Deployment was found."
  fi
  state=$(kubectl -n "$NAMESPACE" get configmap "$STATE_CONFIGMAP_NAME" \
    -o 'jsonpath={.data.phase}{"|"}{.data.version}{"|"}{.data.message}' \
    2>/dev/null || true)
  if [ -n "$state" ]; then
    IFS='|' read -r phase state_version message <<< "$state"
    ui_detail "🧭 Manager state: ${phase:-unknown}${state_version:+ ($state_version)}${message:+ — $message}"
  else
    ui_detail "🧭 Manager state: not available"
  fi
  ui_pause
}

logs_flow() {
  local selector pod choice lines
  ui_screen "logs"
  selector=$(workload_selector)
  pod=$(kubectl -n "$NAMESPACE" get pods -l "$selector" \
    -o 'jsonpath={.items[0].metadata.name}' 2>/dev/null || true)
  if [ -z "$pod" ]; then
    ui_warn "⚠️ No kwatch Pod was found in namespace $NAMESPACE."
    return 0
  fi
  ui_detail "Pod: $NAMESPACE/$pod"
  choice=$(ui_select 0 "Last 50 lines" "Last 200 lines" "Last 1000 lines" \
    "↩️  Back") || return 0
  case "$choice" in
    0) lines=50 ;;
    1) lines=200 ;;
    2) lines=1000 ;;
    *) return 0 ;;
  esac
  ui_rule
  # Logs can carry a webhook URL or a token echoed back by a provider, so they
  # get the same redaction as every other diagnostic the manager prints.
  kubectl -n "$NAMESPACE" logs "$pod" --tail="$lines" 2>&1 |
    sed -E 's#https?://[^ ]+#<url-redacted>#g;
      s/((token|password|secret)[=:])[[:space:]]*[^[:space:]]+/\1<redacted>/Ig' ||
    true
  ui_rule
  ui_pause
}

config_backups() {
  kubectl -n "$NAMESPACE" get secrets \
    -o "jsonpath={range .items[?(@.metadata.labels.app\\.kubernetes\\.io/managed-by=='kwatch.sh')]}{.metadata.name}{\"\n\"}{end}" \
    2>/dev/null | grep "^${RELEASE}-config-[0-9]" | sort -r || true
}

# Every upgrade writes a backup Secret and nothing removed them, so a
# long-lived installation accumulated one per upgrade for ever.
prune_config_backups() {
  local keep="${KWATCH_BACKUP_KEEP:-5}" name index=0
  [[ "$keep" =~ ^[0-9]+$ ]] || keep=5
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    index=$((index + 1))
    [ "$index" -gt "$keep" ] || continue
    kubectl -n "$NAMESPACE" delete secret "$name" --ignore-not-found \
      >/dev/null 2>&1 || true
  done < <(config_backups)
}

# Restoring used to be reachable only as the automatic rollback after a failed
# upgrade, so an unwanted but successful configuration change could not be
# undone from the manager.
restore_flow() {
  local name created choice
  local -a names=() labels=()
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    created=$(kubectl -n "$NAMESPACE" get secret "$name" \
      -o 'jsonpath={.metadata.creationTimestamp}' 2>/dev/null || true)
    names+=("$name")
    labels+=("$name  ${UI_DIM}${created:-unknown}${UI_RESET}")
  done < <(config_backups)
  if [ "${#names[@]}" -eq 0 ]; then
    ui_warn "⚠️ No configuration backups were found in namespace $NAMESPACE."
    ui_detail "Backups are created automatically before each upgrade."
    return 0
  fi
  ui_heading "♻️   Restore a previous configuration"
  ui_detail "Newest first. The current configuration is replaced, then kwatch restarts."
  labels+=("↩️  Back")
  choice=$(ui_select 0 "${labels[@]}") || choice="${#names[@]}"
  if [ "$choice" -ge "${#names[@]}" ]; then
    ui_info "↩️ Restore cancelled; nothing was changed."
    return 0
  fi
  confirm_repair \
    "restore the configuration saved in ${names[$choice]}" \
    "The current KwatchConfig is replaced by the saved one and kwatch is restarted. Notification Secrets are not changed." ||
    {
      ui_info "↩️ Restore cancelled; nothing was changed."
      return 0
    }
  BACKUP_NAME="${names[$choice]}"
  restore_backup
  ui_success "✅ Configuration restored from ${names[$choice]}."
}

# Deleting is a sequence across namespaced and cluster-scoped resources. Check
# every permission before the first deletion: `check_access` calls die, so a
# missing one used to abort mid-way and leave orphaned cluster RBAC behind.
preflight_uninstall_access() {
  check_access delete deployments namespace
  check_access delete services namespace
  check_access delete serviceaccounts namespace
  check_access delete roles namespace
  check_access delete rolebindings namespace
  check_access delete secrets namespace
  check_access delete clusterrolebindings
  check_access delete clusterroles
}

# Everything the manager itself created, beyond the workload: the state marker,
# the cached catalogs, the configuration resource, and the upgrade backups.
purge_manager_data() {
  local name
  for name in "$STATE_CONFIGMAP_NAME" "$CATALOG_CACHE_NAME" \
    "$FEATURE_CATALOG_CACHE_NAME" "$PROVIDER_CATALOG_CACHE_NAME"; do
    [ -n "$name" ] || continue
    kubectl -n "$NAMESPACE" delete configmap "$name" --ignore-not-found \
      >/dev/null 2>&1 || true
  done
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    kubectl -n "$NAMESPACE" delete secret "$name" --ignore-not-found \
      >/dev/null 2>&1 || true
  done < <(config_backups)
  kubectl -n "$NAMESPACE" delete kwatchconfig "$RELEASE" --ignore-not-found \
    >/dev/null 2>&1 || true
}

uninstall_flow() {
  local confirm secret_owner scope purge=false
  adopt_existing_config_secret
  ui_heading "🧹  Uninstall kwatch"
  scope=$(ui_select 0 \
    "🧹 Remove the workload, keep configuration and backups" \
    "🔥 Remove everything the manager created" \
    "↩️  Cancel") || { ui_warn "↩️ Cancelled."; return; }
  case "$scope" in
    0) ;;
    1) purge=true ;;
    *) ui_warn "↩️ Cancelled."; return ;;
  esac
  if [ "$purge" = true ]; then
    ui_warn \
      "⚠️ This removes the workload, the configuration resource, every configuration backup, and the cached catalogs."
    ui_detail "The namespace and the CRD are preserved."
  else
    ui_warn \
      "⚠️ This removes the kwatch workload and its manager-owned configuration Secret."
    ui_detail "KwatchConfig, backups, namespace, and CRD are preserved."
  fi
  confirm=$(ask "Type uninstall to remove kwatch" "") || exit_expected
  [ "$confirm" = uninstall ] || { ui_warn "↩️ Cancelled."; return; }
  preflight_uninstall_access
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
  if [ "$purge" = true ]; then
    with_loading "Removing manager data" purge_manager_data
  fi
  clear_managed_namespace_labels
  if [ "$purge" = true ]; then
    ui_success \
      "✅ kwatch removed, along with its configuration, backups, and cached catalogs. The namespace and CRD remain."
  else
    ui_success \
      "✅ kwatch workload removed. KwatchConfig, backups, namespace, and CRD remain."
  fi
}

usage() {
  cat <<'USAGE'
🧭 Usage: kwatch.sh

Interactive kubectl manager with operational security checks.
Run it with no arguments; every action is chosen from the menu.

  --help, -h        Show this help and exit
  --version, -v     Show the manager catalog version and exit

Environment:
  KWATCH_CONTEXT                   kubeconfig context to manage; skips the
                                   cluster picker
  KWATCH_NAMESPACE                 Namespace to manage (default: kwatch)
  KWATCH_RELEASE                   Release name to manage (default: kwatch)
  KWATCH_PLAIN_UI=true             Disable spinners and colour
  KWATCH_ALLOW_NAMESPACE_LABELS=true
                                   Allow restricted Pod Security labels on a
                                   namespace the manager did not create
  KWATCH_SKIP_ADMISSION_PREFLIGHT=true
                                   Skip the admission-injection dry run
  KWATCH_ROLLOUT_TIMEOUT           How long to wait for a rollout
                                   (default: 5m)
  KWATCH_BACKUP_KEEP               Configuration backups to retain
                                   (default: 5)
USAGE
}

# Loading a release catalog is a precondition for every configuration screen,
# so keep the failure message in one place.
require_catalog_for() {
  local purpose="$1"
  maybe_load_catalog "$INSTALL_VERSION" ||
    die "release catalogs are unavailable; $purpose cannot continue"
  migration_notice
}

# Return to the menu after each action instead of ending the session, so a
# status check or a settings edit does not cost a fresh run and another context
# selection. The installation is reassessed every time, because the previous
# action usually changed it.
interactive_session() {
  while true; do
    MENU_EXIT=false
    case "$INSTALL_STATE" in
      absent) show_absent_menu ;;
      legacy) show_legacy_menu ;;
      supported) show_supported_menu ;;
      broken) show_broken_menu ;;
      *) die "could not assess the kwatch installation" ;;
    esac
    [ "$MENU_EXIT" = true ] && return 0
    [ -t 0 ] || return 0
    # The action just taken usually changed the workload; re-resolve it.
    invalidate_deployment_name
    assess_installation
  done
}

main() {
  local action="${1:-}"
  case "$action" in
    --help|-h) usage; exit 0 ;;
    --version|-v)
      echo "🏷️ kwatch manager catalog $CATALOG_VERSION"
      exit 0
      ;;
    "") ;;
    *) die "kwatch.sh is interactive; run it without an action argument" ;;
  esac
  require_tools
  SESSION_CACHE_DIR=$(mktemp -d 2>/dev/null || true)
  ui_banner
  select_context
  with_loading "Checking Kubernetes cluster" kubectl cluster-info >/dev/null ||
    die "cannot reach the Kubernetes cluster: $(compact_reason "${LAST_COMMAND_ERROR:-no diagnostic was returned}")"
  check_cluster_version
  assess_installation
  interactive_session
}

if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
