#!/usr/bin/env bash
set -euo pipefail

BASE_URL="https://raw.githubusercontent.com/abahmed/kwatch"
RELEASES_URL="https://api.github.com/repos/abahmed/kwatch/releases/latest"
RELEASES_LIST_URL="https://api.github.com/repos/abahmed/kwatch/releases?per_page=30"
RELEASE_DOWNLOAD_URL="https://github.com/abahmed/kwatch/releases/download"
DEFAULT_NAMESPACE="kwatch"
DEFAULT_RELEASE="kwatch"
CATALOG_VERSION=1
FEATURE_CATALOG_VERSION=1
PROVIDER_CATALOG_VERSION=1
SUPPORTED_CATALOG_VERSION=1
SUPPORTED_FEATURE_CATALOG_VERSIONS="1 2"
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
INJECTOR_OPT_OUT_PROFILES=()
INJECTOR_OPT_OUT_PATCH_AFTER=false
MENU_EXIT=false
# Set by a menu action that only looked at the installation, so the session
# does not re-assess a workload nothing touched.
MENU_READ_ONLY=false
# True once the settings flow has written something, so leaving it untouched
# costs nothing on the way back.
CONFIG_FLOW_CHANGED=false
UI_SELECT_HINTS=()
UI_SELECT_PENDING_HINTS=()
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
# The data volume: "pvc" (the release default, a ReadWriteOnce claim on the
# default StorageClass) or "emptydir" (no StorageClass needed; the state is
# lost when the Pod moves). KWATCH_STORAGE picks one without a prompt,
# KWATCH_STORAGE_CLASS names the StorageClass for the claim and
# KWATCH_STORAGE_SIZE sizes the volume.
STORAGE_MODE="${KWATCH_STORAGE:-}"
STORAGE_CLASS="${KWATCH_STORAGE_CLASS:-}"
STORAGE_SIZE="${KWATCH_STORAGE_SIZE:-2Gi}"
# The first release that keeps its state in one file on the data volume
# instead of in ConfigMaps. Upgrading across it rebuilds the state.
VOLUME_STATE_VERSION="v1.0.0-rc.11"
# The storage driver's topology label chosen before the apply, recorded on
# the Deployment once it exists so upgrades keep the placement.
PLANNED_STORAGE_KEY=""
# Deployment resources and placement are the operator's, not the release's: the
# manifest is re-downloaded on every run, so a hand-edited Deployment would be
# reverted by the next upgrade. Recording the choices on the workload itself --
# rather than in a file beside the script -- keeps them with the cluster they
# belong to, so any operator running the manager against it sees and keeps the
# same settings. Only what was set explicitly is recorded, which leaves the
# release free to change the defaults for everything else.
DEPLOYMENT_OVERRIDES_ANNOTATION="kwatch.sh/deployment-overrides"
# What the key was called before it was named after the object it edits. Read,
# never written, so an installation recorded under the old name keeps its
# sizing instead of quietly reverting to the release defaults on the next
# upgrade. Retired once it is read: writing moves the record to the new name.
LEGACY_OVERRIDES_ANNOTATION="kwatch.sh/pod-overrides"
DEPLOYMENT_OVERRIDES=""
# Where the values in DEPLOYMENT_OVERRIDES came from: the running Deployment, or the
# record that survived an uninstall. Worth telling the operator apart, because
# the second case restores sizing they may have forgotten setting.
DEPLOYMENT_OVERRIDES_SOURCE=""
# True when a record was found under the name used before the rename, so the
# save that follows knows there is an old copy to retire.
LEGACY_OVERRIDES_IN_USE=false



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

# The tab title is the only place the step in progress is visible while the
# window sits in the background, and a cluster name in the tab is what stops a
# second window being mistaken for this one. OSC 0 sets the window and tab title on xterm, iTerm2,
# Terminal.app, kitty, Alacritty, WezTerm and tmux; OSC 22/23 push the
# terminal's own title and pop it back on exit, so the shell's prompt title
# returns. Terminals that do not implement them ignore both silently. Skipped
# when stderr is not a terminal, and with KWATCH_NO_TITLE for a terminal that
# prints the escape instead of acting on it.
UI_TITLE=false
UI_TITLE_BASE="kwatch"
if [ -t 2 ] && [ -z "${KWATCH_NO_TITLE:-}" ]; then
  case "${TERM:-}" in
    ""|dumb|linux) ;;
    *) UI_TITLE=true ;;
  esac
fi

ui_set_title() {
  [ "$UI_TITLE" = true ] || return 0
  printf '\033]0;%s\007' "$*" >&2
}

# Name the cluster in the tab for the whole session, and the step while one is
# running.
ui_title_step() {
  if [ -n "${1:-}" ]; then
    ui_set_title "$UI_TITLE_BASE — $1"
  else
    ui_set_title "$UI_TITLE_BASE"
  fi
}

ui_title_push() {
  [ "$UI_TITLE" = true ] || return 0
  printf '\033[22;0t' >&2
}

ui_title_pop() {
  [ "$UI_TITLE" = true ] || return 0
  printf '\033[23;0t' >&2
}

# Retires an unfinished busy line before anything is printed over it. Clearing
# an already-empty line is a no-op, so a flag left set by a subshell costs
# nothing.
UI_BUSY_ACTIVE=false
ui_busy_clear() {
  [ "$UI_BUSY_ACTIVE" = true ] || return 0
  UI_BUSY_ACTIVE=false
  printf '%s' "$UI_CLEAR_LINE" >&2
  return 0
}

ui_info() { ui_busy_clear; printf '%s%s%s\n' "$UI_BRAND" "$*" "$UI_RESET" >&2; }
ui_success() { ui_busy_clear; printf '%s%s%s\n' "$UI_GREEN" "$*" "$UI_RESET" >&2; }
ui_warn() { ui_busy_clear; printf '%s%s%s\n' "$UI_YELLOW" "$*" "$UI_RESET" >&2; }
ui_error() { ui_busy_clear; printf '%s%s%s\n' "$UI_RED" "$*" "$UI_RESET" >&2; }
back_hint() { printf '%s(↩️ type back)%s' "$UI_DIM" "$UI_RESET"; }
ui_heading() {
  ui_busy_clear
  printf '\n%s%s%s\n' "$UI_BOLD$UI_BRAND" "$*" "$UI_RESET" >&2
}
ui_detail() { ui_busy_clear; printf '%s%s%s\n' "$UI_DIM" "$*" "$UI_RESET" >&2; }

# A message printed just before a screen is redrawn is wiped by the redraw --
# the result of the change you just made would flash past. Hold it, and let the
# redrawn screen print it at the top.
FLOW_NOTICE_KIND=""
FLOW_NOTICE_TEXT=""
flow_notice() {
  FLOW_NOTICE_KIND="$1"
  shift
  FLOW_NOTICE_TEXT="$*"
}

show_flow_notice() {
  [ -n "$FLOW_NOTICE_TEXT" ] || return 0
  case "$FLOW_NOTICE_KIND" in
    success) ui_success "$FLOW_NOTICE_TEXT" ;;
    warn) ui_warn "$FLOW_NOTICE_TEXT" ;;
    error) ui_error "$FLOW_NOTICE_TEXT" ;;
    *) ui_info "$FLOW_NOTICE_TEXT" ;;
  esac
  FLOW_NOTICE_KIND=""
  FLOW_NOTICE_TEXT=""
  printf '\n' >&2
  return 0
}

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
  local current="$1" top="$2" visible="$3" filter="$4" columns="${5:-80}"
  local total row index hint
  local detail=""
  total=${#UI_SELECT_MATCHES[@]}
  # The short-list keymap includes j/k and 1-9; undocumented shortcuts are the
  # same as no shortcuts.
  hint="  ↑/↓ move · 1-9 pick · ⏎ choose · esc back"
  [ "$total" -gt "$visible" ] &&
    hint="  ↑/↓ move · ⏎ choose · type to filter · esc back"
  # The counter moves up here when the rows carry their own detail line, so the
  # window keeps the same height either way.
  if [ "$total" -gt "$visible" ] && [ "${#UI_SELECT_HINTS[@]}" -gt 0 ]; then
    hint="$hint · $((current + 1)) of $total"
  fi
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
  # A row is one line, so a long description would be truncated into it. Give
  # the highlighted row's full text the line below the window instead, where
  # there is room for it.
  if [ "$total" -gt 0 ] && [ "${#UI_SELECT_HINTS[@]}" -gt 0 ]; then
    detail="${UI_SELECT_HINTS[${UI_SELECT_MATCHES[$current]}]:-}"
  fi
  if [ "$total" -eq 0 ]; then
    # Filtering to nothing leaves an empty frame; say why rather than looking
    # broken, and keep the filter on screen so it can be edited back.
    printf '%s%s  no matches — backspace to edit the filter%s%s\n' \
      "$UI_CLEAR_LINE" "$UI_YELLOW" "$UI_RESET" "$UI_CLEAR" >&2
  elif [ -n "$detail" ]; then
    printf '%s%s  %s%s%s\n' "$UI_CLEAR_LINE" "$UI_DIM" \
      "$(ui_truncate "$detail" "$((columns - 4))")" "$UI_RESET" \
      "$UI_CLEAR" >&2
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
# A list whose rows carry a caption: the row stays one line, and the
# highlighted row's full text is printed below the window. Captions are passed
# positionally -- <count> labels, then <count> captions -- because ui_select
# runs in a command substitution and a global set by the caller could not be
# cleared again.
ui_select_captioned() {
  local default_index="$1" count="$2" index
  shift 2
  local -a labels=()
  for ((index = 0; index < count; index++)); do
    labels+=("$1")
    shift
  done
  UI_SELECT_PENDING_HINTS=("$@")
  ui_select "$default_index" "${labels[@]}"
}

ui_select() {
  local default_index="$1"; shift
  local count="$#" current top visible rows key rest answer index filter=""
  local total columns
  [ "$count" -gt 0 ] || return 1
  UI_SELECT_LABELS=("$@")
  # Captions arrive through ui_select_captioned, which sets them inside this
  # same command substitution; a plain ui_select call never sees any.
  UI_SELECT_HINTS=("${UI_SELECT_PENDING_HINTS[@]-}")
  if [ "${#UI_SELECT_HINTS[@]}" -ne "$count" ]; then
    UI_SELECT_HINTS=()
  fi
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
  # tput is a fork, and the render runs on every keystroke: measure the terminal
  # once per list instead of once per redraw.
  columns=$(ui_columns)
  visible=$((rows - 8))
  [ "$visible" -lt 5 ] && visible=5
  [ "$visible" -gt "$count" ] && visible="$count"
  ui_busy_clear
  ui_select_filter ""
  current="$default_index"
  [ "$current" -ge 0 ] && [ "$current" -lt "$count" ] || current=0
  top=0
  [ "$current" -ge "$visible" ] && top=$((current - visible + 1))
  printf '\n%s' "$UI_HIDE_CURSOR" >&2
  ui_select_render "$current" "$top" "$visible" "$filter" "$columns"
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
    ui_select_render "$current" "$top" "$visible" "$filter" "$columns"
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

# with_loading runs its command in a background subshell, so a step that sets
# globals -- assess_installation, the settings gather -- cannot use it and used
# to leave a cleared screen with nothing on it while kubectl worked. Print a
# line, do the work in this shell, then erase the line.
ui_busy() {
  ui_interactive || return 0
  UI_BUSY_ACTIVE=true
  printf '%s%s⏳ %s…%s' "$UI_CLEAR_LINE" "$UI_DIM" "$*" "$UI_RESET" >&2
}

ui_busy_done() {
  ui_interactive || return 0
  UI_BUSY_ACTIVE=false
  printf '%s' "$UI_CLEAR_LINE" >&2
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
  ui_title_step "$label"
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
  ui_title_step ""
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
  ui_title_pop
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
  trap 'ui_restore_terminal; ui_title_pop; exit 130' INT
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
  ui_busy_clear
  [ -n "$default" ] && prompt="$prompt [$default]"
  printf '%s%s%s%s: ' "$UI_BOLD" "$UI_CYAN" "$prompt" "$UI_RESET" >&2
  IFS= read -r answer || input_ended
  printf '%s' "${answer:-$default}"
}
# `ask` cannot see Escape: in canonical mode the key is just a byte in the line
# buffer, so it does nothing until Enter is pressed -- which is why "esc back"
# worked in the lists but not at a value prompt. Reading raw keeps Escape live,
# at the cost of doing the line editing here. Printable characters, backspace,
# Ctrl-U and Enter is all a setting value needs.
#
# Prints the answer and returns 0; returns 2 for Escape or a typed "back".
ask_or_back() {
  local prompt="$1" default="${2:-}" buffer="" key rest shown
  if ! ui_interactive; then
    buffer=$(ask "$prompt $(back_hint)" "$default") || exit_expected
    is_back_choice "$buffer" && return 2
    printf '%s' "$buffer"
    return 0
  fi
  ui_busy_clear
  shown="$prompt"
  [ -n "$default" ] && shown="$prompt [$default]"
  printf '%s%s%s%s: ' "$UI_BOLD" "$UI_CYAN" "$shown" "$UI_RESET" >&2
  while true; do
    IFS= read -rsn1 key || { printf '\n' >&2; input_ended; }
    case "$key" in
      $'\x1b')
        # An arrow key arrives as ESC [ A; a bare Escape has nothing after it.
        IFS= read -rsn2 -t "$UI_ESC_TIMEOUT" rest || rest=""
        if [ -z "$rest" ]; then
          printf '\n' >&2
          return 2
        fi
        ;;
      '')
        printf '\n' >&2
        [ -n "$buffer" ] || buffer="$default"
        is_back_choice "$buffer" && return 2
        printf '%s' "$buffer"
        return 0
        ;;
      $'\x7f'|$'\b')
        if [ -n "$buffer" ]; then
          buffer="${buffer%?}"
          printf '\b \b' >&2
        fi
        ;;
      $'\x03')
        printf '\n' >&2
        ui_restore_terminal
        ui_title_pop
        exit 130
        ;;
      $'\x15')
        while [ -n "$buffer" ]; do
          buffer="${buffer%?}"
          printf '\b \b' >&2
        done
        ;;
      *)
        # Stray control bytes would corrupt both the echo and the value; every
        # other byte is passed through, so UTF-8 still arrives intact.
        case "$key" in
          [[:cntrl:]]) ;;
          *) buffer="$buffer$key"; printf '%s' "$key" >&2 ;;
        esac
        ;;
    esac
  done
}

ask_secret() {
  local prompt="$1" answer
  ui_busy_clear
  printf '%s%s%s%s: ' "$UI_BOLD" "$UI_CYAN" "$prompt" "$UI_RESET" >&2
  IFS= read -r -s answer || input_ended
  printf '\n' >&2
  printf '%s' "$answer"
}

# ask_or_back for a value that must not appear on screen. Escape leaves, and
# each keystroke draws a bullet so there is still feedback that it landed.
# Returns 2 for Escape or a typed "back".
ask_secret_or_back() {
  local prompt="$1" buffer="" key rest
  if ! ui_interactive; then
    buffer=$(ask_secret "$prompt $(back_hint)") || exit_expected
    is_back_choice "$buffer" && return 2
    printf '%s' "$buffer"
    return 0
  fi
  ui_busy_clear
  printf '%s%s%s%s: ' "$UI_BOLD" "$UI_CYAN" "$prompt" "$UI_RESET" >&2
  while true; do
    IFS= read -rsn1 key || { printf '\n' >&2; input_ended; }
    case "$key" in
      $'\x1b')
        IFS= read -rsn2 -t "$UI_ESC_TIMEOUT" rest || rest=""
        if [ -z "$rest" ]; then
          printf '\n' >&2
          return 2
        fi
        ;;
      '')
        printf '\n' >&2
        is_back_choice "$buffer" && return 2
        printf '%s' "$buffer"
        return 0
        ;;
      $'\x7f'|$'\b')
        if [ -n "$buffer" ]; then
          buffer="${buffer%?}"
          printf '\b \b' >&2
        fi
        ;;
      $'\x03')
        printf '\n' >&2
        ui_restore_terminal
        ui_title_pop
        exit 130
        ;;
      $'\x15')
        while [ -n "$buffer" ]; do
          buffer="${buffer%?}"
          printf '\b \b' >&2
        done
        ;;
      *)
        case "$key" in
          [[:cntrl:]]) ;;
          *) buffer="$buffer$key"; printf '•' >&2 ;;
        esac
        ;;
    esac
  done
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
    *persistentvolumeclaim*|*unbound*|*storageclass*|*no\ persistent\ volumes*)
      printf '%s' "The state volume claim did not bind: the cluster has no default StorageClass, or none that provisions ReadWriteOnce volumes." ;;
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
    *persistentvolumeclaim*|*unbound*|*storageclass*|*no\ persistent\ volumes*)
      printf '%s' "Mark a default StorageClass, or run the manager with KWATCH_STORAGE_CLASS=<name>, or with KWATCH_STORAGE=emptydir to run without persistent state." ;;
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
    injection_opt_out_collected "$profile" && continue
    printf '%s' "$profile"
    return 0
  done < <(injector_keywords)
  # Nothing in the rejection names a vendor. Count only the injectors not
  # already opted out of, so a second pass can still identify the one that is
  # left; with more than one candidate the manager does not choose.
  while IFS= read -r keyword; do
    [ -n "$keyword" ] || continue
    case "$webhooks" in *"$keyword"*) ;; *) continue ;; esac
    profile=$(provider_profile_for_keyword "$keyword") || continue
    injection_opt_out_collected "$profile" && continue
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

# True when every collected opt-out is already on the workload.
injection_opt_outs_present() {
  local profile
  [ "${#INJECTOR_OPT_OUT_PROFILES[@]}" -gt 0 ] || return 1
  for profile in "${INJECTOR_OPT_OUT_PROFILES[@]-}"; do
    [ -n "$profile" ] || continue
    injection_opt_out_present "$profile" || return 1
  done
  return 0
}

# True when this opt-out was already collected on an earlier pass, which is how
# the probe loop recognises that it has stopped making progress.
injection_opt_out_collected() {
  local wanted="$1" profile
  for profile in "${INJECTOR_OPT_OUT_PROFILES[@]-}"; do
    if [ "$profile" = "$wanted" ]; then
      return 0
    fi
  done
  return 1
}

# The collected opt-outs as pod-template metadata, every line prefixed with a
# newline so an empty set expands to nothing at all. One renderer feeds both the
# probe Pod and the release manifest, which is what makes the probe's verdict
# worth anything: it answers for the exact metadata that will be applied.
opt_out_yaml_lines() {
  local target="$1" indent="$2" profile provider scope key value
  for profile in "${INJECTOR_OPT_OUT_PROFILES[@]-}"; do
    [ -n "$profile" ] || continue
    IFS='|' read -r provider scope key value <<< "$profile"
    [ "$scope" = "$target" ] || continue
    printf '\n%s%s: "%s"' "$indent" "$key" "$value"
  done
}

# The providers collected so far, named for a single readable prompt.
opt_out_provider_list() {
  local profile provider scope key value out=""
  for profile in "${INJECTOR_OPT_OUT_PROFILES[@]-}"; do
    [ -n "$profile" ] || continue
    IFS='|' read -r provider scope key value <<< "$profile"
    if [ -n "$out" ]; then
      out="$out, $provider"
    else
      out="$provider"
    fi
  done
  printf '%s' "$out"
}

# True when the Pod template already declares an annotations block, so a second
# one is not created next to it.
pod_template_has_annotations() {
  awk '
    /^    metadata:$/ { inside = 1; next }
    inside && /^    spec:$/ { exit }
    inside && /^      annotations:$/ { found = 1; exit }
    END { exit (found ? 0 : 1) }
  ' "$1"
}

# Write the collected opt-outs into the release manifest's Pod template, so the
# workload is created already excluded instead of being created, rejected, and
# then patched. Returns non-zero when the manifest is not shaped as expected,
# which sends the caller back to patching after the apply.
inject_opt_out_into_manifest() {
  local manifest="$1" labels annotations rewritten profile provider scope key value
  local has_annotations=false
  labels=$(opt_out_yaml_lines labels '        ')
  annotations=$(opt_out_yaml_lines annotations '        ')
  [ -n "$labels$annotations" ] || return 0
  # Both anchors are unique to the Pod template: the Deployment's own metadata
  # sits at column 0 and its labels at two spaces.
  grep -q '^    metadata:$' "$manifest" || return 1
  grep -q '^      labels:$' "$manifest" || return 1
  # rc.3 ships no annotations on the Pod template, but a release that adds one
  # would get a second `annotations:` key from the insert below -- a duplicate
  # mapping key, which kubectl rejects. Append to the existing block instead.
  if pod_template_has_annotations "$manifest"; then
    has_annotations=true
  fi
  rewritten=$(mktemp) || return 1
  # Passed through the environment rather than -v: awk interprets backslash
  # escapes in a -v value, and these are multi-line strings.
  if ! KWATCH_OPT_OUT_LABELS="$labels" \
    KWATCH_OPT_OUT_ANNOTATIONS="$annotations" \
    KWATCH_HAS_ANNOTATIONS="$has_annotations" awk '
    /^    metadata:$/ && meta == 0 {
      print
      meta = 1
      if (ENVIRON["KWATCH_OPT_OUT_ANNOTATIONS"] != "" &&
        ENVIRON["KWATCH_HAS_ANNOTATIONS"] != "true") {
        print "      annotations:"
        printf "%s\n", substr(ENVIRON["KWATCH_OPT_OUT_ANNOTATIONS"], 2)
      }
      next
    }
    /^      annotations:$/ && annotated == 0 {
      print
      annotated = 1
      if (ENVIRON["KWATCH_OPT_OUT_ANNOTATIONS"] != "" &&
        ENVIRON["KWATCH_HAS_ANNOTATIONS"] == "true") {
        printf "%s\n", substr(ENVIRON["KWATCH_OPT_OUT_ANNOTATIONS"], 2)
      }
      next
    }
    /^      labels:$/ && labelled == 0 {
      print
      labelled = 1
      if (ENVIRON["KWATCH_OPT_OUT_LABELS"] != "") {
        printf "%s\n", substr(ENVIRON["KWATCH_OPT_OUT_LABELS"], 2)
      }
      next
    }
    { print }
  ' "$manifest" >"$rewritten"; then
    rm -f "$rewritten"
    return 1
  fi
  # Trust the result only if every key actually landed.
  for profile in "${INJECTOR_OPT_OUT_PROFILES[@]-}"; do
    [ -n "$profile" ] || continue
    IFS='|' read -r provider scope key value <<< "$profile"
    if ! grep -qF "        $key: \"$value\"" "$rewritten"; then
      rm -f "$rewritten"
      return 1
    fi
  done
  mv "$rewritten" "$manifest" || { rm -f "$rewritten"; return 1; }
  return 0
}

# --- Deployment resources and placement ------------------------------------
#
# Stored as one annotation on the Deployment, semicolon-separated, so it reads
# plainly in `kubectl get deploy -o yaml`:
#
#   kwatch.sh/pod-overrides: requests.cpu=200m;limits.memory=512Mi;\
#     nodeSelector=kubernetes.io/os=linux,workload=infra
#
# Every value is validated before it is stored, and none of the permitted
# characters need quoting in YAML, JSON or a shell word.

# Quantity checks, deliberately narrower than Kubernetes accepts: these are the
# forms an operator writes, and rejecting the rest here gives a better error
# than the API server's.
valid_cpu_quantity() {
  case "$1" in
    ''|*[!0-9.m]*) return 1 ;;
  esac
  printf '%s' "$1" | grep -Eq '^([0-9]+m|[0-9]+(\.[0-9]+)?)$'
}

valid_memory_quantity() {
  printf '%s' "$1" | grep -Eq '^[0-9]+(\.[0-9]+)?(Ki|Mi|Gi|Ti|K|M|G|T)?$'
}

# Millicores and bytes, so a request can be compared with its limit before the
# cluster is touched.
cpu_to_milli() {
  local value="$1"
  case "$value" in
    *m) printf '%s' "${value%m}" ;;
    *) awk -v v="$value" 'BEGIN { printf "%d", v * 1000 }' ;;
  esac
}

memory_to_bytes() {
  local value="$1" number unit
  number=$(printf '%s' "$value" | sed -E 's/[A-Za-z]+$//')
  unit=$(printf '%s' "$value" | sed -E 's/^[0-9.]+//')
  awk -v n="$number" -v u="$unit" 'BEGIN {
    m = 1
    if (u == "Ki") m = 1024
    else if (u == "Mi") m = 1024 * 1024
    else if (u == "Gi") m = 1024 * 1024 * 1024
    else if (u == "Ti") m = 1024 * 1024 * 1024 * 1024
    else if (u == "K") m = 1000
    else if (u == "M") m = 1000000
    else if (u == "G") m = 1000000000
    else if (u == "T") m = 1000000000000
    printf "%.0f", n * m
  }'
}

# A comma-separated k=v list, using the label syntax Kubernetes enforces. Empty
# means "no placement constraint", which is how a nodeSelector is removed.
valid_node_selector() {
  local spec="$1" pair key value
  [ -n "$spec" ] || return 0
  local IFS=','
  for pair in $spec; do
    [ -n "$pair" ] || return 1
    case "$pair" in
      *=*) ;;
      *) return 1 ;;
    esac
    key="${pair%%=*}"
    value="${pair#*=}"
    printf '%s' "$key" |
      grep -Eq '^([A-Za-z0-9]([-A-Za-z0-9_.]*[A-Za-z0-9])?/)?[A-Za-z0-9]([-A-Za-z0-9_.]*[A-Za-z0-9])?$' ||
      return 1
    [ "${#key}" -le 253 ] || return 1
    [ -n "$value" ] || return 1
    printf '%s' "$value" |
      grep -Eq '^[A-Za-z0-9]([-A-Za-z0-9_.]*[A-Za-z0-9])?$' || return 1
    [ "${#value}" -le 63 ] || return 1
  done
  return 0
}

# The nodeSelector as pod-spec YAML, each line prefixed with a newline so an
# empty selector expands to nothing. Splitting on commas needs its own scope:
# unsetting a local IFS would expose the global one.
node_selector_yaml_lines() {
  local spec="$1" indent="$2" pair
  [ -n "$spec" ] || return 0
  local IFS=','
  for pair in $spec; do
    [ -n "$pair" ] || continue
    printf '\n%s%s: "%s"' "$indent" "${pair%%=*}" "${pair#*=}"
  done
}

# Read the recorded overrides from the workload. A fresh install has none.
#
# Two stores, each under two names, is four questions -- and asked one at a time
# that was five seconds every time the status was drawn, for an installation
# that has recorded nothing at all. Both names come back in one request per
# store instead: a jsonpath reads two annotations at once, and
# `get configmap a b --ignore-not-found` returns whichever exists.
deployment_overrides_read() {
  local deployment pair records
  DEPLOYMENT_OVERRIDES=""
  DEPLOYMENT_OVERRIDES_SOURCE=""
  LEGACY_OVERRIDES_IN_USE=false
  deployment=$(deployment_name || true)
  if [ -n "$deployment" ]; then
    # "|" cannot appear in a recorded value: quantities and label selectors are
    # alphanumerics with . - _ / and the , ; = this format already uses.
    pair=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
      -o "jsonpath={.metadata.annotations.${DEPLOYMENT_OVERRIDES_ANNOTATION//./\\.}}{\"|\"}{.metadata.annotations.${LEGACY_OVERRIDES_ANNOTATION//./\\.}}" \
      2>/dev/null || true)
    DEPLOYMENT_OVERRIDES="${pair%%|*}"
    if [ -z "$DEPLOYMENT_OVERRIDES" ]; then
      DEPLOYMENT_OVERRIDES="${pair#*|}"
      [ -n "$DEPLOYMENT_OVERRIDES" ] && LEGACY_OVERRIDES_IN_USE=true
    fi
    [ -n "$DEPLOYMENT_OVERRIDES" ] && DEPLOYMENT_OVERRIDES_SOURCE=deployment
  fi
  # Nothing on the workload: either it was never sized, or this is a reinstall
  # over a kept configuration. The record answers both the same way.
  if [ -z "$DEPLOYMENT_OVERRIDES" ]; then
    records=$(kubectl -n "$NAMESPACE" get configmap \
      "$DEPLOYMENT_OVERRIDES_CONFIGMAP_NAME" \
      "$LEGACY_OVERRIDES_CONFIGMAP_NAME" --ignore-not-found \
      -o "jsonpath={range .items[*]}{.metadata.name}{\"=\"}{.data.overrides}{\"\n\"}{end}" \
      2>/dev/null || true)
    DEPLOYMENT_OVERRIDES=$(printf '%s\n' "$records" |
      sed -n "s|^${DEPLOYMENT_OVERRIDES_CONFIGMAP_NAME}=||p" | head -1)
    if [ -z "$DEPLOYMENT_OVERRIDES" ]; then
      DEPLOYMENT_OVERRIDES=$(printf '%s\n' "$records" |
        sed -n "s|^${LEGACY_OVERRIDES_CONFIGMAP_NAME}=||p" | head -1)
      [ -n "$DEPLOYMENT_OVERRIDES" ] && LEGACY_OVERRIDES_IN_USE=true
    fi
    [ -n "$DEPLOYMENT_OVERRIDES" ] && DEPLOYMENT_OVERRIDES_SOURCE=record
  fi
  # Both stores are ordinary Kubernetes objects that anyone can edit, and these
  # values are written straight into a manifest. A bad quantity there would
  # fail the whole upgrade, so drop what does not validate rather than carrying
  # it into the apply.
  DEPLOYMENT_OVERRIDES=$(deployment_overrides_sanitize "$DEPLOYMENT_OVERRIDES")
  [ -n "$DEPLOYMENT_OVERRIDES" ] || DEPLOYMENT_OVERRIDES_SOURCE=""
  return 0
}

# Keeps the entries that are well formed and drops the rest, reporting anything
# discarded so a hand-edit that did not take is visible rather than silent.
deployment_overrides_sanitize() {
  local raw="$1" entry key value kept="" dropped=""
  [ -n "$raw" ] || return 0
  local IFS=';'
  for entry in $raw; do
    [ -n "$entry" ] || continue
    case "$entry" in
      *=*) ;;
      *) dropped="$dropped $entry"; continue ;;
    esac
    key="${entry%%=*}"
    value="${entry#*=}"
    case "$key" in
      requests.cpu|limits.cpu)
        if ! valid_cpu_quantity "$value"; then
          dropped="$dropped $key"
          continue
        fi
        ;;
      requests.memory|limits.memory)
        if ! valid_memory_quantity "$value"; then
          dropped="$dropped $key"
          continue
        fi
        ;;
      nodeSelector)
        if ! valid_node_selector "$value"; then
          dropped="$dropped $key"
          continue
        fi
        ;;
      license)
        # A marker, never a value: the key itself lives in a Secret.
        if [ "$value" != 1 ]; then
          dropped="$dropped $key"
          continue
        fi
        ;;
      *)
        dropped="$dropped $key"
        continue
        ;;
    esac
    if [ -n "$kept" ]; then
      kept="$kept;$entry"
    else
      kept="$entry"
    fi
  done
  unset IFS
  if [ -n "$dropped" ]; then
    ui_warn "⚠️ Ignoring unusable recorded Deployment settings:$dropped" >&2
  fi
  printf '%s' "$kept"
}

# Record the values in both stores. The ConfigMap is the one that survives an
# uninstall, so a failure to write it is worth reporting even though the Pod has
# already been resized.
deployment_overrides_write() {
  local deployment="$1" overrides="$2" rc=0
  kubectl -n "$NAMESPACE" annotate deployment "$deployment" \
    "$DEPLOYMENT_OVERRIDES_ANNOTATION=$overrides" --overwrite >/dev/null || rc=1
  # One record, not two: retire the old name rather than leaving a second copy
  # to drift out of step with this one. Only when a read actually found one --
  # otherwise this is two API calls per save that can never do anything.
  if [ "${LEGACY_OVERRIDES_IN_USE:-false}" = true ]; then
    kubectl -n "$NAMESPACE" annotate deployment "$deployment" \
      "${LEGACY_OVERRIDES_ANNOTATION}-" >/dev/null 2>&1 || true
    kubectl -n "$NAMESPACE" delete configmap \
      "$LEGACY_OVERRIDES_CONFIGMAP_NAME" --ignore-not-found >/dev/null 2>&1 || true
    # Not cleared here: this function runs under with_loading, which forks, so
    # the assignment would never reach the caller. Every read sets the flag
    # afresh, and every flow reads before it writes.
  fi
  kubectl -n "$NAMESPACE" create configmap "$DEPLOYMENT_OVERRIDES_CONFIGMAP_NAME" \
    --from-literal=overrides="$overrides" --dry-run=client -o yaml |
    kubectl apply -f - >/dev/null || rc=1
  kubectl -n "$NAMESPACE" label configmap "$DEPLOYMENT_OVERRIDES_CONFIGMAP_NAME" \
    app.kubernetes.io/instance="$RELEASE" \
    app.kubernetes.io/managed-by=kwatch.sh --overwrite >/dev/null 2>&1 || true
  return "$rc"
}

deployment_override_get() {
  local wanted="$1" entry
  local IFS=';'
  for entry in $DEPLOYMENT_OVERRIDES; do
    case "$entry" in
      "$wanted"=*) printf '%s' "${entry#*=}"; return 0 ;;
    esac
  done
  return 1
}

# The value the release itself ships, used for anything the operator left alone.
manifest_resource_default() {
  local manifest="$1" section="$2" field="$3"
  awk -v section="$section" -v field="$field" '
    /^        resources:$/ { inres = 1; next }
    inres && /^          [a-z]+:$/ {
      cur = $1
      sub(":", "", cur)
      next
    }
    inres && /^            [a-z]+:/ {
      key = $1
      sub(":", "", key)
      if (cur == section && key == field) {
        value = $2
        gsub(/"/, "", value)
        print value
        exit
      }
      next
    }
    inres { exit }
  ' "$manifest"
}

# The Lease name appears twice in the release manifest: the env var the
# process reads, and the resourceNames of the Role that lets it renew that
# one Lease. Renaming only the first leaves a release named anything but
# "kwatch" unable to hold its Lease, so both are rewritten together.
rewrite_release_lease_name() {
  local manifest="$1"
  sed -i.bak \
    -e "s/^\( *value: \)\"kwatch-leader\"$/\1\"${RELEASE}-leader\"/" \
    -e "s/^\( *resourceNames: \[\)\"kwatch-leader\"\]$/\1\"${RELEASE}-leader\"]/" \
    "$manifest"
  rm -f "$manifest.bak"
}

# Every resource the release ships is named "kwatch" or "kwatch-<role>",
# including the container and the Pod's serviceAccountName, so a release
# named anything else gets its own set: the Roles for the Lease, the restart
# evidence and the control-plane Leases, the data claim, the ServiceAccount
# the Pod runs as, and the container the manager looks up by name.
# The control-plane Role's "namespace: kube-system" is left alone.
# kwatch-license-instance keeps its name: the kwatch binary and the license
# Role's resourceNames hardcode it.
rewrite_release_names() {
  local manifest="$1" version="$2"
  sed -i.bak \
    -e "/^kind: Namespace$/,/^---$/ s/^  name: kwatch$/  name: __KWATCH_NAMESPACE__/" \
    -e "s/^\( *name: \)kwatch-license-instance$/\1__KWATCH_LICENSE_INSTANCE__/" \
    -e "s/^\( *-\{0,1\} *name: \)kwatch$/\1$RELEASE/g" \
    -e "s/^\( *serviceAccountName: \)kwatch$/\1$RELEASE/" \
    -e "s/^\( *name: \)kwatch-\([a-z][a-z-]*\)$/\1${RELEASE}-\2/g" \
    -e "s/^\( *claimName: \)kwatch-data$/\1${RELEASE}-data/" \
    -e "s/^\( *namespace: \)kwatch$/\1$NAMESPACE/g" \
    -e "s/^\( *app.kubernetes.io\/instance: \)kwatch$/\1$RELEASE/g" \
    -e "s#ghcr.io/abahmed/kwatch:[^[:space:]]*#ghcr.io/abahmed/kwatch:$version#g" \
    -e "s/secretName: kwatch/secretName: $CONFIG_SECRET_NAME/g" \
    -e "s/__KWATCH_NAMESPACE__/$NAMESPACE/g" \
    -e "s/__KWATCH_LICENSE_INSTANCE__/kwatch-license-instance/" \
    "$manifest"
  rm -f "$manifest.bak"
  rewrite_release_lease_name "$manifest"
}

# A ReadWriteOnce claim binds only through a StorageClass. The claim in the
# release manifest names none, so it binds only when the cluster marks one
# as default.
default_storage_class() {
  kubectl get storageclass \
    -o 'jsonpath={range .items[*]}{.metadata.name}{" "}{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}{" "}{.metadata.annotations.storageclass\.beta\.kubernetes\.io/is-default-class}{"\n"}{end}' \
    2>/dev/null | awk '$2 == "true" || $3 == "true" { print $1; exit }' || true
}

storage_class_exists() {
  kubectl get storageclass "$1" >/dev/null 2>&1
}

# The data volume the running Deployment uses, so an upgrade keeps it: a
# claim is never swapped for an emptyDir, or the other way round, unless the
# operator asks for it.
live_storage_mode() {
  local deployment="$1" volume
  volume=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.volumes[?(@.name=="data")].emptyDir}' \
    2>/dev/null || true)
  if [ -n "$volume" ]; then
    printf 'emptydir'
  else
    printf 'pvc'
  fi
}

# Decide where the state lives before the manifest is applied. The release
# default is a claim; without a default StorageClass that claim stays Pending
# and the Pod with it, so the choice is made here, where the cluster can be
# asked, instead of being discovered from a rollout that never completes.
choose_storage_mode() {
  local existing_deployment="$1" default_class choice
  case "$STORAGE_MODE" in
    pvc|emptydir|"") ;;
    *) die "KWATCH_STORAGE must be pvc or emptydir, not '$STORAGE_MODE'" ;;
  esac
  valid_memory_quantity "$STORAGE_SIZE" ||
    die "KWATCH_STORAGE_SIZE must be a memory quantity such as 2Gi, not '$STORAGE_SIZE'"
  if [ -n "$STORAGE_CLASS" ] && ! storage_class_exists "$STORAGE_CLASS"; then
    die "StorageClass '$STORAGE_CLASS' (KWATCH_STORAGE_CLASS) does not exist"
  fi
  if [ -n "$existing_deployment" ]; then
    [ -n "$STORAGE_MODE" ] ||
      STORAGE_MODE=$(live_storage_mode "$existing_deployment")
    return 0
  fi
  [ -z "$STORAGE_MODE" ] || return 0
  if [ -n "$STORAGE_CLASS" ]; then
    STORAGE_MODE=pvc
    return 0
  fi
  if [ "$(resolve_access list storageclasses)" = denied ]; then
    ui_info "ℹ️ Cannot list StorageClasses; assuming the cluster has a default one."
    STORAGE_MODE=pvc
    return 0
  fi
  default_class=$(default_storage_class)
  if [ -n "$default_class" ]; then
    STORAGE_MODE=pvc
    ui_detail "💾 State volume: a $STORAGE_SIZE claim on the default StorageClass '$default_class'."
    return 0
  fi
  ui_warn "⚠️ The cluster has no default StorageClass, so the release's state volume claim cannot bind."
  ui_detail "  kwatch keeps incidents and change history on that volume across restarts."
  choice=$(ui_select 0 \
    "📦 Use an emptyDir (no StorageClass needed; state is lost when the Pod moves)" \
    "💾 Name a StorageClass for the claim" \
    "↩️  Cancel") || return 1
  case "$choice" in
    0) STORAGE_MODE=emptydir ;;
    1)
      STORAGE_CLASS=$(ask "StorageClass name" "") || exit_expected
      storage_class_exists "$STORAGE_CLASS" ||
        die "StorageClass '$STORAGE_CLASS' does not exist"
      STORAGE_MODE=pvc
      ;;
    *) return 1 ;;
  esac
}

# Remove one whole document (kind and metadata.name) from a multi-document
# manifest, leaving no empty document behind.
remove_manifest_document() {
  local manifest="$1" kind="$2" name="$3"
  awk -v want_kind="$kind" -v want_name="$name" '
    function flush() {
      if (doc != "" && !(doc_kind == want_kind && doc_name == want_name)) {
        if (printed_any) print "---"
        printf "%s", doc
        printed_any = 1
      }
      doc = ""; doc_kind = ""; doc_name = ""; in_meta = 0
    }
    /^---[[:space:]]*$/ { flush(); next }
    {
      doc = doc $0 "\n"
      if ($1 == "kind:") doc_kind = $2
      if ($0 ~ /^metadata:/) in_meta = 1
      else if ($0 ~ /^[^ #]/) in_meta = 0
      if (in_meta && $0 ~ /^  name:/ && doc_name == "") doc_name = $2
    }
    END { flush() }
  ' "$manifest" >"$manifest.tmp" && mv "$manifest.tmp" "$manifest"
}

manifest_has_document() {
  local manifest="$1" kind="$2" name="$3"
  awk -v want_kind="$kind" -v want_name="$name" '
    BEGIN { missing = 1 }
    /^---/ { doc_kind = ""; doc_name = ""; in_meta = 0; next }
    $1 == "kind:" { doc_kind = tolower($2) }
    /^metadata:/ { in_meta = 1; next }
    /^[^ #]/ { in_meta = 0 }
    in_meta && /^  name:/ && doc_name == "" {
      doc_name = $2
      if (doc_kind == want_kind && doc_name == want_name) missing = 0
    }
    END { exit missing }
  ' "$manifest"
}

# The release ships a claim. In emptyDir mode the Deployment gets an emptyDir
# of the same size, the claim document is dropped, and the container learns
# the cap through KWATCH_VOLUME_LIMIT so the store's rewrite can check the
# real limit. In pvc mode a StorageClass named by the operator is written
# into the claim, and a claim that already exists is left out of the apply:
# its spec is immutable, and the existing claim is the state being kept.
apply_storage_mode_to_manifest() {
  local manifest="$1" claim="${RELEASE}-data"
  case "$STORAGE_MODE" in
    emptydir)
      awk -v size="$STORAGE_SIZE" '
        /^        persistentVolumeClaim:$/ {
          print "        emptyDir:"
          print "          sizeLimit: " size
          skip_claim = 1
          next
        }
        skip_claim && /^          claimName:/ { skip_claim = 0; next }
        /^          - name: KWATCH_DATA_DIR$/ {
          print "          - name: KWATCH_VOLUME_LIMIT"
          print "            value: \"" size "\""
        }
        { print }
      ' "$manifest" >"$manifest.tmp" && mv "$manifest.tmp" "$manifest" ||
        return 1
      remove_manifest_document "$manifest" PersistentVolumeClaim "$claim"
      ;;
    *)
      if kubectl -n "$NAMESPACE" get pvc "$claim" >/dev/null 2>&1; then
        remove_manifest_document "$manifest" PersistentVolumeClaim "$claim"
        return 0
      fi
      if [ -n "$STORAGE_CLASS" ]; then
        awk -v class="$STORAGE_CLASS" '
          { print }
          in_claim && /^  accessModes:/ { print "  storageClassName: " class }
          /^kind: PersistentVolumeClaim$/ { in_claim = 1 }
          /^---/ { in_claim = 0 }
        ' "$manifest" >"$manifest.tmp" && mv "$manifest.tmp" "$manifest" ||
          return 1
      fi
      if [ "$STORAGE_SIZE" != 2Gi ]; then
        sed -i.bak \
          "/^kind: PersistentVolumeClaim$/,\$ s/^\( *storage: \)2Gi$/\1$STORAGE_SIZE/" \
          "$manifest"
        rm -f "$manifest.bak"
      fi
      ;;
  esac
}

# The control-plane Lease Role lives in kube-system, where an operator's own
# access is often narrower than in the kwatch namespace. When it is denied,
# the two kube-system documents are left out rather than failing the whole
# apply: kwatch then reports the scheduler and controller-manager checks as
# unavailable in /health, and everything else runs.
strip_kube_system_rbac_if_denied() {
  local manifest="$1"
  grep -q '^  namespace: kube-system$' "$manifest" || return 0
  if [ "$(resolve_access create roles ns:kube-system)" != denied ] &&
    [ "$(resolve_access create rolebindings ns:kube-system)" != denied ]; then
    return 0
  fi
  ui_warn "⚠️ No permission to create a Role in kube-system; the control-plane Lease checks are skipped."
  ui_detail "  kwatch reports scheduler and controller-manager health as unavailable until an"
  ui_detail "  administrator grants ${RELEASE}-control-plane-leases in kube-system."
  remove_manifest_document "$manifest" Role "${RELEASE}-control-plane-leases"
  remove_manifest_document "$manifest" RoleBinding "${RELEASE}-control-plane-leases"
}

# Documents the installed release carried that the new one does not ship:
# the PodDisruptionBudget and the persistence Role of releases before the
# data volume, for example. Only manager-owned objects of this release go.
prune_superseded_resources() {
  local manifest="$1" kind name
  for kind in poddisruptionbudget role rolebinding; do
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      manifest_has_document "$manifest" "$kind" "$name" && continue
      ui_detail "🧹 Removing $kind $name: this release no longer ships it."
      delete_owned namespace "$kind" "$name"
    done < <(kubectl -n "$NAMESPACE" get "$kind" \
      -l "app.kubernetes.io/instance=$RELEASE,app.kubernetes.io/managed-by=kwatch.sh" \
      -o 'jsonpath={range .items[*]}{.metadata.name}{"\n"}{end}' \
      2>/dev/null || true)
  done
}

# Crossing into the data-volume releases rebuilds the state: incidents open
# in the old version are forgotten, and paging alerts it opened keep their
# old keys, so the new version does not resolve them.
state_reset_notice() {
  local previous="$1" target="$2"
  [ -n "$previous" ] || return 0
  [ "$(compare_release_versions "$previous" "$VOLUME_STATE_VERSION")" = -1 ] ||
    return 0
  [ "$(compare_release_versions "$target" "$VOLUME_STATE_VERSION")" != -1 ] ||
    return 0
  ui_warn "⚠️ $target keeps its state in a file on a new $STORAGE_SIZE volume; nothing is migrated from $previous."
  ui_detail "  Open incidents are rediscovered and announced again. Alerts the old version"
  ui_detail "  opened in paging tools keep their old keys and must be resolved there by hand."
}

# A release before the data volume kept its state in ConfigMaps. After the
# upgrade they hold nothing kwatch reads, so offer to remove them. Only
# ConfigMaps named after this release are listed, and the manager's own are
# left alone.
cleanup_legacy_state_configmaps() {
  local previous="$1" name
  local -a leftovers=()
  [ -n "$previous" ] || return 0
  [ "$(compare_release_versions "$previous" "$VOLUME_STATE_VERSION")" = -1 ] ||
    return 0
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    case "$name" in
      "$STATE_CONFIGMAP_NAME"|"$CATALOG_CACHE_NAME"|\
      "$FEATURE_CATALOG_CACHE_NAME"|"$PROVIDER_CATALOG_CACHE_NAME"|\
      "$DEPLOYMENT_OVERRIDES_CONFIGMAP_NAME"|"$LEGACY_OVERRIDES_CONFIGMAP_NAME")
        continue ;;
      "$RELEASE"-*) leftovers+=("$name") ;;
    esac
  done < <(kubectl -n "$NAMESPACE" get configmaps \
    -o 'jsonpath={range .items[*]}{.metadata.name}{"\n"}{end}' \
    2>/dev/null || true)
  [ "${#leftovers[@]}" -gt 0 ] || return 0
  ui_info "🗄️ kwatch $previous kept its state in ConfigMaps; since $VOLUME_STATE_VERSION it lives on the data volume."
  ui_detail "  ConfigMaps in $NAMESPACE that nothing reads any more:"
  for name in "${leftovers[@]}"; do
    ui_detail "    $name"
  done
  confirm_action "Remove these ${#leftovers[@]} ConfigMaps" "y" || return 0
  check_access delete configmaps namespace
  for name in "${leftovers[@]}"; do
    kubectl -n "$NAMESPACE" delete configmap "$name" --ignore-not-found \
      >/dev/null 2>&1 || true
  done
  ui_success "✅ Removed the previous release's state ConfigMaps."
}

# Secrets are watched by default so a rotated pull Secret or an expiring
# TLS certificate can be named as a cause. Only a hash of each value is kept.
secrets_watch_notice() {
  ui_detail "🔐 Secrets are watched (values are hashed, never stored). Turn this off with"
  ui_detail "   watch.secrets in Edit settings; the Helm chart can also drop the RBAC for it."
}

# Where the state lives, and whether the claim is bound: a Pending claim is
# the one reason a fresh install sits in Pending with nothing else wrong.
show_storage_status() {
  local deployment="$1" mode phase class
  mode=$(live_storage_mode "$deployment")
  if [ "$mode" = emptydir ]; then
    ui_kv "💾" "State" "emptyDir (lost when the Pod moves)"
    return 0
  fi
  phase=$(kubectl -n "$NAMESPACE" get pvc "${RELEASE}-data" \
    -o 'jsonpath={.status.phase}' 2>/dev/null || true)
  class=$(kubectl -n "$NAMESPACE" get pvc "${RELEASE}-data" \
    -o 'jsonpath={.spec.storageClassName}' 2>/dev/null || true)
  ui_kv "💾" "State" "claim ${RELEASE}-data ${phase:-missing}${class:+ on $class}"
}

# A component that stops is logged by the supervisor under a fixed phrase.
# Optional components retry on their own; a required one ends the process,
# so the last such lines are the best explanation of a Pod that is not ready.
component_stop_lines() {
  local selector="$1"
  kubectl -n "$NAMESPACE" logs -l "$selector" --tail=400 2>/dev/null |
    grep -F -e 'application component stopped' \
      -e 'optional component stopped' | tail -2 || true
}

claim_phase() {
  kubectl -n "$NAMESPACE" get pvc "${RELEASE}-data" \
    -o 'jsonpath={.status.phase}' 2>/dev/null || true
}

# The claim's last warning names the real cause of a Pending claim: a
# StorageClass with no working provisioner, or a provisioner that cannot
# serve the node the Pod was placed on.
claim_warning() {
  kubectl -n "$NAMESPACE" get events \
    --field-selector "involvedObject.kind=PersistentVolumeClaim,involvedObject.name=${RELEASE}-data,type=Warning" \
    -o 'jsonpath={.items[-1:].message}' 2>/dev/null || true
}

is_storage_failure() {
  local diagnostic
  diagnostic=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$diagnostic" in
    *"state claim"*|*provisioningfailed*|*"no topology key"*|\
    *"unbound immediate persistentvolumeclaims"*) return 0 ;;
  esac
  return 1
}

# The CSI driver that serves a StorageClass, learned from the cluster
# rather than assumed: a CSI class's provisioner is the driver name, so it
# is found among the registered drivers; an in-tree class (kubernetes.io/*)
# is served by whatever driver provisioned a volume of that class before;
# only when neither answers is Kubernetes' own in-tree-to-CSI translation
# list consulted. Empty when the driver cannot be determined.
csi_driver_for_class() {
  local class="$1" provisioner="$2" registered driver
  registered=$(kubectl get csinodes \
    -o 'jsonpath={range .items[*]}{range .spec.drivers[*]}{.name}{"\n"}{end}{end}' \
    2>/dev/null | sort -u)
  if printf '%s\n' "$registered" | grep -qx -- "$provisioner"; then
    printf '%s' "$provisioner"
    return 0
  fi
  driver=$(kubectl get pv \
    -o "jsonpath={range .items[?(@.spec.storageClassName==\"$class\")]}{.spec.csi.driver}{\"\\n\"}{end}" \
    2>/dev/null | grep . | head -1 || true)
  if [ -n "$driver" ]; then
    printf '%s' "$driver"
    return 0
  fi
  driver=$(csi_driver_for_in_tree_provisioner "$provisioner")
  if [ -n "$driver" ] && printf '%s\n' "$registered" | grep -qx -- "$driver"; then
    printf '%s' "$driver"
    return 0
  fi
  return 1
}

# Kubernetes' in-tree-to-CSI translation list (csi-translation-lib). It is
# complete for the in-tree plugins Kubernetes migrated; anything else is a
# CSI driver already, or unknown.
csi_driver_for_in_tree_provisioner() {
  case "$1" in
    kubernetes.io/aws-ebs) printf 'ebs.csi.aws.com' ;;
    kubernetes.io/gce-pd) printf 'pd.csi.storage.gke.io' ;;
    kubernetes.io/azure-disk) printf 'disk.csi.azure.com' ;;
    kubernetes.io/azure-file) printf 'file.csi.azure.com' ;;
    kubernetes.io/cinder) printf 'cinder.csi.openstack.org' ;;
    kubernetes.io/vsphere-volume) printf 'csi.vsphere.vmware.com' ;;
    kubernetes.io/portworx-volume) printf 'pxd.portworx.com' ;;
    kubernetes.io/rbd) printf 'rbd.csi.ceph.com' ;;
    *) printf '' ;;
  esac
}

# Provisioner and binding mode of a StorageClass in one read. Pinning
# matters only for WaitForFirstConsumer: with Immediate binding the volume
# exists before the Pod and carries the node affinity itself.
storage_class_facts() {
  kubectl get storageclass "$1" \
    -o 'jsonpath={.provisioner}{" "}{.volumeBindingMode}' 2>/dev/null || true
}

# How many nodes have the driver registered, out of all nodes. A driver
# that runs on some nodes only leaves a WaitForFirstConsumer claim stuck
# whenever the scheduler picks one of the others.
csi_driver_node_count() {
  kubectl get csinodes \
    -o "jsonpath={range .items[*]}{range .spec.drivers[?(@.name==\"$1\")]}{.name}{\"\\n\"}{end}{end}" \
    2>/dev/null | grep -c . || true
}

node_count() {
  kubectl get nodes -o 'jsonpath={range .items[*]}{.metadata.name}{"\n"}{end}' \
    2>/dev/null | grep -c . || true
}

# The driver's own topology label, which a node carries only once the driver
# is registered on it. Keys every node has (os, arch, hostname, zone) would
# not tell the nodes apart, so they are skipped.
csi_driver_topology_key() {
  local driver="$1" key
  while IFS= read -r key; do
    key="${key// /}"
    [ -n "$key" ] || continue
    case "$key" in
      kubernetes.io/*|topology.kubernetes.io/*|node.kubernetes.io/*) continue ;;
    esac
    printf '%s' "$key"
    return 0
  done < <(kubectl get csinodes \
    -o "jsonpath={range .items[*]}{range .spec.drivers[?(@.name==\"$driver\")]}{.topologyKeys}{\"\\n\"}{end}{end}" \
    2>/dev/null | tr -d '[]"' | tr ',' '\n' | sort -u)
  return 1
}

STORAGE_AFFINITY_ANNOTATION="kwatch.sh/storage-topology-key"

# Nodes on which the driver is registered, by name: the fallback when the
# driver has no topology label of its own. A snapshot, not a rule: nodes
# added later are not covered, so it is not recorded for upgrades.
csi_driver_node_names() {
  kubectl get csinodes \
    -o "jsonpath={range .items[*]}{.metadata.name}{\" \"}{range .spec.drivers[*]}{.name}{\",\"}{end}{\"\\n\"}{end}" \
    2>/dev/null | awk -v driver="$1" '
      index("," $2, "," driver ",") { print $1 }'
}

# A required node affinity: with one argument, nodes carrying that label;
# with more, the named nodes.
storage_affinity_json() {
  local key="$1" values="" name
  shift
  if [ "$#" -eq 0 ]; then
    printf '{"nodeAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":{"nodeSelectorTerms":[{"matchExpressions":[{"key":"%s","operator":"Exists"}]}]}}}' "$key"
    return 0
  fi
  for name in "$@"; do
    values="${values:+$values,}\"$name\""
  done
  printf '{"nodeAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":{"nodeSelectorTerms":[{"matchExpressions":[{"key":"%s","operator":"In","values":[%s]}]}]}}}' "$key" "$values"
}

# A storage affinity recorded on the running Deployment is written into the
# fresh release manifest, so an upgrade keeps kwatch on nodes the storage
# driver serves instead of landing on one it cannot.
inject_storage_affinity_into_manifest() {
  local manifest="$1" deployment="$2" key
  [ -n "$deployment" ] || return 0
  key=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o "jsonpath={.metadata.annotations.${STORAGE_AFFINITY_ANNOTATION//./\\.}}" \
    2>/dev/null || true)
  [ -n "$key" ] || return 0
  inject_affinity_key_into_manifest "$manifest" "$key"
}

inject_affinity_key_into_manifest() {
  local manifest="$1" key="$2"
  shift 2
  awk -v key="$key" -v names="$*" '
    { print }
    /^      serviceAccountName: / && !done {
      print "      affinity:"
      print "        nodeAffinity:"
      print "          requiredDuringSchedulingIgnoredDuringExecution:"
      print "            nodeSelectorTerms:"
      print "            - matchExpressions:"
      print "              - key: " key
      if (names == "") {
        print "                operator: Exists"
      } else {
        print "                operator: In"
        print "                values:"
        n = split(names, list, " ")
        for (i = 1; i <= n; i++) print "                - " list[i]
      }
      done = 1
    }
  ' "$manifest" >"$manifest.tmp" && mv "$manifest.tmp" "$manifest"
}

# Before the first apply: when the StorageClass's CSI driver is registered
# on only some nodes, a WaitForFirstConsumer claim binds only if the Pod
# lands on one of them. Pin the Pod there now, from what the cluster
# reports, instead of finding out from a claim that never binds. A driver
# registered on no node cannot provision at all, so the choice is emptyDir
# or stopping; in-tree provisioners without CSI registration are left to
# try, since they may still work.
plan_storage_affinity() {
  local manifest="$1" existing_deployment="$2" class provisioner driver
  local with_driver total key recorded="" choice binding name
  local -a names=()
  PLANNED_STORAGE_KEY=""
  [ "$STORAGE_MODE" = pvc ] || return 0
  if [ -n "$existing_deployment" ]; then
    recorded=$(kubectl -n "$NAMESPACE" get deployment "$existing_deployment" \
      -o "jsonpath={.metadata.annotations.${STORAGE_AFFINITY_ANNOTATION//./\\.}}" \
      2>/dev/null || true)
    [ -z "$recorded" ] || return 0
  fi
  class="$STORAGE_CLASS"
  if [ -z "$class" ]; then
    class=$(kubectl -n "$NAMESPACE" get pvc "${RELEASE}-data" \
      -o 'jsonpath={.spec.storageClassName}' 2>/dev/null || true)
  fi
  [ -n "$class" ] || class=$(default_storage_class)
  [ -n "$class" ] || return 0
  read -r provisioner binding <<<"$(storage_class_facts "$class")"
  [ -n "$provisioner" ] || return 0
  total=$(node_count)
  [ "${total:-0}" -gt 0 ] || return 0
  if ! driver=$(csi_driver_for_class "$class" "$provisioner"); then
    case "$provisioner" in
      # An in-tree plugin may still provision without a CSI registration.
      kubernetes.io/*) return 0 ;;
    esac
    ui_warn "⚠️ StorageClass '$class' is served by '$provisioner', which is registered on no node, so the state claim cannot bind."
    choice=$(ui_select 0 \
      "📦 Use an emptyDir instead (state is lost when the Pod moves)" \
      "↩️  Cancel") || return 1
    [ "$choice" = 0 ] || return 1
    STORAGE_MODE=emptydir
    apply_storage_mode_to_manifest "$manifest"
    return
  fi
  with_driver=$(csi_driver_node_count "$driver")
  [ "${with_driver:-0}" -lt "$total" ] || return 0
  [ "$binding" = WaitForFirstConsumer ] || return 0
  if key=$(csi_driver_topology_key "$driver"); then
    ui_detail "📍 The $driver storage driver runs on $with_driver of $total nodes; kwatch is kept on those (label $key)."
    inject_affinity_key_into_manifest "$manifest" "$key" || return 1
    PLANNED_STORAGE_KEY="$key"
    return 0
  fi
  # No label of its own: name the nodes, and say the list is a snapshot.
  while IFS= read -r name; do
    [ -n "$name" ] && names+=("$name")
  done < <(csi_driver_node_names "$driver")
  [ "${#names[@]}" -gt 0 ] || return 0
  ui_detail "📍 The $driver storage driver runs on $with_driver of $total nodes and has no topology label; kwatch is kept on ${names[*]}."
  ui_detail "   Nodes added later are not covered; re-run the manager after the node pool changes."
  inject_affinity_key_into_manifest "$manifest" kubernetes.io/hostname "${names[@]}" ||
    return 1
}

# A rollout that failed on an unbound claim. The claim's warning says why;
# the two generic repairs are to keep kwatch on the nodes the storage driver
# serves, or to give up persistent state and use an emptyDir.
repair_storage() {
  local version="$1" class provisioner="" driver with_driver=0 total key=""
  local deployment warning phase choice
  local -a labels=() actions=()
  phase=$(claim_phase)
  if [ -z "$phase" ] || [ "$phase" = Bound ]; then
    return 1
  fi
  deployment=$(deployment_name || true)
  [ -n "$deployment" ] || deployment="$RELEASE"
  warning=$(claim_warning)
  class=$(kubectl -n "$NAMESPACE" get pvc "${RELEASE}-data" \
    -o 'jsonpath={.spec.storageClassName}' 2>/dev/null || true)
  [ -n "$class" ] && read -r provisioner _ <<<"$(storage_class_facts "$class")"
  driver=""
  [ -n "$provisioner" ] &&
    driver=$(csi_driver_for_class "$class" "$provisioner" || true)
  ui_warn "⚠️ The state volume claim ${RELEASE}-data is $phase, so the Pod cannot start."
  [ -n "$warning" ] && ui_detail "  $(compact_reason "$warning")"
  total=$(node_count)
  if [ -n "$driver" ]; then
    with_driver=$(csi_driver_node_count "$driver")
    key=$(csi_driver_topology_key "$driver" || true)
  fi
  if [ "${with_driver:-0}" -gt 0 ] && [ "$with_driver" -lt "${total:-0}" ]; then
    ui_detail "  The $driver storage driver is registered on $with_driver of $total nodes; the claim was placed on a node without it."
    actions+=(affinity)
    labels+=("📍 Keep kwatch on the $with_driver node(s) where the storage driver runs")
  fi
  actions+=(emptydir cancel)
  labels+=(
    "📦 Use an emptyDir instead (state is lost when the Pod moves)"
    "↩️  Cancel"
  )
  choice=$(ui_select 0 "${labels[@]}") || return 1
  case "${actions[$choice]}" in
    affinity) repair_storage_affinity "$deployment" "$key" "$driver" ;;
    emptydir) repair_storage_emptydir "$version" ;;
    *) return 1 ;;
  esac
}

repair_storage_affinity() {
  local deployment="$1" key="$2" driver="$3" details patch affinity name
  local -a names=()
  if [ -n "$key" ]; then
    details="This adds a node affinity requiring the label $key, which a node"
    details+=" carries only once the storage driver is registered on it, and lets"
    details+=" the scheduler place the claim again. The affinity is recorded on"
    details+=" the Deployment and kept across upgrades."
    affinity=$(storage_affinity_json "$key")
  else
    while IFS= read -r name; do
      [ -n "$name" ] && names+=("$name")
    done < <(csi_driver_node_names "$driver")
    [ "${#names[@]}" -gt 0 ] || return 1
    details="The $driver driver has no topology label of its own, so this adds"
    details+=" a node affinity naming the nodes it runs on today (${names[*]})."
    details+=" Nodes added later are not covered; re-run the manager after the"
    details+=" node pool changes."
    affinity=$(storage_affinity_json kubernetes.io/hostname "${names[@]}")
  fi
  confirm_repair "keep kwatch on nodes the storage driver serves" "$details" ||
    return 1
  check_access patch deployments namespace
  check_access patch persistentvolumeclaims namespace
  if [ -n "$key" ]; then
    patch=$(printf '{"metadata":{"annotations":{"%s":"%s"}},"spec":{"template":{"spec":{"affinity":%s}}}}' \
      "$STORAGE_AFFINITY_ANNOTATION" "$key" "$affinity")
  else
    patch=$(printf '{"spec":{"template":{"spec":{"affinity":%s}}}}' "$affinity")
  fi
  with_loading "Pinning kwatch to nodes with the storage driver" \
    kubectl -n "$NAMESPACE" patch deployment "$deployment" --type=merge \
    -p "$patch" >/dev/null || return 1
  # The claim remembers the node it was first placed on and the provisioner
  # keeps retrying there; forget it so the scheduler chooses again.
  kubectl -n "$NAMESPACE" annotate pvc "${RELEASE}-data" \
    volume.kubernetes.io/selected-node- >/dev/null 2>&1 || true
  with_loading "Waiting for kwatch rollout" \
    wait_for_kwatch_rollout "$deployment" || return 1
  ui_success "✅ kwatch is ready on a node the storage driver serves."
}

repair_storage_emptydir() {
  local version="$1" details
  details="The unbound claim ${RELEASE}-data is deleted (it never held data) and"
  details+=" the Deployment is re-applied with an emptyDir volume of $STORAGE_SIZE."
  details+=" Incidents and change history are then lost whenever the Pod moves."
  confirm_repair "run kwatch without persistent state" "$details" || return 1
  check_access delete persistentvolumeclaims namespace
  STORAGE_MODE=emptydir
  kubectl -n "$NAMESPACE" delete pvc "${RELEASE}-data" --ignore-not-found \
    --wait=false >/dev/null 2>&1 || true
  apply_manifests "$version" || return 1
  verify_operational_security || return 1
  ui_success "✅ kwatch is ready without persistent state."
}

# Put the operator's resources and placement into the release manifest before it
# is applied. This is what makes them survive an upgrade: the manifest is fetched
# fresh every run, so anything not written back here is silently reverted to the
# release default. Anything the operator did not set keeps that default.
apply_deployment_overrides_to_manifest() {
  local manifest="$1" section field value node_spec rendered=""
  local limits_cpu limits_memory requests_cpu requests_memory rewritten
  local want_resources=false want_placement=false applied_all=true
  local has_resources=false requested_resources=false can_write_resources=true
  [ -n "$DEPLOYMENT_OVERRIDES" ] || return 0
  grep -q '^    spec:$' "$manifest" || return 1
  if [ "$(deployment_override_get license || true)" = 1 ]; then
    inject_license_env_into_manifest "$manifest" || applied_all=false
  fi
  grep -q '^        resources:$' "$manifest" && has_resources=true
  for section in limits requests; do
    for field in cpu memory; do
      value=$(deployment_override_get "$section.$field" || true)
      if [ -n "$value" ]; then
        requested_resources=true
      else
        value=$(manifest_resource_default "$manifest" "$section" "$field")
      fi
      case "$section$field" in
        limitscpu) limits_cpu="$value" ;;
        limitsmemory) limits_memory="$value" ;;
        requestscpu) requests_cpu="$value" ;;
        requestsmemory) requests_memory="$value" ;;
      esac
    done
  done
  # A resources block with a hole in it is worse than no override at all:
  # the Go memory limit is derived from limits.memory (KWATCH_MEMORY_LIMIT),
  # so an incomplete set means the block is left exactly as the release
  # shipped it.
  if [ -z "$limits_memory" ] || [ -z "$limits_cpu" ] ||
    [ -z "$requests_memory" ] || [ -z "$requests_cpu" ]; then
    can_write_resources=false
  fi
  [ "$has_resources" = true ] || can_write_resources=false
  if [ "$requested_resources" = true ]; then
    if [ "$can_write_resources" = true ]; then
      want_resources=true
    else
      # Placement is independent and can still be kept, so carry on and report
      # the shortfall to the caller rather than abandoning both.
      applied_all=false
    fi
  fi
  node_spec=$(deployment_override_get nodeSelector || true)
  if [ -n "$node_spec" ]; then
    want_placement=true
    rendered=$(node_selector_yaml_lines "$node_spec" '        ')
  fi
  if [ "$want_resources" != true ] && [ "$want_placement" != true ]; then
    [ "$applied_all" = true ] && return 0
    return 1
  fi
  rewritten=$(mktemp) || return 1
  # A release that starts shipping its own nodeSelector would otherwise end up
  # with two of them -- a duplicate mapping key kubectl rejects -- so the
  # shipped block is dropped whenever this one replaces it.
  if ! KWATCH_LIMITS_CPU="$limits_cpu" KWATCH_LIMITS_MEMORY="$limits_memory" \
    KWATCH_REQUESTS_CPU="$requests_cpu" \
    KWATCH_REQUESTS_MEMORY="$requests_memory" \
    KWATCH_NODE_SELECTOR="$rendered" \
    KWATCH_WANT_RESOURCES="$want_resources" awk '
    /^    spec:$/ && placed == 0 {
      print
      placed = 1
      if (ENVIRON["KWATCH_NODE_SELECTOR"] != "") {
        print "      nodeSelector:"
        printf "%s\n", substr(ENVIRON["KWATCH_NODE_SELECTOR"], 2)
      }
      next
    }
    /^      nodeSelector:$/ && ENVIRON["KWATCH_NODE_SELECTOR"] != "" {
      dropping_selector = 1
      next
    }
    dropping_selector == 1 {
      if ($0 ~ /^        /) next
      dropping_selector = 0
    }
    /^        resources:$/ && sized == 0 &&
      ENVIRON["KWATCH_WANT_RESOURCES"] == "true" {
      sized = 1
      print "        resources:"
      print "          limits:"
      printf "            memory: \"%s\"\n", ENVIRON["KWATCH_LIMITS_MEMORY"]
      printf "            cpu: \"%s\"\n", ENVIRON["KWATCH_LIMITS_CPU"]
      print "          requests:"
      printf "            memory: \"%s\"\n", ENVIRON["KWATCH_REQUESTS_MEMORY"]
      printf "            cpu: \"%s\"\n", ENVIRON["KWATCH_REQUESTS_CPU"]
      # Drop the block the release shipped, whatever it contained.
      dropping = 1
      next
    }
    dropping == 1 {
      if ($0 ~ /^          /) next
      dropping = 0
    }
    { print }
  ' "$manifest" >"$rewritten"; then
    rm -f "$rewritten"
    return 1
  fi
  # Trust the result only if what was asked for actually landed.
  if [ "$want_resources" = true ] &&
    ! grep -qF "            memory: \"$limits_memory\"" "$rewritten"; then
    rm -f "$rewritten"
    return 1
  fi
  if [ "$want_placement" = true ] &&
    ! grep -q '^      nodeSelector:$' "$rewritten"; then
    rm -f "$rewritten"
    return 1
  fi
  mv "$rewritten" "$manifest" || { rm -f "$rewritten"; return 1; }
  [ "$applied_all" = true ] && return 0
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
  local image="$1" output probe_labels probe_annotations
  # Carry the opt-outs collected so far, so each pass asks whether *this*
  # candidate metadata is admissible rather than re-asking the first question.
  probe_labels=$(opt_out_yaml_lines labels '    ')
  probe_annotations=$(opt_out_yaml_lines annotations '    ')
  if [ -n "$probe_annotations" ]; then
    probe_annotations=$'\n  annotations:'"$probe_annotations"
  fi
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
    app.kubernetes.io/managed-by: kwatch.sh$probe_labels$probe_annotations
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

# Decide the opt-outs before the Deployment is applied, and keep asking the API
# server until it admits the Pod. One injector's opt-out can uncover a second --
# a cluster running Datadog and Istio rejects the Pod again once the Datadog
# volume is gone -- and each pass re-probes with everything collected so far, so
# the set that comes out is one the cluster has actually accepted rather than a
# guess. Opting out is driven by the rejection, not by which webhooks happen to
# be installed: an injector whose content passes Pod Security is left to do its
# job.
#
# Nothing here can fail the install: an unidentified injector, a cluster that
# refuses the dry run, and a declined prompt all leave the previous behaviour in
# place, and the reactive repair still runs if the rollout then fails.
plan_injection_opt_out() {
  local image="$1" failure profile details providers limit passes
  INJECTOR_OPT_OUT_PROFILES=()
  INJECTOR_OPT_OUT_PATCH_AFTER=false
  if [ "${KWATCH_SKIP_ADMISSION_PREFLIGHT:-false}" = true ]; then
    return 0
  fi
  # One pass per known injector at most: every pass either adds an opt-out that
  # was not there before or leaves the loop, so the bound cannot be reached
  # without having identified them all.
  limit=$(injector_keywords | wc -l | tr -d '[:space:]')
  [ -n "$limit" ] || limit=1
  passes=0
  while [ "$passes" -lt "$limit" ]; do
    passes=$((passes + 1))
    if failure=$(admission_preflight_probe "$image"); then
      break
    fi
    [ -n "$failure" ] || break
    # A missing permission or an unsupported dry run is not a rejection; the
    # manager stays out of the way rather than reporting a cluster problem.
    is_injected_admission_failure "$failure" || break
    if ! profile=$(injection_opt_out_profile "$failure"); then
      ui_warn "⚠️ An admission injector adds content that Pod Security rejects in $NAMESPACE."
      ui_detail "$(compact_reason "$failure")"
      ui_warn "⚠️ The injector was not identified."
      show_injector_candidates
      ui_info "ℹ️ The manager will not guess an opt-out label or change cluster policy."
      break
    fi
    # The same answer twice means the opt-out did not stop the injection, so
    # another pass would only repeat itself.
    if injection_opt_out_collected "$profile"; then
      ui_warn "⚠️ An admission injector adds content that Pod Security rejects in $NAMESPACE."
      ui_detail "$(compact_reason "$failure")"
      ui_info "ℹ️ The documented opt-out did not stop it; nothing further is assumed."
      break
    fi
    INJECTOR_OPT_OUT_PROFILES+=("$profile")
  done
  [ "${#INJECTOR_OPT_OUT_PROFILES[@]}" -gt 0 ] || return 0
  # Already excluded on an earlier run: keep the set so the manifest carries it
  # rather than losing it, but do not ask the same question again.
  if injection_opt_outs_present; then
    return 0
  fi
  providers=$(opt_out_provider_list)
  details="$providers injection adds content to Pods in $NAMESPACE that Pod"
  details+=" Security rejects, so the workload could never start. This adds the"
  details+=" documented opt-out to the kwatch Pod template as it is created:"
  details+="$(opt_out_yaml_lines labels '  ')$(opt_out_yaml_lines annotations '  ')"
  details+=$'\n'"It does not change the injector, Pod Security, namespace"
  details+=" policy, or any other workload."
  confirm_repair \
    "exclude only the kwatch Pod from $providers injection" \
    "$details" || INJECTOR_OPT_OUT_PROFILES=()
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
  local deployment details json taint existing
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
  # The release ships tolerations of its own (a not-ready or unreachable node,
  # so the Pod moves quickly); a merge patch replaces the list, so keep them.
  existing=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.tolerations}' 2>/dev/null || true)
  if [[ "$existing" == \[*\] ]] && [ "$existing" != "[]" ]; then
    existing="${existing#\[}"
    json="${existing%\]},$json"
  fi
  check_access patch deployments namespace
  with_loading "Adding node tolerations" \
    kubectl -n "$NAMESPACE" patch deployment "$deployment" --type=merge \
    -p "{\"spec\":{\"template\":{\"spec\":{\"tolerations\":[$json]}}}}" ||
    return 1
  with_loading "Waiting for corrected kwatch rollout" \
    wait_for_kwatch_rollout "$deployment" || return 1
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
    wait_for_kwatch_rollout "$deployment"; then
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
  local pvc_phase
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
  pvc_phase=$(claim_phase)
  if [ -n "$pvc_phase" ]; then
    ui_detail "💾 State claim ${RELEASE}-data: $pvc_phase"
    [ "$pvc_phase" = Bound ] || ui_detail "   $(compact_reason "$(claim_warning)")"
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
  UI_TITLE_BASE="kwatch · $(context_label "$SELECTED_CONTEXT")"
  ui_title_step ""
  ui_detail "  Selected cluster: $(context_label "$SELECTED_CONTEXT")"
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
  local file="$1" entry id lifecycle description dependencies tier
  local catalog_version="" seen="|"
  local -a loaded=()
  while IFS= read -r entry || [ -n "$entry" ]; do
    if [[ "$entry" =~ ^#\ kwatch\ feature\ catalog\ v([0-9]+)$ ]]; then
      catalog_version="${BASH_REMATCH[1]}"
      continue
    fi
    [[ -z "$entry" || "$entry" = \#* ]] && continue
    IFS='|' read -r id lifecycle description dependencies tier <<<"$entry"
    [ -n "$id" ] && \
      [ "$lifecycle" = startup -o "$lifecycle" = runtime ] && \
      [ -n "$description" ] || return 1
    # v1 has no tier column; v2 requires community or pro.
    case "$catalog_version" in
      1) [ -z "$tier" ] || return 1 ;;
      2) [ "$tier" = community -o "$tier" = pro ] || return 1 ;;
      *) return 1 ;;
    esac
    case "$seen" in
      *"|$id|"*) return 1 ;;
    esac
    seen="${seen}${id}|"
    loaded+=("$entry")
  done < "$file"
  case " $SUPPORTED_FEATURE_CATALOG_VERSIONS " in
    *" $catalog_version "*) ;;
    *) return 1 ;;
  esac
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
# Backup names are per-second; these keep a second backup inside the same second
# from overwriting the first.
LAST_BACKUP_TIMESTAMP=""
LAST_BACKUP_SUFFIX=0""
backup_config() {
  local resource timestamp candidate license_key license_backup_file backup_rc=0
  local -a license_backup_args=()
  resource=$(kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" -o json)
  timestamp=$(date -u +%Y%m%d%H%M%S)
  # The name is only accurate to the second, and two backups can land inside
  # one -- entering the settings takes one, changing a value takes another.
  # `apply` would then overwrite the first, quietly costing a generation of the
  # thing that exists to protect the operator. Counting within the session
  # settles it without asking the API server: a collision means this session
  # just wrote that name.
  if [ "$timestamp" = "$LAST_BACKUP_TIMESTAMP" ]; then
    LAST_BACKUP_SUFFIX=$((LAST_BACKUP_SUFFIX + 1))
    candidate="${RELEASE}-config-$timestamp-$LAST_BACKUP_SUFFIX"
  else
    LAST_BACKUP_TIMESTAMP="$timestamp"
    LAST_BACKUP_SUFFIX=0
    candidate="${RELEASE}-config-$timestamp"
  fi
  BACKUP_NAME="$candidate"
  # The license key (the ${RELEASE}-license Secret) travels with the backup so a
  # restore does not lose it. kwatch-license-instance is deliberately NOT
  # included: it is kwatch's record of which install it belongs to, and putting
  # it back on a different cluster -- or into a copy of this one -- would make
  # that cluster look like a clone of the original and trip the one-key,
  # one-cluster check. kwatch rebuilds it on its own.
  license_backup_args=()
  license_backup_file=""
  if license_key=$(license_current_key); then
    license_backup_file=$(mktemp)
    chmod 600 "$license_backup_file"
    printf '%s' "$license_key" >"$license_backup_file"
    license_backup_args=(--from-file="$LICENSE_SECRET_KEY=$license_backup_file")
  fi
  kubectl -n "$NAMESPACE" create secret generic "$BACKUP_NAME" \
    --from-literal=resource.json="$resource" \
    ${license_backup_args[@]+"${license_backup_args[@]}"} \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null || backup_rc=$?
  [ -z "$license_backup_file" ] || rm -f "$license_backup_file"
  [ "$backup_rc" -eq 0 ] || return "$backup_rc"
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
  restore_license_from_backup
  deployment=$(deployment_name)
  [ -n "$deployment" ] || return 0
  restart_kwatch
}

# Puts the license Secret back from a backup when it has gone missing. An
# existing Secret is left alone: it may hold a newer key than the backup.
restore_license_from_backup() {
  local encoded key deployment
  encoded=$(secret_data_base64 "$BACKUP_NAME" "$LICENSE_SECRET_KEY")
  [ -n "$encoded" ] || return 0
  license_secret_exists && return 0
  key=$(printf '%s' "$encoded" | base64 -d 2>/dev/null ||
    printf '%s' "$encoded" | base64 --decode 2>/dev/null ||
    printf '%s' "$encoded" | base64 -D 2>/dev/null) || return 0
  [ -n "$key" ] || return 0
  license_store_secret "$key" || return 0
  deployment=$(deployment_name || true)
  [ -n "$deployment" ] && license_wire_env "$deployment" || true
  ui_info "🔑 Restored the license key ($(license_mask "$key"))."
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

# Applying a CRD that drops a version the cluster already stores objects in
# is rejected by the API server with a raw error. Check first.
crd_keeps_stored_versions() {
  local crd_file="$1" stored v
  stored=$(kubectl get crd kwatchconfigs.kwatch.abahmed.dev \
    -o 'jsonpath={.status.storedVersions[*]}' 2>/dev/null || true)
  for v in $stored; do
    grep -Eq "^    - name: $v\$" "$crd_file" && continue
    LAST_COMMAND_ERROR="This release cannot manage a cluster that already stores KwatchConfig as $v; choose a newer release."
    return 1
  done
}

# Releases that ship v1beta1 mark v1alpha1 deprecated, and kubectl warns on
# every write to it. Older CRDs serve only v1alpha1, so ask the installed CRD
# which version it serves; the fields written below are the same in both.
config_api_version() {
  local served
  served=$(kubectl get crd kwatchconfigs.kwatch.abahmed.dev \
    -o 'jsonpath={.spec.versions[?(@.served==true)].name}' 2>/dev/null || true)
  case " $served " in
    *" v1beta1 "*) printf '%s' kwatch.abahmed.dev/v1beta1 ;;
    *) printf '%s' kwatch.abahmed.dev/v1alpha1 ;;
  esac
}

# The installer creates the namespace itself, without the annotation that
# `kubectl apply` merges against, so applying the release's Namespace document
# onto it prints a warning. Drop that document when the namespace exists.
drop_namespace_document() {
  local manifest="$1"
  kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || return 0
  awk 'function flush() { if (!skip) printf "%s", buf; buf = ""; skip = 0 }
    /^---[[:space:]]*$/ { flush(); buf = $0 "\n"; next }
    /^kind: Namespace[[:space:]]*$/ { skip = 1 }
    { buf = buf $0 "\n" }
    END { flush() }' "$manifest" >"$manifest.ns" && mv "$manifest.ns" "$manifest"
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
  local api_version
  api_version=$(config_api_version)
  kubectl -n "$NAMESPACE" apply -f - <<EOF >/dev/null
apiVersion: $api_version
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
  verify_release_file "$version" deploy/crd.yaml "$tmp" ||
    die "${LAST_COMMAND_ERROR:-the CRD for $version could not be verified}"
  grep -q '^kind: CustomResourceDefinition$' "$tmp" || die "downloaded CRD for $version is invalid"
  crd_keeps_stored_versions "$tmp" || die "$LAST_COMMAND_ERROR"
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

# Providers that will exist after this edit: the ones already configured plus
# the ones chosen in this session, each counted once.
provider_total_count() {
  local provider display
  {
    existing_provider_names | while IFS='|' read -r provider display; do
      printf '%s\n' "$provider"
    done
    printf '%s' "${CONFIGURED_PROVIDERS:-|}" | tr '|' '\n'
  } | sed '/^$/d' | sort -u | wc -l | tr -d ' '
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
    count=$(ask_or_back "Number of custom webhook headers" "0") || return 2
    [[ "$count" =~ ^[0-9]+$ ]] && break
    ui_warn "⚠️ Header count must be a non-negative integer."
  done
  [ "$count" -gt 0 ] || return 0
  printf '    headers:\n' >>"$file"
  for ((i = 1; i <= count; i++)); do
    while true; do
      name=$(ask_or_back "Header $i name") || return 2
      [ -n "$name" ] && break
      ui_warn "⚠️ Header name cannot be empty."
    done
    while true; do
      value=$(ask_secret_or_back "Header $i value") || return 2
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
  local decision index row path_width value_width max_value
  local -a categories=() category_labels=() entries=() labels=() values=() paths=()
  local -a captions=()
  CONFIG_FLOW_CHANGED=false
  require_config_catalog
  # No confirmation to reach the list: nothing is written by browsing it, and
  # each individual change is confirmed on its own below.
  ensure_crd
  # Opening the settings is around twenty seconds of API calls on a remote
  # cluster the first time -- a permission preflight, the configuration
  # resource, two migrations and a backup. Name each step rather than leaving a
  # blank screen; the permission answers are cached, so a second visit is quick.
  ui_busy "Checking permissions"
  preflight_access manage
  ui_busy_done
  ui_busy "Reading the configuration resource"
  preflight_config_resource
  ensure_config_resource
  ui_busy_done
  ui_busy "Preserving existing settings"
  migrate_legacy_telemetry ||
    die "could not preserve the existing telemetry setting"
  ui_busy_done
  ui_busy "Saving a configuration backup"
  backup_config
  ui_busy_done
  ui_busy "Migrating legacy settings"
  if ! migrate_legacy_silences; then
    ui_busy_done
    ui_error "❌ Legacy configuration migration failed; the previous configuration can be restored."
    restore_backup_after_failure \
      "This reverses the legacy settings migration that just failed." || true
    die "configuration migration failed"
  fi
  ui_busy_done
  categories=("Alerts" "Scope" "Performance" "Incident memory" "Noise reduction"
    "Monitors" "Operations" "Compatibility" "Product control" "Security")
  category_labels=("🚨 Alerts" "🎯 Scope" "⚡ Performance" "🧠 Incident memory"
    "🔇 Noise reduction" "🔍 Monitors" "🛠️  Operations" "🔄 Compatibility"
    "🎛️  Product control" "🔒 Security" "↩️  Back")
  while true; do
    ui_screen_clear
    ui_heading "⚙️  kwatch configuration"
    show_flow_notice
    # Leaving the settings without editing anything changed nothing, so the
    # session does not need to re-read the installation on the way back.
    choice=$(ui_select 0 "${category_labels[@]}") || {
      [ "$CONFIG_FLOW_CHANGED" = true ] || MENU_READ_ONLY=true
      return 0
    }
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
      flow_notice info "ℹ️ No settings in $category."
      continue
    fi
    values=()
    ui_busy "Reading current values"
    while IFS= read -r current; do
      values+=("$current")
    done < <(config_values_for_paths "${paths[@]}")
    ui_busy_done
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
    # With the description off the row there is room for the value in full;
    # cap it only at what the window can actually show.
    max_value=$(($(ui_columns) - path_width - 10))
    [ "$max_value" -lt 8 ] && max_value=8
    [ "$value_width" -gt "$max_value" ] && value_width="$max_value"
    # Two columns, not three. The description used to share the row and was
    # truncated to fit -- a clipped sentence is worse than none -- so it now
    # captions the highlighted row on the line below the window, in full.
    labels=()
    captions=()
    for index in "${!entries[@]}"; do
      IFS='|' read -r path type default category_name description status replacement <<<"${entries[$index]}"
      display_value="${values[$index]:-}"
      [ -n "$display_value" ] || display_value="default: $default"
      printf -v row '%-*s  %-*s' \
        "$path_width" "$(ui_truncate "$path" "$path_width")" \
        "$value_width" "$(ui_truncate "$display_value" "$value_width")"
      config_path_is_pro "$path" && row="$row  $(pro_badge)"
      labels+=("$row")
      captions+=("$description")
    done
    labels+=("↩️  Back")
    captions+=("Return to the previous menu")
    ui_screen_clear
    ui_heading "📋  $category settings"
    choice=$(ui_select_captioned 0 "${#labels[@]}" "${labels[@]}" \
      "${captions[@]}") || continue
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
        value=$(ask_or_back "New value (Enter keeps current)" \
          "$prompt_default") || continue
        [ -n "$value" ] || continue
        ;;
    esac
    [ "$value" = "$current" ] && {
      flow_notice info "↩️ $path is already $value."
      continue
    }
    confirm_change \
      "⚙️ Change $path to '$value'." \
      "The current value is '${current:-default ($default)}'. kwatch will validate the new value and restart the workload if needed." || {
      flow_notice info "↩️ Keeping the existing value for $path."
      continue
    }
    CONFIG_FLOW_CHANGED=true
    backup_config
    if ! patch_config_value "$path" "$type" "$value"; then
      ui_error "❌ Invalid configuration value; the previous configuration can be restored."
      restore_backup_after_failure \
        "The attempted value was rejected by Kubernetes." || true
      continue
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
    flow_notice success "✅ Updated $path."
  done
}

configure_alert_flow() {
  local backup deployment had_backup=false rc
  LICENSE_COMMUNITY_CACHE=""
  require_provider_catalog
  # No confirmation here: reaching this flow is already a deliberate choice, and
  # nothing is written until the save step. Every prompt below accepts "back".
  PROVIDER_EDIT_INTENT=true
  ui_detail "Nothing is saved until the end; type back at any prompt to leave."
  ui_busy "Reading the configuration Secret"
  adopt_existing_config_secret
  ui_busy_done
  ensure_crd
  ui_busy "Reading the configuration resource"
  preflight_config_resource
  ensure_config_resource
  ui_busy_done
  ui_busy "Preserving existing settings"
  migrate_legacy_telemetry ||
    die "could not preserve the existing telemetry setting"
  ui_busy_done
  ui_busy "Checking permissions"
  preflight_alert_access
  ui_busy_done
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
      MENU_READ_ONLY=true
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
  if ui_interactive && confirm_action "Send a test alert now" "y"; then
    testalert_flow
  fi
}

configure_after_install() {
  local choice
  choice=$(ask_yes_no \
    "🛠️ Configure additional kwatch settings now? This includes all catalog settings" \
    "y")
  [ "$choice" = true ] && configure_flow
  # Every install path ends here, so this is the last thing an install asks.
  license_install_prompt
  return 0
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
# The Pod sizing is recorded twice: on the Deployment, where it is visible in a
# plain `kubectl get deploy -o yaml`, and in this ConfigMap, which outlives the
# Deployment. Uninstalling with configuration kept and then reinstalling would
# otherwise come back on the release defaults, which is not what "keep
# configuration" promises. A full purge removes both.
DEPLOYMENT_OVERRIDES_CONFIGMAP_NAME="${RELEASE}-deployment-overrides"
LEGACY_OVERRIDES_CONFIGMAP_NAME="${RELEASE}-pod-overrides"
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

# Answers one access question, from the session cache when it is already there.
# Prints allowed, denied or unknown; never exits, so it is safe to run several
# at once in the background.
#
# An access preflight is 28 SelfSubjectAccessReviews. Asked one at a time
# against a remote cluster that is about eleven seconds before a flow can draw
# anything, and the answers cannot change while the manager runs -- so they are
# asked together and remembered for the session.
resolve_access() {
  local verb="$1" resource="$2" scope="${3:-}" result file=""
  if [ -n "$SESSION_CACHE_DIR" ]; then
    file="$SESSION_CACHE_DIR/access-$verb-$resource-${scope:-cluster}"
    if [ -f "$file" ]; then
      cat "$file"
      return 0
    fi
  fi
  # A scope of "namespace" means the managed namespace; "ns:<name>" asks
  # about another one, such as kube-system.
  local target_namespace="$NAMESPACE"
  case "$scope" in ns:*) target_namespace="${scope#ns:}" ;; esac
  if [ -n "$scope" ]; then
    result=$(kubectl auth can-i "$verb" "$resource" --namespace "$target_namespace" 2>/dev/null || true)
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
    yes|yes\ *)
      [ -n "$file" ] && printf 'allowed' >"$file" 2>/dev/null
      printf 'allowed'
      ;;
    no|no\ *)
      [ -n "$file" ] && printf 'denied' >"$file" 2>/dev/null
      printf 'denied'
      ;;
    *)
      # Some Kubernetes distributions reject a preflight SelfSubjectAccessReview
      # for cluster resources even though the real operation is allowed. Do not
      # turn that discovery limitation into a noisy false warning; the command
      # that follows remains the authoritative check. Not remembered either:
      # the next answer may be conclusive.
      printf 'unknown'
      ;;
  esac
  return 0
}

check_access() {
  local verb="$1" resource="$2" scope="${3:-}" where=""
  case "$scope" in
    "") ;;
    ns:*) where=" in namespace ${scope#ns:}" ;;
    *) where=" in namespace $NAMESPACE" ;;
  esac
  if [ "$(resolve_access "$verb" "$resource" "$scope")" = denied ]; then
    die "missing Kubernetes permission: $verb $resource$where"
  fi
  return 0
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
  check_access get persistentvolumeclaims namespace
  if [ "$mode" = install ]; then
    check_access create namespaces
    check_access create deployments namespace
    check_access patch deployments namespace
    check_access create persistentvolumeclaims namespace
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
      check_access create persistentvolumeclaims namespace
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

have_command() { type -P "$1" >/dev/null 2>&1; }

# Prints the SHA-256 of a file with whichever tool the system has (GNU
# coreutils or the macOS/BSD shasum).
sha256_of_file() {
  local file="$1" out
  if have_command sha256sum; then
    out=$(sha256sum "$file") || return 1
  elif have_command shasum; then
    out=$(shasum -a 256 "$file") || return 1
  else
    return 1
  fi
  printf '%s' "${out%% *}"
}

# Checks a file downloaded from a release tag against the release's signed
# SHA256SUMS ("<sha256>  <repo path>" lines for deploy/deploy.yaml and
# deploy/crd.yaml). Returns 0 when the file is verified, or when the release
# predates SHA256SUMS and the operator accepts that. Returns 1 with
# LAST_COMMAND_ERROR set on a mismatch, a missing entry, a failed signature
# or when the checksums cannot be fetched: those are never skipped.
verify_release_file() {
  local version="$1" repo_path="$2" file="$3"
  local sums bundle code expected actual
  sums=$(mktemp) || return 1
  bundle=$(mktemp) || { rm -f "$sums"; return 1; }
  code=$(curl -sSL --retry 3 --retry-delay 2 --connect-timeout 10 \
    -o "$sums" -w '%{http_code}' \
    "$RELEASE_DOWNLOAD_URL/$version/SHA256SUMS" 2>/dev/null) || code=000
  case "$code" in
    200) ;;
    404)
      rm -f "$sums" "$bundle"
      ui_warn "⚠️ $version publishes no SHA256SUMS, so $repo_path cannot be verified."
      ui_detail "   Releases from v1.0.0-rc.20 on are checksummed; older ones are not."
      if [ -t 0 ] && ! confirm_action "Continue without verification" "n"; then
        LAST_COMMAND_ERROR="download of $repo_path for $version was not verified and you declined to continue"
        return 1
      fi
      return 0
      ;;
    *)
      rm -f "$sums" "$bundle"
      LAST_COMMAND_ERROR="could not fetch SHA256SUMS for $version (HTTP $code); refusing to apply an unverified $repo_path"
      return 1
      ;;
  esac
  expected=$(awk -v path="$repo_path" \
    '$2 == path || $2 == "*" path { print $1; exit }' "$sums")
  if [[ ! "$expected" =~ ^[0-9a-fA-F]{64}$ ]]; then
    rm -f "$sums" "$bundle"
    LAST_COMMAND_ERROR="SHA256SUMS for $version has no valid entry for $repo_path"
    return 1
  fi
  if have_command cosign; then
    code=$(curl -sSL --retry 3 --retry-delay 2 --connect-timeout 10 \
      -o "$bundle" -w '%{http_code}' \
      "$RELEASE_DOWNLOAD_URL/$version/SHA256SUMS.sigstore.json" \
      2>/dev/null) || code=000
    if [ "$code" = 200 ]; then
      if ! cosign verify-blob --bundle "$bundle" \
        --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
        --certificate-identity-regexp='^https://github.com/abahmed/kwatch/.github/workflows/publish.yml@' \
        "$sums" >/dev/null 2>&1; then
        rm -f "$sums" "$bundle"
        LAST_COMMAND_ERROR="the cosign signature on SHA256SUMS for $version did not verify"
        return 1
      fi
    else
      ui_warn "⚠️ No signature was published for SHA256SUMS of $version; checking SHA-256 only."
    fi
  else
    ui_detail "ℹ️ cosign is not installed, so the SHA256SUMS signature was not checked (SHA-256 only)."
  fi
  rm -f "$sums" "$bundle"
  actual=$(sha256_of_file "$file") || {
    LAST_COMMAND_ERROR="sha256sum or shasum is required to verify $repo_path"
    return 1
  }
  if [ "$(printf '%s' "$actual" | tr 'A-F' 'a-f')" != \
    "$(printf '%s' "$expected" | tr 'A-F' 'a-f')" ]; then
    LAST_COMMAND_ERROR="checksum mismatch for $repo_path at $version: expected $expected, got $actual. Nothing was applied."
    return 1
  fi
  ui_detail "🔐 Verified $repo_path ($version) against SHA256SUMS."
  return 0
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
  # A release candidate older than the stable release (left over once the
  # stable one ships) is not a choice worth offering.
  if [ -n "$preview" ] && [ "$(compare_release_versions "$preview" "$stable")" != 1 ]; then
    preview=""
  fi
  # Until the first stable 1.x, "latest" on GitHub is a 0.x release this
  # manager cannot run. Recommending it would only lead to a refusal.
  if version_is_legacy "$stable"; then
    if [ -z "$preview" ]; then
      ui_warn "⚠️ The latest stable release ($stable) predates v1.0.0 and cannot be managed by this manager."
      return 1
    fi
    ui_info "ℹ️ The latest stable release ($stable) predates v1.0.0; the current release candidate is $preview."
    confirm_action "Use release candidate $preview" "y" || return 1
    printf '%s' "$preview"
    return 0
  fi
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
    "$SESSION_CACHE_DIR/workload-selector" 2>/dev/null || true
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

lease_name_for_deployment() {
  local deployment="$1" lease
  lease=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.containers[0].env[?(@.name=="KWATCH_LEADER_ELECTION_NAME")].value}' \
    2>/dev/null || true)
  [ -n "$lease" ] || lease="${RELEASE}-leader"
  printf '%s' "$lease"
}

rollout_timeout_seconds() {
  local value
  case "$ROLLOUT_TIMEOUT" in
    (*s)
      value="${ROLLOUT_TIMEOUT%s}"
      [[ "$value" =~ ^[0-9]+$ ]] || { printf '%s' 300; return; }
      printf '%s' "$value"
      ;;
    (*m)
      value="${ROLLOUT_TIMEOUT%m}"
      [[ "$value" =~ ^[0-9]+$ ]] || { printf '%s' 300; return; }
      printf '%s' "$((10#$value * 60))"
      ;;
    (*h)
      value="${ROLLOUT_TIMEOUT%h}"
      [[ "$value" =~ ^[0-9]+$ ]] || { printf '%s' 300; return; }
      printf '%s' "$((10#$value * 3600))"
      ;;
    (*) printf '%s' 300 ;;
  esac
}

# A Pod being Running and 1/1 only describes that Pod. Wait for Kubernetes to
# finish the current Deployment revision, then separately confirm that Kwatch
# has elected a ready leader.
wait_for_kwatch_rollout() {
  local deployment="$1" deadline timeout_seconds
  local lease holder holder_ready phase
  timeout_seconds=$(rollout_timeout_seconds)
  lease=$(lease_name_for_deployment "$deployment")

  if ! kubectl -n "$NAMESPACE" rollout status "deployment/$deployment" \
    --timeout="${timeout_seconds}s" >/dev/null; then
    LAST_COMMAND_ERROR="Deployment rollout did not complete within ${timeout_seconds}s."
    phase=$(claim_phase)
    if [ -n "$phase" ] && [ "$phase" != Bound ]; then
      LAST_COMMAND_ERROR="$LAST_COMMAND_ERROR State claim ${RELEASE}-data is $phase: $(claim_warning)"
    fi
    ui_error "❌ Kwatch Deployment rollout did not complete."
    kubectl -n "$NAMESPACE" get deployment "$deployment" -o yaml >&2 || true
    kubectl -n "$NAMESPACE" get pods -l "$(workload_selector)" -o wide >&2 || true
    kubectl -n "$NAMESPACE" get lease "$lease" -o yaml >&2 || true
    return 1
  fi

  # Leader election starts after the new Pods are available. Give it a fresh,
  # bounded window instead of reusing time consumed by the Deployment rollout.
  deadline=$((SECONDS + timeout_seconds))
  while (( SECONDS < deadline )); do
    holder=$(kubectl -n "$NAMESPACE" get lease "$lease" \
      -o jsonpath='{.spec.holderIdentity}' 2>/dev/null || true)
    holder_ready=""
    if [ -n "$holder" ]; then
      holder_ready=$(kubectl -n "$NAMESPACE" get pod "$holder" \
        -o 'jsonpath={range .status.conditions[?(@.type=="Ready")]}{.status}{end}' \
        2>/dev/null || true)
    fi
    if [ -n "$holder" ] && [ "$holder_ready" = True ]; then
      return 0
    fi
    sleep 2
  done
  LAST_COMMAND_ERROR="Deployment rolled out, but its Lease holder is not ready."
  ui_error "❌ Kwatch did not complete its leader-aware rollout."
  kubectl -n "$NAMESPACE" get deployment "$deployment" -o yaml >&2 || true
  kubectl -n "$NAMESPACE" get pods -l "$(workload_selector)" -o wide >&2 || true
  kubectl -n "$NAMESPACE" get lease "$lease" -o yaml >&2 || true
  return 1
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
  with_loading "Waiting for kwatch rollout" \
    wait_for_kwatch_rollout "$deployment" || return 1
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
  if [ -z "$image" ]; then
    # Installs made before the container followed the release name still
    # call it "kwatch"; the Deployment has one container either way.
    deployment=$(deployment_name || true)
    if [ -n "$deployment" ]; then
      image=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
        -o 'jsonpath={.spec.template.spec.containers[0].image}' \
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
  # A state claim left by an uninstall is reused by the next install, so the
  # incident history survives; worth saying before that install starts.
  kubectl -n "$NAMESPACE" get pvc "${RELEASE}-data" \
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
  local area="$1" entry id lifecycle description dependencies tier line
  local shown=0 pro_shown=0
  for entry in ${FEATURE_CATALOG[@]+"${FEATURE_CATALOG[@]}"}; do
    IFS='|' read -r id lifecycle description dependencies tier <<<"$entry"
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
    if [ "$tier" = pro ]; then
      line="$line  $(pro_badge)${UI_DIM}"
      pro_shown=$((pro_shown + 1))
    fi
    ui_detail "  $line"
    shown=$((shown + 1))
  done
  printf '\n' >&2
  ui_detail "  $shown capabilities"
  if [ "$pro_shown" -gt 0 ]; then
    ui_detail "  PRO features need a license — kwatch Pro is free during early access: https://kwatch.dev/signup?src=installer"
  fi
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
# Scope is "namespace" (the managed one), "ns:<name>" (another namespace,
# such as kube-system for the control-plane Lease Role) or "cluster".
delete_owned() {
    local scope="$1" kind="$2" name="$3" owner app service_account
    local ns="$NAMESPACE"
    case "$scope" in
      ns:*) ns="${scope#ns:}"; scope=namespace ;;
    esac
    if [ "$scope" = namespace ]; then
      owner=$(kubectl -n "$ns" get "$kind" "$name" \
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
      check_access delete "$kind" "ns:$ns"
      kubectl -n "$ns" delete "$kind" "$name" \
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
  delete_owned namespace role "${RELEASE}-leader-election"
  delete_owned namespace rolebinding "${RELEASE}-leader-election"
  delete_owned namespace role "${RELEASE}-restart-evidence"
  delete_owned namespace rolebinding "${RELEASE}-restart-evidence"
  delete_owned namespace role "${RELEASE}-license"
  delete_owned namespace rolebinding "${RELEASE}-license"
  delete_owned ns:kube-system role "${RELEASE}-control-plane-leases"
  delete_owned ns:kube-system rolebinding "${RELEASE}-control-plane-leases"
  # Releases before the data volume shipped these.
  delete_owned namespace poddisruptionbudget "$RELEASE"
  delete_owned namespace rolebinding "$RELEASE"
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
  wait_for_kwatch_rollout "$deployment" >/dev/null 2>&1 || true
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
  local default="$5" description="$6" value allowed choice option
  local default_index=0 count
  local -a options=() option_labels=()
  case "$validation" in
    one-of:*)
      # A closed set is a choice. Typing one of the values by hand, and being
      # told off for a typo, is work the list can do instead.
      allowed="${validation#one-of:}"
      while IFS= read -r option; do
        [ -n "$option" ] || continue
        if [ "$option" = "$default" ]; then
          default_index="${#options[@]}"
          option_labels+=("$option ${UI_GREEN}(current)${UI_RESET}")
        else
          option_labels+=("$option")
        fi
        options+=("$option")
      # printf '%s\n', not '%s': without the trailing newline `read` returns
      # non-zero on the last value and the loop body never runs for it, which
      # silently dropped the final allowed value.
      done < <(printf '%s\n' "$allowed" | tr ',' '\n')
      if [ "${#options[@]}" -gt 0 ] && ui_interactive; then
        ui_info "🎯 $description"
        count="${#options[@]}"
        # An empty answer means "leave this field as it is", which the typed
        # prompt gets from pressing Enter; the list needs to offer it.
        choice=$(ui_select "$default_index" "${option_labels[@]}" \
          "⏭️  Leave unchanged" "↩️  Back") || return 2
        if [ "$choice" -lt "$count" ]; then
          printf '%s' "${options[$choice]}"
          return 0
        fi
        [ "$choice" -eq "$count" ] || return 2
        printf ''
        return 0
      fi
      ui_info "🎯 Allowed values for $field: ${allowed//,/ · }"
      ;;
  esac
  while true; do
    if [ "$secret" = true ]; then
      value=$(ask_secret_or_back "$description") || return 2
    else
      value=$(ask_or_back "$description" "$default") || return 2
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
      # A second provider is where Community stops sending: say so now, but
      # still let the operator save it.
      if [ "$(provider_total_count)" -gt 1 ]; then
        warn_community_provider_cap
      fi
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
  # These are Secret-backed extras unrelated to providers, such as the
  # heartbeat URL. Asking for each one on every provider edit was a prompt that
  # is almost always answered with Enter, so ask once whether they are wanted
  # at all; declining keeps whatever is already stored.
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
# when the change is visible first, but the upgrade has already been confirmed
# by the time this runs, so asking again is one prompt too many. Print the diff
# for whoever wants it -- KWATCH_SHOW_DIFF=true -- and stay silent otherwise.
# Never on a fresh install: there is nothing to compare against.
preview_manifest_changes() {
  local manifest="$1" existing="$2" diff_output
  [ -n "$existing" ] || return 0
  [ "${KWATCH_SHOW_DIFF:-false}" = true ] || return 0
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

# kwatch holds its Lease through a Role scoped with resourceNames, so an
# unnamed authorization query would report a false denial. Ask about the
# exact Lease, and about creating it, as the workload's ServiceAccount.
# A release whose RBAC is intact answers yes to all and nothing changes.
self_check_rbac_missing() {
  local subject="system:serviceaccount:$NAMESPACE:$RELEASE" lease answer verb
  local deployment
  deployment=$(deployment_name || true)
  lease=$(lease_name_for_deployment "${deployment:-$RELEASE}")
  for verb in get update; do
    answer=$(kubectl auth can-i "$verb" leases.coordination.k8s.io \
      --resource-name="$lease" -n "$NAMESPACE" --as="$subject" \
      2>/dev/null || true)
    case "$answer" in
      *no*) return 0 ;;
      *yes*) ;;
      # Impersonation is not allowed here, so the question cannot be asked.
      *) return 1 ;;
    esac
  done
  answer=$(kubectl auth can-i create leases.coordination.k8s.io \
    -n "$NAMESPACE" --as="$subject" 2>/dev/null || true)
  case "$answer" in
    *no*) return 0 ;;
  esac
  return 1
}

repair_self_check_rbac() {
  local role="${RELEASE}-leader-election" lease details patch deployment
  deployment=$(deployment_name || true)
  lease=$(lease_name_for_deployment "${deployment:-$RELEASE}")
  kubectl -n "$NAMESPACE" get role "$role" >/dev/null 2>&1 || return 1
  details="kwatch cannot hold its Lease '$lease', so it never starts monitoring."
  details+=" This adds the create rule and the named get/update rule for that"
  details+=" Lease to $role in $NAMESPACE."
  confirm_repair "grant the Lease permissions" "$details" || return 1
  check_access patch roles namespace
  patch=$(printf '%s%s%s%s' \
    '[{"op":"add","path":"/rules/-","value":{"apiGroups":["coordination.k8s.io"],' \
    '"resources":["leases"],"verbs":["create"]}},' \
    '{"op":"add","path":"/rules/-","value":{"apiGroups":["coordination.k8s.io"],' \
    "\"resources\":[\"leases\"],\"resourceNames\":[\"$lease\"],\"verbs\":[\"get\",\"update\"]}}]")
  with_loading "Updating $role" kubectl -n "$NAMESPACE" patch role "$role" \
    --type=json -p "$patch" \
    >/dev/null || return 1
  restart_kwatch || return 1
  ui_success "✅ Lease permissions granted."
  return 0
}

apply_manifests() {
  local version="$1" tmp crd_tmp deployment existing_deployment profile
  local rollout_error event_detail
  local manifest_to_apply
  valid_release_version "$version" || die "invalid kwatch release version: $version"
  existing_deployment=$(deployment_name || true)
  if [ -n "$existing_deployment" ]; then
    adopt_existing_config_secret
  fi
  choose_storage_mode "$existing_deployment" || {
    LAST_COMMAND_ERROR="no state volume was chosen"
    return 1
  }
  tmp=$(mktemp)
  crd_tmp=$(mktemp)
  trap 'rm -f "${tmp:-}" "${tmp:-}.bak" "${crd_tmp:-}" \
    2>/dev/null || true' RETURN
  with_loading "Downloading CRD for $version" curl -fsSL --location \
    --retry 3 --retry-delay 2 --connect-timeout 10 \
    "$BASE_URL/$version/deploy/crd.yaml" -o "$crd_tmp" || return 1
  verify_release_file "$version" deploy/crd.yaml "$crd_tmp" || return 1
  crd_keeps_stored_versions "$crd_tmp" || return 1
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
  verify_release_file "$version" deploy/deploy.yaml "$tmp" || return 1
  if ! grep -q '^kind: Deployment$' "$tmp"; then
    LAST_COMMAND_ERROR="Downloaded deployment manifest for $version does not contain a Deployment."
    return 1
  fi
  rewrite_release_names "$tmp" "$version"
  drop_namespace_document "$tmp"
  ensure_config_volume_readable "$tmp"
  apply_storage_mode_to_manifest "$tmp" || {
    LAST_COMMAND_ERROR="the state volume could not be written into the manifest"
    return 1
  }
  strip_kube_system_rbac_if_denied "$tmp"
  plan_storage_affinity "$tmp" "$existing_deployment" || {
    LAST_COMMAND_ERROR="no state volume was chosen"
    return 1
  }
  inject_storage_affinity_into_manifest "$tmp" "$existing_deployment"
  # Carry the operator's resources and placement into the new manifest. Without
  # this the upgrade silently reverts them: the manifest is downloaded fresh
  # every run and ships the release's own values.
  deployment_overrides_read
  if [ -n "$DEPLOYMENT_OVERRIDES" ]; then
    if apply_deployment_overrides_to_manifest "$tmp"; then
      if [ -z "$(overrides_without_license)" ]; then
        :
      elif [ "$DEPLOYMENT_OVERRIDES_SOURCE" = record ]; then
        # Restoring sizing the operator set before an uninstall is helpful, but
        # only if they are told it happened.
        ui_detail "🧮 Restored the Deployment resources and placement recorded earlier."
      else
        ui_detail "🧮 Kept the configured Deployment resources and placement."
      fi
      if [ "$(deployment_override_get license || true)" = 1 ]; then
        ui_detail "🔑 Kept the Pro license key reference ($(license_secret_name))."
      fi
    else
      ui_warn "⚠️ The recorded Deployment resources could not be fully applied to this"
      ui_warn "   release; the parts that did not apply use the release defaults."
    fi
  fi
  # Ask the cluster what it will do to this Pod, and put the answer into the
  # manifest before it is applied: the workload is then created already
  # excluded, instead of being created, rejected by Pod Security, and patched
  # afterwards. Only when the manifest cannot be rewritten does the patch after
  # the apply remain as the fallback.
  plan_injection_opt_out "ghcr.io/abahmed/kwatch:$version"
  if [ "${#INJECTOR_OPT_OUT_PROFILES[@]}" -gt 0 ] &&
    ! inject_opt_out_into_manifest "$tmp"; then
    INJECTOR_OPT_OUT_PATCH_AFTER=true
  fi
  preview_manifest_changes "$tmp" "$existing_deployment"
  # Deployment selectors are immutable, so an older release whose selector
  # differs does need the Deployment recreated -- but omitting the selector from
  # the manifest is not how to get there. `kubectl apply` merges against the
  # last-applied-configuration annotation, which the manager's own previous
  # apply put a selector into, so a manifest without one asks the API server to
  # *delete* it: "spec.selector: Invalid value: null: field is immutable", on
  # every upgrade, including the ordinary one where the selector never changed.
  # Apply the manifest as the release ships it. A real selector change fails
  # here and the recreate below is offered, which is the only repair there is.
  manifest_to_apply="$tmp"
  invalidate_deployment_name
  if ! with_loading "Applying kwatch Deployment" kubectl apply -f \
    "$manifest_to_apply"; then
    # The prompt below asks for a delete-and-recreate. Show what Kubernetes
    # objected to first: it is the only evidence for whether that is the right
    # answer, and with_loading has captured it rather than printed it.
    if [ -n "$LAST_COMMAND_ERROR" ]; then
      ui_detail "$(compact_reason "$LAST_COMMAND_ERROR")"
    fi
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
  deployment=$(deployment_name)
  [ -n "$deployment" ] || deployment="$RELEASE"
  if [ -n "$PLANNED_STORAGE_KEY" ]; then
    kubectl -n "$NAMESPACE" annotate deployment "$deployment" \
      "$STORAGE_AFFINITY_ANNOTATION=$PLANNED_STORAGE_KEY" --overwrite \
      >/dev/null 2>&1 || true
  fi
  if [ "$INJECTOR_OPT_OUT_PATCH_AFTER" = true ]; then
    for profile in "${INJECTOR_OPT_OUT_PROFILES[@]-}"; do
      [ -n "$profile" ] || continue
      apply_injection_opt_out "$deployment" "$profile" || return 1
    done
  fi
  # The sizing came from the surviving record, so this Deployment does not carry
  # the annotation yet. Mirror it back, so the values stay visible on the
  # workload rather than only in the record.
  if [ "$DEPLOYMENT_OVERRIDES_SOURCE" = record ] && [ -n "$DEPLOYMENT_OVERRIDES" ]; then
    deployment_overrides_write "$deployment" "$DEPLOYMENT_OVERRIDES" >/dev/null 2>&1 || true
  fi
  if with_loading "Waiting for kwatch rollout" \
    wait_for_kwatch_rollout "$deployment"; then
    prune_superseded_resources "$tmp"
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

# Six of these seven answers come from the same Deployment, and asked one at a
# time they were six silent seconds at the end of every upgrade. One request
# returns them all: none of the values -- true, false, RuntimeDefault, ALL, a
# file mode -- can contain the separator.
verify_operational_security() {
  local deployment enforce non_root read_only no_escalation seccomp dropped secret_mode
  local fields
  deployment=$(deployment_name)
  [ -n "$deployment" ] || deployment="$RELEASE"
  ui_busy "Verifying operational security"
  enforce=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.labels.pod-security\.kubernetes\.io/enforce}')
  fields=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o "jsonpath={.spec.template.spec.containers[?(@.name==\"$RELEASE\")].securityContext.runAsNonRoot}{\"|\"}{.spec.template.spec.containers[?(@.name==\"$RELEASE\")].securityContext.readOnlyRootFilesystem}{\"|\"}{.spec.template.spec.containers[?(@.name==\"$RELEASE\")].securityContext.allowPrivilegeEscalation}{\"|\"}{.spec.template.spec.containers[?(@.name==\"$RELEASE\")].securityContext.seccompProfile.type}{\"|\"}{.spec.template.spec.containers[?(@.name==\"$RELEASE\")].securityContext.capabilities.drop[0]}{\"|\"}{.spec.template.spec.volumes[?(@.name==\"config-volume\")].secret.defaultMode}")
  IFS='|' read -r non_root read_only no_escalation seccomp dropped secret_mode \
    <<< "$fields"
  ui_busy_done
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
  ui_busy "Checking install permissions"
  preflight_access install
  ui_busy_done
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
      record_state complete "$version" "installation repaired after granting the Lease permissions"
      FRESH_INSTALL=false
      configure_after_install
      return 0
    elif is_storage_failure "$install_failure" && repair_storage "$version"; then
      record_state complete "$version" "installation repaired after fixing the state volume"
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
  secrets_watch_notice
  configure_after_install
}

upgrade_flow() {
  local version upgrade_failure="" change_confirmed="${1:-false}" allow_same=false
  local previous="$INSTALL_VERSION"
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
  state_reset_notice "$previous" "$version"
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
  ui_busy "Checking upgrade permissions"
  preflight_access upgrade
  ui_busy_done
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
  # A key supplied through the environment is recorded first, so the manifest
  # applied just below already carries it and the Pod rolls only once.
  license_apply_from_env record
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
    if is_storage_failure "$upgrade_failure" && repair_storage "$version"; then
      record_state complete "$version" "upgrade repaired after fixing the state volume"
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
  cleanup_legacy_state_configmaps "$previous"
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
    "🚪 Exit"); then
    case "$choice" in
      0) legacy_reinstall_flow; return ;;
      1) status_flow; MENU_READ_ONLY=true; return ;;
      2) logs_flow; MENU_READ_ONLY=true; return ;;
    esac
  fi
  MENU_EXIT=true
}

show_supported_menu() {
  ui_screen "ready"
  local choice
  local -a actions=() labels=()
  actions+=(status logs upgrade providers testalert settings resources capabilities license)
  labels+=(
    "📊 View status"
    "📜 View recent logs"
    "⬆️  Upgrade kwatch"
    "🔌 Edit notification providers"
    "🔔 Send test alert"
    "⚙️  Edit settings"
    "🧮 Edit Deployment resources and placement"
    "🧩 View capabilities"
    "🔑 License / Pro"
  )
  # Restoring is meaningless with nothing to restore from.
  if [ -n "$(config_backups)" ]; then
    actions+=(restore)
    labels+=("♻️  Restore a previous configuration")
  fi
  actions+=(diagnostics uninstall exit)
  labels+=("🧰 Save diagnostics to file" "🧹 Uninstall kwatch" "🚪 Exit")
  if ! choice=$(ui_select 0 "${labels[@]}"); then
    MENU_EXIT=true
    return
  fi
  case "${actions[$choice]}" in
    status) status_flow; MENU_READ_ONLY=true ;;
    logs) logs_flow; MENU_READ_ONLY=true ;;
    testalert) testalert_flow; MENU_READ_ONLY=true ;;
    diagnostics) diagnostics_flow; MENU_READ_ONLY=true ;;
    upgrade) upgrade_flow ;;
    providers)
      require_catalog_for "provider editing"
      configure_alert_flow
      ;;
    settings)
      require_catalog_for "settings editing"
      configure_flow
      ;;
    resources) configure_deployment_resources_flow || true ;;
    capabilities)
      require_catalog_for "capabilities"
      features_flow
      MENU_READ_ONLY=true
      ;;
    license) license_flow ;;
    restore) restore_flow ;;
    uninstall) uninstall_flow ;;
    *) MENU_EXIT=true ;;
  esac
}

# True when a kwatch Pod is waiting for a node that does not exist. A cluster
# that scales its nodes to zero out of hours puts the installation in exactly
# this state, and nothing the manager can do -- upgrading, disabling a
# component, granting a permission -- makes a Pod schedulable when there is
# nowhere to run it. Worth naming, so the operator is not sent looking for a
# fault in kwatch.
workload_unschedulable() {
  local selector="$1" phases nodes
  phases=$(kubectl -n "$NAMESPACE" get pods -l "$selector" \
    -o 'jsonpath={range .items[*]}{.status.phase}{" "}{end}' 2>/dev/null || true)
  case "$phases" in
    *Pending*) ;;
    *) return 1 ;;
  esac
  # "NotReady" does not contain " Ready", so this counts only usable nodes.
  nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready' || true)
  [ "${nodes:-0}" -eq 0 ] 2>/dev/null || return 1
  return 0
}

# True when a kwatch container was killed for exceeding its memory limit. That
# is the one broken state whose repair is a resource change rather than a
# rollout, so it is worth recognising by name.
workload_was_oomkilled() {
  local selector="$1" reasons
  reasons=$(kubectl -n "$NAMESPACE" get pods -l "$selector" \
    -o 'jsonpath={range .items[*]}{.status.containerStatuses[*].lastState.terminated.reason}{" "}{.status.containerStatuses[*].state.terminated.reason}{" "}{end}' \
    2>/dev/null || true)
  case "$reasons" in
    *OOMKilled*) return 0 ;;
  esac
  return 1
}

show_broken_menu() {
  local choice selector oomkilled=false unschedulable=false
  local selfcheck_missing storage_pending=false claim
  local -a actions=() labels=()
  ui_screen "needs attention"
  ui_kv "📦" "Deployment" "${INSTALL_DEPLOYMENT:-unknown}"
  ui_kv "🏷️" "Version" "${INSTALL_VERSION:-unknown}"
  ui_kv "❗" "Reason" "$INSTALL_REASON"
  printf '\n' >&2
  selector=$(workload_selector)
  # Five round trips before this menu can be drawn, which on a remote cluster is
  # several seconds of nothing. Do the silent probing first, under one notice,
  # then print -- show_unready_pods writes as it goes and would overwrite it.
  ui_busy "Diagnosing the installation"
  workload_unschedulable "$selector" && unschedulable=true
  workload_was_oomkilled "$selector" && oomkilled=true
  selfcheck_missing=false
  self_check_rbac_missing && selfcheck_missing=true
  claim=$(claim_phase)
  [ -n "$claim" ] && [ "$claim" != Bound ] && storage_pending=true
  ui_busy_done
  show_unready_pods "$selector" || true
  if [ "$unschedulable" = true ]; then
    ui_warn "⚠️ No node is available, so the Pod cannot be placed anywhere."
    ui_detail "  This is not a kwatch fault and no repair here can change it."
    ui_detail "  A cluster that scales its nodes to zero out of hours recovers"
    ui_detail "  on its own once a node returns."
  fi
  # Offer the repair that matches the symptom first. Being killed for memory is
  # not fixed by another rollout of the same release; the limit has to change.
  if [ "$oomkilled" = true ]; then
    ui_warn "⚠️ A kwatch container was killed for exceeding its memory limit."
    ui_detail "  Raising the memory limit is the repair; the value is kept across upgrades."
    actions+=(resources)
    labels+=("🧮 Raise the memory limit (the container was OOMKilled)")
  fi
  if [ "$storage_pending" = true ]; then
    ui_warn "⚠️ The state volume claim is $claim; the Pod cannot start without it."
    actions+=(storage)
    labels+=("💾 Fix the state volume (claim is $claim)")
  fi
  if [ "$selfcheck_missing" = true ]; then
    actions+=(selfcheck)
    labels+=("🔑 Grant the Lease permissions")
  fi
  actions+=(status logs upgrade settings providers)
  labels+=(
    "📊 View status"
    "📜 View recent logs"
    "🛠️  Repair by upgrading kwatch"
    "⚙️  Edit settings"
    "🔌 Edit notification providers"
  )
  # Only worth listing twice when it is not already the first entry.
  if [ "$oomkilled" != true ]; then
    actions+=(resources)
    labels+=("🧮 Edit Deployment resources and placement")
  fi
  actions+=(uninstall exit)
  labels+=(
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
    storage) repair_storage "${INSTALL_VERSION:-}" || true ;;
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
    status) status_flow; MENU_READ_ONLY=true ;;
    logs) logs_flow; MENU_READ_ONLY=true ;;
    resources) configure_deployment_resources_flow || true ;;
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
  local phase probe pvc_phase
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
        # A Pending Pod whose state claim is not bound is waiting for storage,
        # not for a node; say so, since the scheduler's message only hints at it.
        if [ "$phase" = Pending ]; then
          pvc_phase=$(kubectl -n "$NAMESPACE" get pvc "${RELEASE}-data" \
            -o 'jsonpath={.status.phase}' 2>/dev/null || true)
          if [ -n "$pvc_phase" ] && [ "$pvc_phase" != Bound ]; then
            scheduling="${scheduling:+$scheduling }State volume claim ${RELEASE}-data is $pvc_phase; the cluster may have no default StorageClass."
          fi
        fi
      fi
    fi
    ui_warn "$(ui_dot bad) Pod $pod is not ready: ${waiting:-unknown}${terminated:+ (last exit: $terminated)}"
    [ -n "$scheduling" ] && ui_detail "   $(compact_reason "$scheduling")"
    [ -n "$probe" ] && ui_detail "   $(compact_reason "$probe")"
    # A required component that stopped ends the process, and the supervisor
    # logs which one; show that rather than leaving the restart unexplained.
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      ui_detail "   ⚠️ $(compact_reason "$line")"
    done < <(component_stop_lines "$selector")
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
    # -o wide names the node: with placement configurable, where the Pod landed
    # is part of the status rather than a detail to go digging for.
    kubectl -n "$NAMESPACE" get pods -l "$selector" -o wide 2>/dev/null |
      sed 's/^/  /' || true
    show_unready_pods "$selector" || true
    show_deployment_shape "$deployment"
    show_storage_status "$deployment"
  else
    ui_warn "⚠️ No kwatch Deployment was found."
  fi
  license_status_section
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

# Resources and placement belong in the status now that they can be changed,
# together with whether an upgrade will keep them.
show_deployment_shape() {
  local deployment="$1" index requests_cpu requests_memory limits_cpu
  local limits_memory selector_text opt_outs
  index=$(kwatch_container_index "$deployment") || return 0
  requests_cpu=$(live_resource_value "$deployment" "$index" requests cpu)
  requests_memory=$(live_resource_value "$deployment" "$index" requests memory)
  limits_cpu=$(live_resource_value "$deployment" "$index" limits cpu)
  limits_memory=$(live_resource_value "$deployment" "$index" limits memory)
  selector_text=$(live_node_selector "$deployment")
  printf '\n' >&2
  if [ -n "$requests_cpu$limits_cpu" ]; then
    ui_kv "🧮" "Resources" \
      "requests ${requests_cpu:-—}/${requests_memory:-—} · limits ${limits_cpu:-—}/${limits_memory:-—}"
  fi
  ui_kv "📍" "Placement" "${selector_text:-any node}"
  deployment_overrides_read
  if [ -n "$(overrides_without_license)" ]; then
    ui_detail "  🔒 Recorded; upgrades and reinstalls keep these values."
  else
    ui_detail "  ℹ️ Release defaults; edit them from the menu to keep them across upgrades."
  fi
  # An opt-out is invisible until something goes wrong with it, so say it is on.
  opt_outs=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.metadata.labels}{.spec.template.metadata.annotations}' \
    2>/dev/null || true)
  case "$opt_outs" in
    *admission.datadoghq.com/enabled*|*sidecar.istio.io/inject*|\
    *linkerd.io/inject*|*vault.hashicorp.com/agent-inject*|\
    *kuma.io/sidecar-injection*|*instrumentation.opentelemetry.io*)
      ui_detail "  🔌 Excluded from at least one admission injector."
      ;;
  esac
}

# Logs can carry a webhook URL or a token echoed back by a provider, so they get
# the same redaction as every other diagnostic the manager prints.
redact_stream() {
  sed -E 's#https?://[^ ]+#<url-redacted>#g;
    s/((token|password|secret)[=:])[[:space:]]*[^[:space:]]+/\1<redacted>/Ig'
}

# During a rollout there is more than one Pod, and the interesting one is
# usually not the first. Ask rather than picking silently.
select_workload_pod() {
  local selector="$1" choice index=0
  local -a pods=() labels=()
  local name phase ready restarts line
  while IFS='|' read -r name phase ready restarts; do
    [ -n "$name" ] || continue
    pods+=("$name")
    line="$name  ${UI_DIM}$phase"
    [ "$ready" = true ] || line="$line · not ready"
    [ "${restarts:-0}" = 0 ] || line="$line · ${restarts} restarts"
    labels+=("$line${UI_RESET}")
  done < <(kubectl -n "$NAMESPACE" get pods -l "$selector" \
    -o 'jsonpath={range .items[*]}{.metadata.name}{"|"}{.status.phase}{"|"}{.status.containerStatuses[0].ready}{"|"}{.status.containerStatuses[0].restartCount}{"\n"}{end}' \
    2>/dev/null || true)
  [ "${#pods[@]}" -gt 0 ] || return 1
  if [ "${#pods[@]}" -eq 1 ]; then
    printf '%s' "${pods[0]}"
    return 0
  fi
  ui_info "🧊 More than one kwatch Pod is present."
  # 2 for "cancelled", not 1: the caller would otherwise report that no Pod
  # exists, when the truth is that the user chose not to pick one.
  choice=$(ui_select 0 "${labels[@]}") || return 2
  printf '%s' "${pods[$choice]}"
  return 0
}

logs_flow() {
  local selector pod choice lines=200 rc=0 previous
  ui_screen "logs"
  selector=$(workload_selector)
  ui_busy "Finding the kwatch Pod"
  pod=$(select_workload_pod "$selector") || rc="$?"
  ui_busy_done
  if [ "${rc:-0}" -eq 2 ]; then
    return 0
  fi
  if [ -z "$pod" ]; then
    ui_warn "⚠️ No kwatch Pod was found in namespace $NAMESPACE."
    return 0
  fi
  ui_detail "Pod: $NAMESPACE/$pod"
  choice=$(ui_select 0 \
    "Last 50 lines" \
    "Last 200 lines" \
    "Last 1000 lines" \
    "🔎 Errors and warnings only" \
    "📡 Follow live" \
    "⏮️  Previous container (before the last restart)" \
    "↩️  Back") || return 0
  case "$choice" in
    0) lines=50 ;;
    1) lines=200 ;;
    2) lines=1000 ;;
    3)
      # The interesting lines are a small fraction of the output, so search a
      # deeper window than the plain views show.
      ui_rule
      kubectl -n "$NAMESPACE" logs "$pod" --tail=2000 2>&1 | redact_stream |
        grep -Ei 'error|warn|fail|panic|fatal|refused|denied|timeout' ||
        ui_detail "No errors or warnings in the last 2000 lines."
      ui_rule
      ui_pause
      return 0
      ;;
    4)
      follow_logs "$pod"
      return 0
      ;;
    5)
      # A Pod that has never restarted has no previous container, and kubectl
      # says so in a way worth replacing rather than printing alongside.
      ui_rule
      if previous=$(kubectl -n "$NAMESPACE" logs "$pod" --previous \
        --tail=200 2>/dev/null); then
        printf '%s\n' "$previous" | redact_stream
      else
        ui_detail "No previous container: this Pod has not restarted."
      fi
      ui_rule
      ui_pause
      return 0
      ;;
    *) return 0 ;;
  esac
  ui_rule
  kubectl -n "$NAMESPACE" logs "$pod" --tail="$lines" 2>&1 | redact_stream ||
    true
  ui_rule
  ui_pause
}

# `kubectl logs -f` ends only when it is interrupted, which needs two things the
# rest of the manager does not do. The kubectl wrapper buffers output to a file
# and prints it when the command finishes, so following through it would show
# nothing at all -- hence `command kubectl` here. And Ctrl-C reaches the whole
# foreground process group, so the session's own INT trap would exit the manager
# along with kubectl; absorb the signal for the duration instead, then restore
# the real traps.
follow_logs() {
  local pod="$1"
  ui_rule
  ui_detail "Following $pod — press Ctrl-C to stop"
  trap ':' INT
  command kubectl --context "$SELECTED_CONTEXT" -n "$NAMESPACE" logs "$pod" \
    -f --tail=20 2>&1 | redact_stream || true
  install_signal_traps
  ui_rule
  ui_info "⏹️ Stopped following."
  ui_pause
}

# Listing backups is a round trip, and the ready menu does it on every redraw
# just to decide whether to offer Restore -- which is why coming back from a
# submenu paused. Cache it for the session and drop the cache whenever the set
# of backups changes.
config_backups() {
  local file="" result
  [ -n "$SESSION_CACHE_DIR" ] && file="$SESSION_CACHE_DIR/config-backups"
  if [ -n "$file" ] && [ -f "$file" ]; then
    cat "$file"
    return 0
  fi
  result=$(config_backups_uncached)
  cache_list "$file" "$result"
  printf '%s' "$result"
  [ -n "$result" ] && printf '\n'
  return 0
}

# One newline-terminated line per entry, or an empty file: `cat` then reproduces
# exactly what the uncached path emits, so a cache hit and a miss are read the
# same way.
cache_list() {
  local file="$1" result="$2"
  [ -n "$file" ] || return 0
  if [ -n "$result" ]; then
    printf '%s\n' "$result" >"$file" 2>/dev/null || true
  else
    : >"$file" 2>/dev/null || true
  fi
  return 0
}

invalidate_config_backups() {
  [ -n "$SESSION_CACHE_DIR" ] &&
    rm -f "$SESSION_CACHE_DIR/config-backups" 2>/dev/null
  return 0
}

config_backups_detailed() {
  kubectl -n "$NAMESPACE" get secrets \
    -o "jsonpath={range .items[?(@.metadata.labels.app\\.kubernetes\\.io/managed-by=='kwatch.sh')]}{.metadata.name}{\"|\"}{.metadata.creationTimestamp}{\"\n\"}{end}" \
    2>/dev/null | grep "^${RELEASE}-config-[0-9]" | sort -r || true
}

config_backups_uncached() {
  kubectl -n "$NAMESPACE" get secrets \
    -o "jsonpath={range .items[?(@.metadata.labels.app\\.kubernetes\\.io/managed-by=='kwatch.sh')]}{.metadata.name}{\"\n\"}{end}" \
    2>/dev/null | grep "^${RELEASE}-config-[0-9]" | sort -r || true
}

# Every upgrade writes a backup Secret and nothing removed them, so a
# long-lived installation accumulated one per upgrade for ever.
prune_config_backups() {
  local keep="${KWATCH_BACKUP_KEEP:-5}" name index=0 kept=""
  local file="" pruned_all=true
  [[ "$keep" =~ ^[0-9]+$ ]] || keep=5
  # Read past the cache: a backup was just written, and pruning the previous
  # list would keep one too many.
  invalidate_config_backups
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    index=$((index + 1))
    if [ "$index" -gt "$keep" ]; then
      # A delete that did not happen leaves a backup the seeded list would deny
      # exists, so fall back to clearing the cache rather than describing the
      # cluster wrongly.
      kubectl -n "$NAMESPACE" delete secret "$name" --ignore-not-found \
        >/dev/null 2>&1 || pruned_all=false
      continue
    fi
    if [ -n "$kept" ]; then
      kept="$kept
$name"
    else
      kept="$name"
    fi
  done < <(config_backups)
  # The survivors are already known, so seed the cache with them instead of
  # clearing it: the menu drawn next would otherwise re-list every Secret just
  # to decide whether to offer Restore.
  if [ "$pruned_all" != true ]; then
    invalidate_config_backups
    return 0
  fi
  [ -n "$SESSION_CACHE_DIR" ] && file="$SESSION_CACHE_DIR/config-backups"
  cache_list "$file" "$kept"
  return 0
}

# Restoring used to be reachable only as the automatic rollback after a failed
# upgrade, so an unwanted but successful configuration change could not be
# undone from the manager.
restore_flow() {
  local name created choice
  local -a names=() labels=()
  ui_busy "Reading configuration backups"
  while IFS='|' read -r name created; do
    [ -n "$name" ] || continue
    names+=("$name")
    labels+=("$name  ${UI_DIM}${created:-unknown}${UI_RESET}")
  done < <(config_backups_detailed)
  ui_busy_done
  if [ "${#names[@]}" -eq 0 ]; then
    ui_warn "⚠️ No configuration backups were found in namespace $NAMESPACE."
    ui_detail "Backups are created automatically before each upgrade."
    MENU_READ_ONLY=true
    return 0
  fi
  ui_heading "♻️   Restore a previous configuration"
  ui_detail "Newest first. The current configuration is replaced, then kwatch restarts."
  labels+=("↩️  Back")
  choice=$(ui_select 0 "${labels[@]}") || choice="${#names[@]}"
  if [ "$choice" -ge "${#names[@]}" ]; then
    ui_info "↩️ Restore cancelled; nothing was changed."
    MENU_READ_ONLY=true
    return 0
  fi
  confirm_repair \
    "restore the configuration saved in ${names[$choice]}" \
    "The current KwatchConfig is replaced by the saved one and kwatch is restarted. Notification Secrets are not changed." ||
    {
      ui_info "↩️ Restore cancelled; nothing was changed."
      MENU_READ_ONLY=true
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
  local purge="${1:-false}"
  [ "$purge" = true ] && check_access delete persistentvolumeclaims namespace
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
    "$FEATURE_CATALOG_CACHE_NAME" "$PROVIDER_CATALOG_CACHE_NAME" \
    "$DEPLOYMENT_OVERRIDES_CONFIGMAP_NAME" \
    "$LEGACY_OVERRIDES_CONFIGMAP_NAME"; do
    [ -n "$name" ] || continue
    kubectl -n "$NAMESPACE" delete configmap "$name" --ignore-not-found \
      >/dev/null 2>&1 || true
  done
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    kubectl -n "$NAMESPACE" delete secret "$name" --ignore-not-found \
      >/dev/null 2>&1 || true
  done < <(config_backups)
  invalidate_config_backups
  kubectl -n "$NAMESPACE" delete kwatchconfig "$RELEASE" --ignore-not-found \
    >/dev/null 2>&1 || true
  # The state volume: incident history, change timeline and the outbox.
  delete_owned namespace persistentvolumeclaim "${RELEASE}-data"
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
      "⚠️ This removes the workload, the configuration resource, every configuration backup, the cached catalogs, and the state volume (incident history)."
    ui_detail "The namespace and the CRD are preserved."
  else
    ui_warn \
      "⚠️ This removes the kwatch workload and its manager-owned configuration Secret."
    ui_detail "KwatchConfig, backups, the state volume, namespace, and CRD are preserved."
  fi
  confirm=$(ask "Type uninstall to remove kwatch" "") || exit_expected
  [ "$confirm" = uninstall ] || { ui_warn "↩️ Cancelled."; return; }
  ui_busy "Checking uninstall permissions"
  preflight_uninstall_access "$purge"
  ui_busy_done
  # The Pod is needed to release the key, so this comes before the workload goes.
  license_release_before_uninstall
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
  license_delete_after_uninstall
  if [ "$purge" = true ]; then
    with_loading "Removing manager data" purge_manager_data
  fi
  clear_managed_namespace_labels
  if [ "$purge" = true ]; then
    ui_success \
      "✅ kwatch removed, along with its configuration, backups, cached catalogs, and state volume. The namespace and CRD remain."
  else
    ui_success \
      "✅ kwatch workload removed. KwatchConfig, backups, the state volume, namespace, and CRD remain."
  fi
}

# ---------------------------------------------------------------------------
# License / Pro
#
# The Community edition is free; Pro is unlocked by a license key (one key, one
# cluster). The key lives in a Secret named after the release and reaches the
# kwatch container as KWATCH_LICENSE_KEY through a secretKeyRef, so it is never
# written into the Deployment itself. The wiring is recorded as a `license=1`
# entry among the Deployment overrides, which is how an upgrade -- the manifest
# is downloaded fresh every time -- keeps it.
# ---------------------------------------------------------------------------
LICENSE_SIGNUP_URL="https://kwatch.dev/signup?src=installer"
LICENSE_ACCOUNT_URL="https://kwatch.dev/account"
LICENSE_ENV_NAME="KWATCH_LICENSE_KEY"
LICENSE_SECRET_KEY="license-key"
# kwatch's own per-install record. It is not named after the release because
# kwatch, not this script, owns it. Never backed up or restored: see
# backup_config.
LICENSE_INSTANCE_SECRET="kwatch-license-instance"
LICENSE_HEALTH_PORT=8060
LICENSE_FLOW_CHANGED=false
LICENSE_COMMUNITY_CACHE=""
LICENSE_PAYLOAD=""
LICENSE_PLAN=""
LICENSE_EXP=""
LICENSE_DAYS_LEFT=""

license_secret_name() { printf '%s-license' "$RELEASE"; }

# The badge features_flow draws next to Pro capabilities.
pro_badge() { printf '%sPRO%s' "$UI_YELLOW" "$UI_RESET"; }

license_now() { date +%s; }
license_have_jq() { command -v jq >/dev/null 2>&1; }

# The key is a credential: only the last six characters are ever shown.
license_mask() {
  local key="$1"
  if [ "${#key}" -le 10 ]; then
    printf 'KW1-…'
  else
    printf 'KW1-…%s' "${key: -6}"
  fi
}

# base64url without padding -> bytes. Restores the alphabet and the padding
# that the standard decoder insists on.
base64url_decode() {
  local text="${1//-/+}" out
  text="${text//_//}"
  case $((${#text} % 4)) in
    1) return 1 ;;
    2) text="$text==" ;;
    3) text="$text=" ;;
  esac
  out=$(printf '%s' "$text" | base64 -d 2>/dev/null) ||
    out=$(printf '%s' "$text" | base64 --decode 2>/dev/null) ||
    out=$(printf '%s' "$text" | base64 -D 2>/dev/null) || return 1
  printf '%s' "$out"
}

# Prints the decoded payload JSON of KW1-<payload>.<signature>. The signature is
# only checked for being present: verifying it is kwatch's job, not this
# script's.
license_payload_json() {
  local key="$1" body payload signature json
  case "$key" in
    KW1-*) ;;
    *) return 1 ;;
  esac
  body="${key#KW1-}"
  case "$body" in
    *.*.*|.*|*.|*[!A-Za-z0-9_.=-]*) return 1 ;;
    *.*) ;;
    *) return 1 ;;
  esac
  payload="${body%%.*}"
  signature="${body#*.}"
  [ -n "$payload" ] && [ -n "$signature" ] || return 1
  json=$(base64url_decode "$payload") || return 1
  case "$json" in
    \{*\}) ;;
    *) return 1 ;;
  esac
  printf '%s' "$json"
}

# One field of a flat JSON object: jq when it is installed, sed otherwise.
license_json_field() {
  local json="$1" field="$2"
  if license_have_jq; then
    printf '%s' "$json" | jq -r --arg f "$field" '.[$f] // empty' 2>/dev/null
  else
    printf '%s' "$json" | sed -n \
      "s/.*\"$field\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\",}]*\)\"\{0,1\}.*/\1/p" |
      head -1
  fi
}

license_date() {
  date -u -r "$1" +%Y-%m-%d 2>/dev/null ||
    date -u -d "@$1" +%Y-%m-%d 2>/dev/null || printf '%s' "$1"
}

# Decodes the key into LICENSE_PLAN, LICENSE_EXP and LICENSE_DAYS_LEFT.
# Returns 0 when usable, 1 when it is not a key at all, 2 when it has expired.
license_inspect() {
  local key="$1" now
  LICENSE_PAYLOAD=""
  LICENSE_PLAN=""
  LICENSE_EXP=""
  LICENSE_DAYS_LEFT=""
  LICENSE_PAYLOAD=$(license_payload_json "$key") || return 1
  LICENSE_PLAN=$(license_json_field "$LICENSE_PAYLOAD" plan || true)
  # Every license, the legacy "trial" plan included, is Pro to the operator.
  case "$LICENSE_PLAN" in trial|pro) LICENSE_PLAN="Pro" ;; esac
  LICENSE_EXP=$(license_json_field "$LICENSE_PAYLOAD" exp || true)
  [[ "$LICENSE_EXP" =~ ^[0-9]+$ ]] || return 1
  now=$(license_now)
  LICENSE_DAYS_LEFT=$(((LICENSE_EXP - now) / 86400))
  [ "$LICENSE_EXP" -gt "$now" ] || return 2
  return 0
}

license_report_key() {
  local key="$1" rc=0
  license_inspect "$key" || rc=$?
  case "$rc" in
    0)
      ui_success "✅ Key accepted: plan ${LICENSE_PLAN:-unknown}, ${LICENSE_DAYS_LEFT} days left (expires $(license_date "$LICENSE_EXP"))."
      ;;
    1)
      ui_error "❌ That is not a kwatch license key (expected KW1-<payload>.<signature>)."
      ;;
    2)
      ui_warn "⚠️ This license key expired on $(license_date "$LICENSE_EXP")."
      ;;
  esac
  return "$rc"
}

license_secret_exists() {
  [ -n "$(kubectl -n "$NAMESPACE" get secret "$(license_secret_name)" \
    --ignore-not-found -o name 2>/dev/null || true)" ]
}

# Prints the stored key, or nothing and a failure when there is none.
license_current_key() {
  local encoded key
  encoded=$(secret_data_base64 "$(license_secret_name)" "$LICENSE_SECRET_KEY")
  [ -n "$encoded" ] || return 1
  key=$(printf '%s' "$encoded" | base64 -d 2>/dev/null ||
    printf '%s' "$encoded" | base64 --decode 2>/dev/null ||
    printf '%s' "$encoded" | base64 -D 2>/dev/null) || return 1
  [ -n "$key" ] || return 1
  printf '%s' "$key"
}

# The first kwatch Pod, or nothing and a failure.
kwatch_pod_name() {
  local pod
  pod=$(kubectl -n "$NAMESPACE" get pods -l "$(workload_selector)" \
    -o 'jsonpath={.items[0].metadata.name}' 2>/dev/null || true)
  [ -n "$pod" ] || return 1
  printf '%s' "$pod"
}

# The text kwatch serves on /status, read through the API server's Pod proxy so
# nothing has to be installed in the (read-only, minimal) container. kwatch
# serves /status only with healthCheck.statusEndpoint: true (default false).
kwatch_status_proxy() {
  local pod
  pod=$(kwatch_pod_name) || return 1
  kubectl get --raw \
    "/api/v1/namespaces/$NAMESPACE/pods/$pod:$LICENSE_HEALTH_PORT/proxy/status" \
    --request-timeout=10s 2>/dev/null
}

# Fallback when /status is off: `kwatch license status` run in the Pod.
kwatch_status_exec() {
  local pod
  pod=$(kwatch_pod_name) || return 1
  kubectl -n "$NAMESPACE" exec "$pod" -- kwatch license status 2>/dev/null
}

# Turns the output of `kwatch license status` (internal/app/license_cli.go) into
# the Edition and License lines of /status. The command prints "Key:", "State:",
# "Plan:", "License:" and "Expires:" lines, or one "No license key is
# configured: kwatch runs the Community edition." line. State is a local check
# of the key (valid key, expired or invalid), not the activation.
kwatch_license_cli_to_status() {
  local text="$1" state plan
  if grep -qi '^No license key is configured' <<<"$text"; then
    printf 'Edition: Community\nLicense: community\n'
    return 0
  fi
  state=$(printf '%s\n' "$text" | sed -n 's/^State:[[:space:]]*//p' | head -1)
  [ -n "$state" ] || return 1
  plan=$(printf '%s\n' "$text" | sed -n 's/^Plan:[[:space:]]*//p' | head -1)
  case "$state" in
    valid*) printf 'Edition: %s\n' "${plan:-unknown}" ;;
    *) printf 'Edition: Community\n' ;;
  esac
  printf 'License: %s\n' "$state"
}

# The /status text, or the same lines rebuilt from `kwatch license status`
# when /status is off. Fails when neither answers.
kwatch_status_text() {
  local text
  text=$(kwatch_status_proxy || true)
  if [ -n "$text" ]; then
    printf '%s\n' "$text"
    return 0
  fi
  text=$(kwatch_status_exec || true)
  [ -n "$text" ] || return 1
  kwatch_license_cli_to_status "$text"
}

LICENSE_STATUS_UNAVAILABLE="license state unavailable (enable healthCheck.statusEndpoint for full status)"

# The Edition and License lines of a /status text.
license_status_lines() {
  printf '%s\n' "$1" | grep -iE '^[[:space:]]*(Edition|License)[^:]*:' || true
}

license_inactive_line() {
  printf '%s\n' "$1" |
    grep -i 'Pro features configured but inactive:' | head -1 || true
}

# community, invalid, pending, active, grace, expired, revoked or conflict.
# The troublesome ones come first so "expired (was active)" reads as expired.
license_state_word() {
  local lower word
  lower=$(printf ' %s ' "$1" | tr '[:upper:]' '[:lower:]')
  for word in conflict revoked expired invalid grace pending active community; do
    case "$lower" in
      *[!a-z]"$word"[!a-z]*) printf '%s' "$word"; return 0 ;;
    esac
  done
  return 1
}

license_state_hint() {
  case "$1" in
    conflict) printf 'license is bound to another cluster — choose "Move license to this cluster" in License / Pro, or transfer it at %s' "$LICENSE_ACCOUNT_URL" ;;
    grace) printf 'kwatch could not verify the license recently; Pro keeps working for now — check egress or renew at %s' "$LICENSE_ACCOUNT_URL" ;;
    expired) printf 'the license has expired and Pro features are off — renew it at %s' "$LICENSE_ACCOUNT_URL" ;;
    revoked) printf 'the license was revoked — manage it at %s' "$LICENSE_ACCOUNT_URL" ;;
    invalid) printf 'kwatch rejected the key — replace it from License / Pro in the menu' ;;
    *) return 1 ;;
  esac
}

# Prints the edition and license lines of a /status text, and calls out the
# states that need attention.
license_print_status() {
  local text="$1" lines inactive word hint line
  lines=$(license_status_lines "$text")
  inactive=$(license_inactive_line "$text")
  [ -n "$lines$inactive" ] || return 1
  word=$(license_state_word "$lines" || true)
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    line="${line#"${line%%[![:space:]]*}"}"
    case "$word" in
      grace|expired|conflict|revoked|invalid) ui_warn "  🎫 $line" ;;
      *) ui_detail "  🎫 $line" ;;
    esac
  done <<<"$lines"
  if hint=$(license_state_hint "$word" 2>/dev/null); then
    ui_warn "     ↳ $hint"
  fi
  if [ -n "$inactive" ]; then
    inactive="${inactive#"${inactive%%[![:space:]]*}"}"
    ui_warn "  🔒 $inactive"
  fi
  return 0
}

license_status_section() {
  local text
  text=$(kwatch_status_text || true)
  if [ -z "$text" ] || ! license_print_status "$text"; then
    ui_detail "  $LICENSE_STATUS_UNAVAILABLE"
  fi
}

# community | other | "" (unknown), from the Edition line of /status.
license_edition() {
  local line
  line=$(kwatch_status_text 2>/dev/null |
    grep -iE '^[[:space:]]*Edition[^:]*:' | head -1 || true)
  [ -n "$line" ] || return 0
  case "$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')" in
    *community*) printf 'community' ;;
    *) printf 'other' ;;
  esac
}

# Community when /status says so; with no answer, when no key was ever added.
license_is_community() {
  case "$LICENSE_COMMUNITY_CACHE" in
    yes) return 0 ;;
    no) return 1 ;;
  esac
  case "$(license_edition)" in
    community) LICENSE_COMMUNITY_CACHE=yes; return 0 ;;
    other) LICENSE_COMMUNITY_CACHE=no; return 1 ;;
  esac
  if license_secret_exists; then
    LICENSE_COMMUNITY_CACHE=no
    return 1
  fi
  LICENSE_COMMUNITY_CACHE=yes
  return 0
}

community_provider_cap_message() {
  printf 'Community sends to 1 provider — extra providers stay inactive until you add a Pro license (free during early access: %s)' \
    "$LICENSE_SIGNUP_URL"
}

# Called when a provider is being added to a configuration that already has
# one. Saving is still allowed: the extra providers simply stay inactive.
warn_community_provider_cap() {
  license_is_community || return 0
  ui_warn "⚠️ $(community_provider_cap_message)"
  return 0
}

# Pro-only settings, matched on the path itself or anything beneath it.
config_path_is_pro() {
  local top="${1%%.*}"
  case "$top" in
    routes|routing|templates|severityByReason|severityByOwnerKind|maintenance|\
    runbooks|auditLog|heartbeatMonitor|activeProbeMonitor|namespaceSelector|\
    reasons) return 0 ;;
  esac
  return 1
}

# DEPLOYMENT_OVERRIDES without the license marker: what the sizing screens mean
# by "recorded".
overrides_without_license() {
  local entry kept=""
  local IFS=';'
  for entry in $DEPLOYMENT_OVERRIDES; do
    [ -n "$entry" ] || continue
    [ "$entry" = license=1 ] && continue
    kept="${kept:+$kept;}$entry"
  done
  printf '%s' "$kept"
}

# Adds (on) or drops (off) the license marker in DEPLOYMENT_OVERRIDES.
license_overrides_set() {
  local state="$1" kept
  kept=$(overrides_without_license)
  if [ "$state" = on ]; then
    kept="${kept:+$kept;}license=1"
  fi
  DEPLOYMENT_OVERRIDES="$kept"
}

# The container's env var, as the Deployment should carry it.
license_env_patch() {
  local container="$1" mode="${2:-set}" name
  name=$(license_secret_name)
  printf '{"spec":{"template":{"spec":{"containers":[{"name":"%s","env":[' "$container"
  if [ "$mode" = remove ]; then
    # shellcheck disable=SC2016  # "$patch" is the literal merge directive
    printf '{"name":"%s","$patch":"delete"}' "$LICENSE_ENV_NAME"
  else
    printf '{"name":"%s","value":null,"valueFrom":{"secretKeyRef":{"name":"%s","key":"%s","optional":true}}}' \
      "$LICENSE_ENV_NAME" "$name" "$LICENSE_SECRET_KEY"
  fi
  printf ']}]}}}}'
}

kwatch_container_name() {
  local deployment="$1" names name
  names=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={range .spec.template.spec.containers[*]}{.name}{"\n"}{end}' \
    2>/dev/null || true)
  while IFS= read -r name; do
    if [ "$name" = "$RELEASE" ] || [ "$name" = kwatch ]; then
      printf '%s' "$name"
      return 0
    fi
  done <<<"$names"
  return 1
}

# True when the Deployment already reads the key from this release's Secret.
license_env_wired() {
  local deployment="$1" current
  current=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o "jsonpath={.spec.template.spec.containers[*].env[?(@.name==\"$LICENSE_ENV_NAME\")].valueFrom.secretKeyRef.name}" \
    2>/dev/null || true)
  [ "$current" = "$(license_secret_name)" ]
}

# Puts KWATCH_LICENSE_KEY (from the Secret, optional) into the manifest. The
# Secret is optional so a Pod still starts, as Community, if the key is gone.
inject_license_env_into_manifest() {
  local manifest="$1" rewritten header=false
  grep -q "name: $LICENSE_ENV_NAME\$" "$manifest" && return 0
  grep -q '^        env:$' "$manifest" || header=true
  rewritten=$(mktemp) || return 1
  if ! KWATCH_LICENSE_SECRET="$(license_secret_name)" \
    KWATCH_LICENSE_ENV="$LICENSE_ENV_NAME" \
    KWATCH_LICENSE_KEYNAME="$LICENSE_SECRET_KEY" \
    KWATCH_ENV_HEADER="$header" awk '
    function emit() {
      printf "          - name: %s\n", ENVIRON["KWATCH_LICENSE_ENV"]
      print "            valueFrom:"
      print "              secretKeyRef:"
      printf "                name: %s\n", ENVIRON["KWATCH_LICENSE_SECRET"]
      printf "                key: %s\n", ENVIRON["KWATCH_LICENSE_KEYNAME"]
      print "                optional: true"
    }
    ENVIRON["KWATCH_ENV_HEADER"] == "false" && /^        env:$/ && done == 0 {
      print; emit(); done = 1; next
    }
    ENVIRON["KWATCH_ENV_HEADER"] == "true" && /^        image:/ && done == 0 {
      print; print "        env:"; emit(); done = 1; next
    }
    { print }
  ' "$manifest" >"$rewritten" ||
    ! grep -q "name: $LICENSE_ENV_NAME\$" "$rewritten"; then
    rm -f "$rewritten"
    return 1
  fi
  mv "$rewritten" "$manifest" || { rm -f "$rewritten"; return 1; }
}

# Create or update the license Secret.
license_store_secret() {
  local key="$1" name tmp
  name=$(license_secret_name)
  tmp=$(mktemp) || return 1
  chmod 600 "$tmp"
  printf '%s' "$key" >"$tmp"
  if ! kubectl -n "$NAMESPACE" create secret generic "$name" \
    --from-file="$LICENSE_SECRET_KEY=$tmp" --dry-run=client -o yaml |
    kubectl apply -f - >/dev/null; then
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"
  kubectl -n "$NAMESPACE" label secret "$name" \
    app.kubernetes.io/instance="$RELEASE" \
    app.kubernetes.io/managed-by=kwatch.sh --overwrite >/dev/null 2>&1 || true
}

license_wire_env() {
  local deployment="$1" container
  license_env_wired "$deployment" && return 0
  container=$(kwatch_container_name "$deployment") || container=kwatch
  kubectl -n "$NAMESPACE" patch deployment "$deployment" --type=strategic \
    -p "$(license_env_patch "$container")" >/dev/null
}

# The license Role, RoleBinding and instance Secret. Installs older than
# licensing lack them and kwatch cannot keep its instance key without them.
# Anything missing is created; anything present is left alone (the Secret in
# particular holds kwatch's key and is never rewritten).
license_ensure_instance_access() {
  local deployment="$1" sa role
  role=$(license_secret_name)
  sa=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.serviceAccountName}' 2>/dev/null || true)
  [ -n "$sa" ] || sa="$RELEASE"
  if ! kubectl -n "$NAMESPACE" get role "$role" >/dev/null 2>&1; then
    kubectl -n "$NAMESPACE" apply -f - >/dev/null <<EOF || return 1
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: $role
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/instance: $RELEASE
    app.kubernetes.io/managed-by: kwatch.sh
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["$LICENSE_INSTANCE_SECRET"]
  verbs: ["get", "update"]
EOF
  fi
  if ! kubectl -n "$NAMESPACE" get rolebinding "$role" >/dev/null 2>&1; then
    kubectl -n "$NAMESPACE" apply -f - >/dev/null <<EOF || return 1
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $role
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/instance: $RELEASE
    app.kubernetes.io/managed-by: kwatch.sh
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: $role
subjects:
- kind: ServiceAccount
  name: $sa
  namespace: $NAMESPACE
EOF
  fi
  if ! kubectl -n "$NAMESPACE" get secret "$LICENSE_INSTANCE_SECRET" >/dev/null 2>&1; then
    kubectl -n "$NAMESPACE" create secret generic "$LICENSE_INSTANCE_SECRET" \
      >/dev/null || return 1
    kubectl -n "$NAMESPACE" label secret "$LICENSE_INSTANCE_SECRET" \
      app.kubernetes.io/instance="$RELEASE" \
      app.kubernetes.io/managed-by=kwatch.sh --overwrite >/dev/null 2>&1 || true
  fi
}

license_rollout_incomplete() {
  ui_warn "⚠️ The key is saved and kwatch was told to use it, but the rollout has not finished."
  ui_warn "   Nothing was deleted or repaired. Check the Pod with Status and Logs; the rollout"
  ui_warn "   keeps going on its own, and Remove key restores the previous state."
}

# Stores the key and wires it into kwatch. Mode "record" stops short of touching
# the running workload: the next apply_manifests picks the marker up (used when
# an upgrade is about to apply the manifest anyway).
license_apply_key() {
  local key="$1" mode="${2:-full}" deployment already=false
  with_loading "Saving the license key" license_store_secret "$key" || {
    ui_error "❌ Could not save the license Secret." \
      "$(compact_reason "${LAST_COMMAND_ERROR:-no diagnostic was returned}")"
    return 1
  }
  deployment=$(deployment_name || true)
  deployment_overrides_read
  license_overrides_set on
  if [ -z "$deployment" ] || [ "$mode" = record ]; then
    deployment_overrides_write "${deployment:-$RELEASE}" "$DEPLOYMENT_OVERRIDES" \
      >/dev/null 2>&1 || true
    LICENSE_FLOW_CHANGED=true
    ui_detail "  The key is stored; it is applied with the next install or upgrade."
    return 0
  fi
  with_loading "Checking kwatch's access to its license record" \
    license_ensure_instance_access "$deployment" || {
    ui_error "❌ This install predates licensing and its license RBAC could not be added." \
      "$(compact_reason "${LAST_COMMAND_ERROR:-no diagnostic was returned}")"
    ui_detail "  The key is stored, but kwatch was not changed. Upgrade kwatch from the"
    ui_detail "  menu first (it adds the missing Role, RoleBinding and Secret), then add the key again."
    return 1
  }
  license_env_wired "$deployment" && already=true
  with_loading "Pointing kwatch at the license Secret" \
    license_wire_env "$deployment" || {
    ui_error "❌ Could not add $LICENSE_ENV_NAME to the Deployment." \
      "$(compact_reason "${LAST_COMMAND_ERROR:-no diagnostic was returned}")"
    return 1
  }
  with_loading "Recording the license for future upgrades" \
    deployment_overrides_write "$deployment" "$DEPLOYMENT_OVERRIDES" || {
    ui_warn "⚠️ The key is active, but it could not be recorded;"
    ui_warn "   an upgrade might drop it. Add it again after upgrading."
  }
  LICENSE_FLOW_CHANGED=true
  invalidate_deployment_name
  LICENSE_COMMUNITY_CACHE=""
  # Exactly one rollout. Wiring the env into the Deployment changes the Pod
  # template, which rolls it out by itself; only a key that was already wired
  # (a replaced key) needs the restart. Neither path deletes anything: on a
  # timeout the rollout is left as it is, with its diagnostics shown.
  if [ "$already" = true ]; then
    restart_kwatch || {
      license_rollout_incomplete
      return 1
    }
  else
    with_loading "Waiting for kwatch rollout" \
      wait_for_kwatch_rollout "$deployment" || {
      license_rollout_incomplete
      return 1
    }
  fi
  ui_success "✅ License key applied: $(license_mask "$key")"
}

# The same key supplied through the environment: no prompts. An unusable key is
# reported and skipped rather than failing an install that otherwise worked.
license_apply_from_env() {
  local mode="${1:-full}" key="${KWATCH_LICENSE_KEY:-}" rc=0
  key="${key//[[:space:]]/}"
  [ -n "$key" ] || return 0
  ui_info "🔑 Applying $LICENSE_ENV_NAME ($(license_mask "$key"))"
  license_report_key "$key" || rc=$?
  if [ "$rc" -ne 0 ]; then
    ui_warn "⚠️ Skipping the license key from $LICENSE_ENV_NAME."
    return 0
  fi
  license_apply_key "$key" "$mode" ||
    ui_warn "⚠️ The license key could not be applied; add it from License / Pro."
}

# The last step of an install.
license_install_prompt() {
  local key rc=0
  if [ -n "${KWATCH_LICENSE_KEY:-}" ]; then
    license_apply_from_env full
    return 0
  fi
  license_secret_exists && return 0
  key=$(ask_secret "🔑 Have a Pro license key? (Enter to skip)") ||
    exit_expected
  key="${key//[[:space:]]/}"
  if [ -z "$key" ]; then
    ui_detail "  Get a free Pro license: $LICENSE_SIGNUP_URL"
    return 0
  fi
  license_report_key "$key" || rc=$?
  if [ "$rc" -eq 1 ]; then
    ui_detail "  Add it later from License / Pro in the menu."
    return 0
  fi
  if [ "$rc" -eq 2 ]; then
    confirm_action "Use the expired key anyway" "n" || return 0
  fi
  license_apply_key "$key" full ||
    ui_warn "⚠️ The license key could not be applied; add it from License / Pro."
}

license_show_status() {
  local key text
  ui_screen "license"
  if key=$(license_current_key); then
    ui_kv "🔑" "Key" "$(license_mask "$key")"
    local rc=0
    license_inspect "$key" || rc=$?
    if [ "$rc" -eq 1 ]; then
      ui_warn "⚠️ The stored key does not decode as a kwatch license key."
    else
      ui_kv "🎟️" "Plan" "${LICENSE_PLAN:-unknown}"
      if [ "$rc" -eq 2 ]; then
        ui_warn "  ⌛ Expired on $(license_date "$LICENSE_EXP")"
      else
        ui_kv "⏳" "Days left" "$LICENSE_DAYS_LEFT (expires $(license_date "$LICENSE_EXP"))"
      fi
    fi
  else
    ui_detail "  No license key is configured: this is the Community edition."
    ui_detail "  Get a free Pro license: $LICENSE_SIGNUP_URL"
  fi
  printf '\n' >&2
  text=$(kwatch_status_text || true)
  if [ -z "$text" ] || ! license_print_status "$text"; then
    ui_detail "  $LICENSE_STATUS_UNAVAILABLE"
  fi
}

license_add_flow() {
  local key rc=0
  ui_heading "🔑  Add or replace the license key"
  license_secret_exists || ui_detail "  No key yet? Get a free Pro license: $LICENSE_SIGNUP_URL"
  key=$(ask_secret_or_back "Pro license key") || {
    ui_info "↩️ Nothing was changed."
    return 0
  }
  key="${key//[[:space:]]/}"
  [ -n "$key" ] || { ui_info "↩️ Nothing was changed."; return 0; }
  license_report_key "$key" || rc=$?
  [ "$rc" -ne 1 ] || return 0
  if [ "$rc" -eq 2 ]; then
    confirm_action "Save the expired key anyway" "n" || {
      ui_info "↩️ Nothing was changed."
      return 0
    }
  fi
  check_access patch deployments namespace
  license_apply_key "$key" full ||
    ui_error "❌ The license key was not fully applied."
}

license_remove_flow() {
  local deployment container name
  ui_heading "🗑️  Remove the license key"
  name=$(license_secret_name)
  if ! license_secret_exists; then
    ui_detail "  No license key is configured."
    ui_detail "  Get a free Pro license: $LICENSE_SIGNUP_URL"
    return 0
  fi
  confirm_change "🗑️ Remove the license key and return to Community." \
    "The Secret $name and the $LICENSE_ENV_NAME setting are deleted and kwatch restarts. To use the key on another cluster, release it first (uninstall offers this)." ||
    { ui_info "↩️ Nothing was changed."; return 0; }
  deployment=$(deployment_name || true)
  deployment_overrides_read
  license_overrides_set off
  if [ -n "$deployment" ]; then
    container=$(kwatch_container_name "$deployment") || container=kwatch
    with_loading "Removing $LICENSE_ENV_NAME from the Deployment" \
      kubectl -n "$NAMESPACE" patch deployment "$deployment" --type=strategic \
      -p "$(license_env_patch "$container" remove)" >/dev/null || {
      ui_error "❌ Could not update the Deployment." \
        "$(compact_reason "${LAST_COMMAND_ERROR:-no diagnostic was returned}")"
      return 1
    }
    deployment_overrides_write "$deployment" "$DEPLOYMENT_OVERRIDES" \
      >/dev/null 2>&1 || true
  fi
  kubectl -n "$NAMESPACE" delete secret "$name" --ignore-not-found >/dev/null ||
    ui_warn "⚠️ The Secret $name could not be deleted."
  LICENSE_FLOW_CHANGED=true
  LICENSE_COMMUNITY_CACHE=""
  invalidate_deployment_name
  if [ -n "$deployment" ]; then
    with_loading "Waiting for kwatch rollout" \
      wait_for_kwatch_rollout "$deployment" || return 1
  fi
  ui_success "✅ License key removed; kwatch is running as Community."
}

# Takes the license over from the cluster that holds it. `kwatch license move`
# runs in the Pod: it asks the leader to move and prints the outcome (moved,
# already here, transfer limit reached, invalid key). It can wait up to about
# two minutes for the leader, so its output is shown as it comes.
license_move_flow() {
  local pod
  ui_heading "🚚  Move the license to this cluster"
  if ! license_secret_exists; then
    ui_detail "  No license key is configured here. Add it first with Add or replace key."
    return 0
  fi
  confirm_change "🚚 Move the license to this cluster." \
    "The cluster that holds it now drops to Community at its next daily check. A license can move 3 times in 30 days." ||
    { ui_info "↩️ Nothing was changed."; return 0; }
  pod=$(kwatch_pod_name) || {
    ui_error "❌ No kwatch Pod was found in $NAMESPACE; wait for kwatch to start and try again."
    return 1
  }
  ui_info "⏳ Asking kwatch to move the license (this can take up to 2 minutes)"
  LICENSE_COMMUNITY_CACHE=""
  if ! kubectl -n "$NAMESPACE" exec "$pod" -- kwatch license move; then
    ui_warn "⚠️ The license was not moved. You can also transfer it at $LICENSE_ACCOUNT_URL"
    return 1
  fi
}

# Cluster check-ins: whether the Pod pings api.kwatch.dev every 30 minutes so
# app.kwatch.dev can show the cluster as silent. Stored in the KwatchConfig
# (spec.clusterCheckins, default on) so upgrades keep it.
CHECKINS_CONFIG_PATH="clusterCheckins"

checkins_state() {
  case "$(config_value "$CHECKINS_CONFIG_PATH")" in
    false) printf 'off' ;;
    *) printf 'on' ;;
  esac
}

checkins_flow() {
  local state choice target reason
  ui_heading "Cluster check-ins"
  ui_detail "  kwatch checks in with api.kwatch.dev every 30 minutes. If it goes quiet"
  ui_detail "  for 60 minutes, app.kwatch.dev shows this cluster as silent."
  ui_detail "  Nothing is sent to you. Sent: a random or hashed installation ID, the kwatch version,"
  ui_detail "  the node count and the cluster name if you set one."
  state=$(checkins_state)
  if [ "$state" = on ]; then
    choice=$(ui_select 0 "Turn off" "Back") || return 0
    target=false
  else
    choice=$(ui_select 0 "Turn on" "Back") || return 0
    target=true
  fi
  [ "$choice" = 0 ] || return 0
  if reason=$(patch_config_value "$CHECKINS_CONFIG_PATH" boolean "$target" 2>&1); then
    LICENSE_FLOW_CHANGED=true
    if [ "$target" = true ]; then
      ui_success "Cluster check-ins are on. The first check-in follows within 30 minutes."
    else
      ui_success "Cluster check-ins are off."
      ui_detail "  If the final check-in cannot reach api.kwatch.dev, app.kwatch.dev shows this"
      ui_detail "  cluster as silent until the key is removed or moved."
    fi
  else
    ui_error "Could not change Cluster check-ins: $(compact_reason "${reason:-no diagnostic was returned}"). Nothing was changed. Run the installer again after fixing it."
  fi
}

# Runs `kwatch test-alert` in the Pod through the live delivery path.
testalert_flow() {
  local selector pod rc=0 out status=0 count choice
  local -a args=() names=()
  ui_screen "test alert"
  selector=$(workload_selector)
  ui_busy "Finding the kwatch Pod"
  pod=$(select_workload_pod "$selector") || rc="$?"
  ui_busy_done
  [ "${rc:-0}" -ne 2 ] || return 0
  if [ -z "$pod" ]; then
    ui_warn "No kwatch Pod was found in namespace $NAMESPACE. Install or repair kwatch first."
    ui_pause
    return 0
  fi
  if [ "$(kubectl -n "$NAMESPACE" get pod "$pod" \
    -o 'jsonpath={.status.containerStatuses[0].ready}' 2>/dev/null || true)" != true ]; then
    ui_warn "The kwatch Pod is not ready yet. Wait a minute, or choose View status."
    ui_pause
    return 0
  fi
  # `--provider ?` prints the configured provider names, one per line.
  while IFS= read -r name; do
    name="${name//[[:space:]]/}"
    [ -n "$name" ] && names+=("$name")
  done < <(kubectl -n "$NAMESPACE" exec "$pod" -- kwatch test-alert --provider "?" 2>/dev/null || true)
  count=${#names[@]}
  if [ "$count" -gt 1 ]; then
    choice=$(ui_select 0 "All providers" "${names[@]}") || return 0
    [ "$choice" = 0 ] || args=(--provider "${names[$((choice - 1))]}")
  fi
  ui_busy "Sending the test alert"
  out=$(kubectl -n "$NAMESPACE" exec "$pod" -- kwatch test-alert --from installer ${args[@]+"${args[@]}"} 2>&1) || status=$?
  ui_busy_done
  if printf '%s' "$out" | grep -qi 'unknown command'; then
    ui_warn "This kwatch version does not have test-alert yet. Choose Upgrade kwatch, then try again."
  else
    printf '%s\n' "$out" | redact_stream >&2
  fi
  ui_pause
  return 0
}

# ---- Save diagnostics to file ------------------------------------------------
# Collects on this machine with kubectl, redacts, asks, and writes one archive.
# Nothing is uploaded. No Secret is read.

DIAG_WORK=""
DIAG_MAX_BYTES=$((10 * 1024 * 1024))

diag_text_redact() {
  sed -E 's#https?://[^[:space:]"'"'"')]+#<url>#g;
    s#[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}#<email>#g;
    s#KW1-[A-Za-z0-9_-]+#<redacted>#g;
    s#([0-9]{1,3}\.){3}[0-9]{1,3}#<ip>#g;
    s#([0-9A-Fa-f]{1,4}:){3,7}[0-9A-Fa-f]{0,4}#<ip>#g;
    s#eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_.-]+#<redacted>#g;
    s#AKIA[0-9A-Z]{16}#<redacted>#g' | redact_stream
}

# Prefer the Pod's own `kwatch redact` (one list for shell and Go); then the
# shell pass on top as a floor.
diag_redact() {
  if [ -n "${DIAG_POD_REDACT:-}" ]; then
    kubectl -n "$NAMESPACE" exec -i "$DIAG_POD" -- kwatch redact 2>/dev/null | diag_text_redact
  else
    diag_text_redact
  fi
}

# Keeps keys, booleans, numbers and a few enum words; every other string is
# <set> or <empty>.
diag_config_allowlist() {
  awk '
    /^spec:/ { on=1; print; next }
    on && /^[^ #]/ { exit }
    on {
      line=$0
      if (match(line, /^[ -]*[A-Za-z0-9_.\/-]+:[ ]+/)) {
        head=substr(line, 1, RLENGTH); val=substr(line, RLENGTH+1)
        if (val ~ /^(true|false|[0-9]+([.][0-9]+)?|debug|info|warn|error|slack|discord|telegram|email|pagerduty|opsgenie|teams|webhook|mattermost|rocketchat|zulip|ntfy|gotify|googlechat|matrix|line|dingtalk|feishu|lark|sns|twilio|pushover|text|json)$/) print line
        else if (val ~ /^(""|'"''"'|\[\]|\{\})$/) print head "<empty>"
        else if (val ~ /^[|>]/) print head "<set>"
        else print head "<set>"
      } else if (match(line, /^[ ]*-[ ]+/)) {
        head=substr(line, 1, RLENGTH); val=substr(line, RLENGTH+1)
        if (val ~ /^(true|false|[0-9]+)$/) print line; else print head "<set>"
      } else if (line ~ /:[ ]*$/) print line
      else if (line ~ /^[ ]+[^ ]/) { match(line, /^[ ]+/); print substr(line, 1, RLENGTH) "<set>" }
    }'
}

diag_deployment_clean() {
  awk '
    /^  managedFields:/ { skip=1; next }
    skip && /^    / { next }
    skip && /^  [^ ]/ { skip=0 }
    /kubectl.kubernetes.io\/last-applied-configuration/ { next }
    { if ($0 ~ /^[ -]*value:[ ]/) { sub(/value:.*/, "value: <set>") } print }'
}

# Final scan: any hit aborts. Prints the offending file name.
diag_scan() {
  local dir="$1" f hit=""
  for f in "$dir"/*; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in README.txt) continue ;; esac
    if sed -E 's#@sha256:[0-9a-f]+##g' "$f" | grep -Eiq \
      'https?://|@|[A-Za-z0-9+/=_-]{41,}|(token|secret|password|key)[[:space:]]*[=:][[:space:]]*[^<[:space:]]'; then
      # Allow plain booleans and numbers after a key name.
      if sed -E 's#@sha256:[0-9a-f]+##g' "$f" | grep -Ei \
        'https?://|@|[A-Za-z0-9+/=_-]{41,}|(token|secret|password|key)[[:space:]]*[=:][[:space:]]*[^<[:space:]]' |
        grep -Eiv '(token|secret|password|key)[[:space:]]*[=:][[:space:]]*(true|false|[0-9]+)[[:space:]]*$' |
        grep -q .; then
        hit=$(basename "$f")
        break
      fi
    fi
  done
  [ -z "$hit" ] || { printf '%s' "$hit"; return 1; }
  return 0
}

diag_kb() {
  local f="$1" bytes
  bytes=$(wc -c <"$f" 2>/dev/null | tr -d ' ')
  printf '%s' $(((${bytes:-0} + 1023) / 1024))
}

diag_cluster_slug() {
  local name slug
  name=$(config_value app.clusterName)
  [ -n "$name" ] || name="$NAMESPACE"
  slug=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' |
    sed -E 's/-+/-/g;s/^-//;s/-$//' | cut -c1-30 | sed -E 's/-$//')
  printf '%s' "${slug:-cluster}"
}

diag_collect() {
  local dir="$1" lines="$2" missing="" err
  local deployment
  mkdir -p "$dir"
  ui_detail "  Status"
  { kwatch_status_text 2>/dev/null || true; } | diag_redact >"$dir/status.txt"
  ui_detail "  Logs"
  if [ -n "$DIAG_POD" ]; then
    kubectl -n "$NAMESPACE" logs "$DIAG_POD" --tail="$lines" 2>&1 | diag_redact >"$dir/logs.txt"
    if kubectl -n "$NAMESPACE" logs "$DIAG_POD" --previous --tail="$lines" >"$dir/.prev" 2>/dev/null; then
      diag_redact <"$dir/.prev" >"$dir/logs-previous.txt"
    fi
    rm -f "$dir/.prev"
  fi
  ui_detail "  Events"
  if err=$(kubectl -n "$NAMESPACE" get events 2>&1 >"$dir/.events"); then
    diag_redact <"$dir/.events" >"$dir/events.txt"
  else
    missing="${missing:+$missing,}\"events\""
    DIAG_NOTES="${DIAG_NOTES}Could not read events ($(compact_reason "$err")). The diagnostics were saved without them.
"
  fi
  rm -f "$dir/.events"
  ui_detail "  Configuration (secrets removed)"
  kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" -o yaml 2>/dev/null |
    diag_config_allowlist >"$dir/config.yaml" || true
  [ -s "$dir/config.yaml" ] || rm -f "$dir/config.yaml"
  if [ -n "$DIAG_POD" ]; then
    kubectl -n "$NAMESPACE" describe pod "$DIAG_POD" 2>/dev/null |
      sed -E 's/^([[:space:]]+[A-Za-z0-9_.-]+):[[:space:]]+.*(<set to the key.*|[^[:space:]]+)$/\1: <set>/' |
      awk '/^    Environment:/ {env=1; print; next} env && /^    [A-Za-z]/ {env=0} env && /^      [A-Za-z_]/ {sub(/:.*/, ": <set>")} {print}' |
      diag_redact >"$dir/pods.txt"
  fi
  deployment=$(deployment_name 2>/dev/null || true)
  if [ -n "$deployment" ]; then
    kubectl -n "$NAMESPACE" get deployment "$deployment" -o yaml 2>/dev/null |
      diag_deployment_clean | diag_redact >"$dir/deployment.yaml"
  fi
  DIAG_MISSING="$missing"
}

diag_write_manifest() {
  local dir="$1" lines="$2" server nodes edition
  server=$(kubectl version -o json 2>/dev/null |
    sed -n '/serverVersion/,$p' | sed -n 's/.*"gitVersion": *"\([^"]*\)".*/\1/p' | head -1)
  nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
  edition=$(kwatch_status_text 2>/dev/null | sed -n 's/^Edition:[[:space:]]*//p' | head -1)
  {
    printf '{\n'
    printf '  "bundle_format": 1,\n'
    printf '  "created_utc": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "installer_catalog": "%s",\n' "$(json_escape "${INSTALL_VERSION:-unknown}")"
    printf '  "edition": "%s",\n' "$(json_escape "${edition:-unknown}")"
    printf '  "kubernetes_server": "%s",\n' "$(json_escape "${server:-unknown}")"
    printf '  "node_count": %s,\n' "${nodes:-0}"
    printf '  "installer_os": "%s",\n' "$(uname -s 2>/dev/null || echo unknown)"
    printf '  "log_lines": %s,\n' "$lines"
    printf '  "kwatch_pod_found": %s,\n' "$([ -n "$DIAG_POD" ] && echo true || echo false)"
    printf '  "missing": [%s]\n' "${DIAG_MISSING:-}"
    printf '}\n'
  } >"$dir/manifest.json"
}

diag_write_readme() {
  cat >"$1/README.txt" <<'README'
kwatch diagnostics

This file was made on your computer by the kwatch installer. kwatch did not
upload it. It holds recent kwatch logs, events from the kwatch namespace, the
kwatch settings with secrets removed, and version information.

Removed: Secrets, your license key, webhook URLs, tokens, e-mail addresses and
IP addresses. Pod names and the namespace name are kept because they are needed
to debug.

Look through it before you send it. Attach it when you reply to our support
email.
README
}

diag_output_dir() {
  if [ -w . ]; then printf '.'; else printf '%s' "$HOME"; fi
}

diagnostics_flow() {
  local selector lines logs_cut=false dir out_dir slug date_s name n=1 file
  local total_kb size choice scan_hit review
  ui_screen "diagnostics"
  command -v kubectl >/dev/null 2>&1 || {
    ui_error "kubectl is needed to collect the diagnostics and could not reach a cluster. Select a cluster first (View status shows which one)."
    ui_pause
    return 0
  }
  if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    ui_error "kubectl is needed to collect the diagnostics and could not reach a cluster. Select a cluster first (View status shows which one)."
    ui_pause
    return 0
  fi
  selector=$(workload_selector)
  DIAG_POD=$(kubectl -n "$NAMESPACE" get pods -l "$selector" \
    -o 'jsonpath={.items[0].metadata.name}' 2>/dev/null || true)
  DIAG_POD_REDACT=""
  DIAG_NOTES=""
  if [ -n "$DIAG_POD" ] &&
    printf 'x' | kubectl -n "$NAMESPACE" exec -i "$DIAG_POD" -- kwatch redact >/dev/null 2>&1; then
    DIAG_POD_REDACT=1
  fi
  DIAG_WORK=$(mktemp -d 2>/dev/null) || { ui_error "Could not write a working folder. Free some space and try again."; ui_pause; return 0; }
  dir="$DIAG_WORK/bundle"
  lines=2000
  ui_busy "Collecting"
  ui_busy_done
  diag_collect "$dir" "$lines"
  for n in 1000 500 200; do
    size=$(du -sk "$dir" | awk '{print $1*1024}')
    [ "${size:-0}" -le "$DIAG_MAX_BYTES" ] && break
    logs_cut=true
    lines=$n
    diag_collect "$dir" "$lines"
  done
  [ -n "$DIAG_POD" ] || DIAG_NOTES="${DIAG_NOTES}No kwatch Pod was found, so the diagnostics have no logs. Everything else was saved.
"
  diag_write_readme "$dir"
  diag_write_manifest "$dir" "$lines"
  ui_detail "  Checking nothing private is left"
  if scan_hit=$(diag_scan "$dir"); then :; else
    ui_error "A line that may hold a secret was left in $scan_hit. Nothing was saved. Please tell us in Get help."
    rm -rf "$DIAG_WORK"; DIAG_WORK=""
    ui_pause
    return 0
  fi
  while true; do
    total_kb=0
    ui_heading "Save diagnostics to a file"
    ui_detail "  kwatch status                    $(diag_kb "$dir/status.txt") KB"
    ui_detail "  Last $lines log lines            $(diag_kb "$dir/logs.txt") KB"
    ui_detail "  Events from the kwatch namespace  $(diag_kb "$dir/events.txt") KB"
    ui_detail "  Settings, secrets removed         $(diag_kb "$dir/config.yaml") KB"
    ui_detail "  kwatch and Kubernetes versions    $(diag_kb "$dir/manifest.json") KB"
    total_kb=$(du -sk "$dir" | awk '{print $1}')
    ui_detail "  Total                            ~${total_kb} KB"
    printf '\n' >&2
    ui_detail "Removed: Secrets, your license key, webhook URLs, tokens, e-mail"
    ui_detail "addresses and IP addresses."
    ui_detail "The file stays on this computer. kwatch does not upload it."
    [ "$logs_cut" != true ] || ui_detail "Logs were cut to the last $lines lines to keep the file small."
    [ -z "$DIAG_NOTES" ] || ui_warn "$DIAG_NOTES"
    choice=$(ui_select 0 "Save the file" "Review the files first" "Cancel") || choice=2
    case "$choice" in
      1)
        review="$DIAG_WORK/review"
        rm -rf "$review"; cp -R "$dir" "$review"
        ui_info "Opened at $review. Look through it, then come back here."
        ui_pause
        ;;
      0) break ;;
      *)
        rm -rf "$DIAG_WORK"; DIAG_WORK=""
        ui_info "Nothing was saved."
        return 0
        ;;
    esac
  done
  out_dir=$(diag_output_dir)
  slug=$(diag_cluster_slug)
  date_s=$(date -u +%Y%m%d)
  name="kwatch-diagnostics-$slug-$date_s"
  file="$out_dir/$name.tar.gz"
  n=2
  while [ -e "$file" ]; do
    file="$out_dir/$name-$n.tar.gz"
    n=$((n + 1))
  done
  if ! tar -czf "$file" -C "$dir" . 2>/dev/null; then
    ui_error "Could not write $file. Free some space or run the installer from a folder you can write to."
    rm -rf "$DIAG_WORK"; DIAG_WORK=""
    ui_pause
    return 0
  fi
  size=$(wc -c <"$file" | tr -d ' ')
  rm -rf "$DIAG_WORK"; DIAG_WORK=""
  ui_heading "Diagnostics saved"
  ui_detail "  $file   ($(((size + 1023) / 1024)) KB)"
  printf '\n' >&2
  ui_detail "Attach this file when you reply to our support email."
  ui_detail "No support email yet? Pro users: open app.kwatch.dev, choose Get help"
  ui_detail "and describe what happened. We reply by e-mail."
  ui_detail "Community: open an issue at github.com/abahmed/kwatch/issues. Attach the"
  ui_detail "file only after you have read it; issues are public."
  if [ -f /.dockerenv ] || [ -n "${KUBERNETES_SERVICE_HOST:-}" ] || [ -n "${CI:-}" ]; then
    printf '\n' >&2
    ui_detail "Copy it out of the container before it stops, for example with kubectl cp or docker cp."
  elif [ -n "${SSH_CONNECTION:-}" ]; then
    local full host
    full="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
    host=$(hostname 2>/dev/null || echo host)
    printf '\n' >&2
    ui_detail "This file is on $host. To copy it to your computer, run this on your"
    ui_detail "computer:"
    ui_detail "  scp ${USER:-user}@$host:$full ."
  fi
  ui_pause
  return 0
}

license_flow() {
  local choice
  LICENSE_FLOW_CHANGED=false
  LICENSE_COMMUNITY_CACHE=""
  while true; do
    ui_screen "license / pro"
    local -a lacts=(status) llabels=("📋 Show license status")
    # Only with an active key: absent otherwise, not greyed.
    if license_secret_exists; then
      lacts+=(checkins)
      llabels+=("📡 Cluster check-ins: $(checkins_state)   (change)")
    fi
    lacts+=(add move remove back)
    llabels+=("🔑 Add or replace key" "🚚 Move license to this cluster" "🗑️  Remove key" "↩️  Back")
    choice=$(ui_select 0 "${llabels[@]}") || break
    case "${lacts[$choice]}" in
      status) license_show_status; ui_pause ;;
      checkins) checkins_flow; ui_pause ;;
      add) license_add_flow; ui_pause ;;
      move) license_move_flow || true; ui_pause ;;
      remove) license_remove_flow; ui_pause ;;
      *) break ;;
    esac
  done
  [ "$LICENSE_FLOW_CHANGED" = true ] || MENU_READ_ONLY=true
  return 0
}

# Uninstall: free the key so another cluster can use it.
license_release_before_uninstall() {
  local pod
  license_secret_exists || return 0
  confirm_action "Release the license so it can be used on another cluster?" "y" ||
    return 0
  pod=$(kubectl -n "$NAMESPACE" get pods -l "$(workload_selector)" \
    -o 'jsonpath={.items[0].metadata.name}' 2>/dev/null || true)
  if [ -n "$pod" ] &&
    kubectl -n "$NAMESPACE" exec "$pod" -- kwatch license deactivate; then
    ui_success "✅ License released."
  else
    ui_warn "⚠️ Could not release the license from the Pod; you can release it from $LICENSE_ACCOUNT_URL"
  fi
}

license_delete_after_uninstall() {
  local name
  name=$(license_secret_name)
  if license_secret_exists || [ -n "$(kubectl -n "$NAMESPACE" get secret \
    "$LICENSE_INSTANCE_SECRET" --ignore-not-found -o name 2>/dev/null || true)" ]; then
    if confirm_action "Delete the license Secrets ($name and $LICENSE_INSTANCE_SECRET)?" "n"; then
      kubectl -n "$NAMESPACE" delete secret "$name" "$LICENSE_INSTANCE_SECRET" \
        --ignore-not-found >/dev/null 2>&1 || true
    else
      ui_info "🔐 Keeping the license Secrets."
    fi
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
  KWATCH_SHOW_DIFF=true            Print what an upgrade will change in the
                                   cluster before applying it
  KWATCH_NO_TITLE=1                Leave the terminal tab title alone
  KWATCH_ROLLOUT_TIMEOUT           How long to wait for a rollout
                                   (default: 5m)
  KWATCH_BACKUP_KEEP               Configuration backups to retain
                                   (default: 5)
  KWATCH_STORAGE=pvc|emptydir      Where the state lives: a claim on the
                                   default StorageClass (default), or an
                                   emptyDir that is lost when the Pod moves
  KWATCH_STORAGE_CLASS             StorageClass for the state claim
  KWATCH_STORAGE_SIZE              Size of the state volume (default: 2Gi)
  KWATCH_LICENSE_KEY               Pro license key (KW1-...). When set, install
                                   and upgrade store it in the ${RELEASE}-license
                                   Secret and apply it without prompting. Manage
                                   it later from License / Pro in the menu
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
# Resources and placement, asked once and then remembered. The values shown as
# defaults are the ones running now, so pressing Enter through the questions
# changes nothing.
# One value at a time, chosen from a list, the way settings are edited: walking
# through five prompts to change one number was four questions too many. Nothing
# reaches the cluster until Apply, so Escape at any point costs nothing.
configure_deployment_resources_flow() {
  local deployment index choice count cursor=0
  local requests_cpu requests_memory limits_cpu limits_memory node_spec
  local live_requests_cpu live_requests_memory live_limits_cpu
  local live_limits_memory live_node_spec
  local -a labels=() captions=()
  deployment=$(deployment_name || true)
  if [ -z "$deployment" ]; then
    ui_error "❌ kwatch is not installed, so there is no Deployment to size."
    return 1
  fi
  index=$(kwatch_container_index "$deployment") || index=""
  if [ -z "$index" ]; then
    ui_error "❌ Could not find the kwatch container in the Deployment."
    return 1
  fi
  ui_busy "Reading the current Deployment resources"
  live_requests_cpu=$(live_resource_value "$deployment" "$index" requests cpu)
  live_requests_memory=$(live_resource_value "$deployment" "$index" requests memory)
  live_limits_cpu=$(live_resource_value "$deployment" "$index" limits cpu)
  live_limits_memory=$(live_resource_value "$deployment" "$index" limits memory)
  live_node_spec=$(live_node_selector "$deployment")
  deployment_overrides_read
  ui_busy_done
  requests_cpu="$live_requests_cpu"
  requests_memory="$live_requests_memory"
  limits_cpu="$live_limits_cpu"
  limits_memory="$live_limits_memory"
  node_spec="$live_node_spec"

  while true; do
    ui_screen_clear
    ui_heading "🧮 Deployment resources and placement"
    if [ -n "$(overrides_without_license)" ]; then
      ui_detail "  Recorded; upgrades and reinstalls keep these values."
    else
      ui_detail "  Release defaults; applying here makes upgrades keep them."
    fi
    labels=()
    captions=()
    override_field_row "CPU request" "$requests_cpu" "$live_requests_cpu"
    captions+=("Guaranteed CPU. Written as 100m, 250m, 0.5 or 2.")
    override_field_row "CPU limit" "$limits_cpu" "$live_limits_cpu"
    captions+=("Ceiling before the container is throttled.")
    override_field_row "Memory request" "$requests_memory" "$live_requests_memory"
    captions+=("Guaranteed memory. Written as 128Mi, 512Mi or 1Gi.")
    override_field_row "Memory limit" "$limits_memory" "$live_limits_memory"
    captions+=("Ceiling before the container is killed; also caps the Go heap.")
    override_field_row "Placement" "${node_spec:-any node}" "${live_node_spec:-any node}"
    captions+=("Node selector as key=value,key=value — or any node.")
    count=5
    if deployment_shape_changed "$requests_cpu" "$live_requests_cpu" \
      "$requests_memory" "$live_requests_memory" "$limits_cpu" \
      "$live_limits_cpu" "$limits_memory" "$live_limits_memory" \
      "$node_spec" "$live_node_spec"; then
      labels+=("✅ Apply changes")
      captions+=("Patch the Deployment, record the values, wait for the new Pod.")
    else
      labels+=("${UI_DIM}✅ Apply changes (nothing changed yet)${UI_RESET}")
      captions+=("Edit a value above first.")
    fi
    labels+=("↩️  Back")
    captions+=("Leave without changing anything.")

    choice=$(ui_select_captioned "$cursor" "${#labels[@]}" "${labels[@]}" \
      "${captions[@]}") || { MENU_READ_ONLY=true; return 0; }
    # Stay on the row that was just edited rather than jumping back to the top.
    cursor="$choice"
    case "$choice" in
      0) requests_cpu=$(edit_cpu_field "CPU request" "$requests_cpu") ;;
      1) limits_cpu=$(edit_cpu_field "CPU limit" "$limits_cpu") ;;
      2) requests_memory=$(edit_memory_field "Memory request" "$requests_memory") ;;
      3) limits_memory=$(edit_memory_field "Memory limit" "$limits_memory") ;;
      4) node_spec=$(edit_placement_field "$node_spec") ;;
      "$count")
        if ! deployment_shape_changed "$requests_cpu" "$live_requests_cpu" \
          "$requests_memory" "$live_requests_memory" "$limits_cpu" \
          "$live_limits_cpu" "$limits_memory" "$live_limits_memory" \
          "$node_spec" "$live_node_spec"; then
          ui_info "ℹ️ Nothing has been changed yet."
          continue
        fi
        apply_deployment_shape "$deployment" "$index" "$requests_cpu" \
          "$requests_memory" "$limits_cpu" "$limits_memory" "$node_spec"
        return "$?"
        ;;
      *) MENU_READ_ONLY=true; return 0 ;;
    esac
  done
}

# Appends one row to the caller's `labels` array -- bash scopes locals
# dynamically, so this writes the flow's own list, not a global. Shows the
# pending value, and what it was whenever an edit has changed it.
override_field_row() {
  local name="$1" value="$2" live="$3" row
  printf -v row '%-16s %s' "$name" "${value:-—}"
  if [ "$value" != "$live" ]; then
    row="$row  ${UI_YELLOW}← was ${live:-—}${UI_RESET}"
  fi
  labels+=("$row")
}

deployment_shape_changed() {
  [ "$1" != "$2" ] || [ "$3" != "$4" ] || [ "$5" != "$6" ] ||
    [ "$7" != "$8" ] || [ "$9" != "${10}" ]
}

# Each editor keeps the current value when the prompt is left with Escape, so
# cancelling one field does not discard the others.
edit_cpu_field() {
  local name="$1" current="$2" answer
  while true; do
    answer=$(ask_or_back "$name" "$current") || { printf '%s' "$current"; return 0; }
    if valid_cpu_quantity "$answer"; then
      printf '%s' "$answer"
      return 0
    fi
    ui_warn "⚠️ Not a CPU quantity. Use 100m, 250m, 0.5 or 2."
  done
}

edit_memory_field() {
  local name="$1" current="$2" answer
  while true; do
    answer=$(ask_or_back "$name" "$current") || { printf '%s' "$current"; return 0; }
    if valid_memory_quantity "$answer"; then
      printf '%s' "$answer"
      return 0
    fi
    ui_warn "⚠️ Not a memory quantity. Use 128Mi, 512Mi or 1Gi."
  done
}

edit_placement_field() {
  local current="$1" answer
  ui_detail "  Type - for any node."
  while true; do
    answer=$(ask_or_back "Node selector (key=value,key=value)" "$current") ||
      { printf '%s' "$current"; return 0; }
    # An empty answer keeps the current selector, so a dash is the only way to
    # say "no placement constraint".
    [ "$answer" = "-" ] && answer=""
    if valid_node_selector "$answer"; then
      printf '%s' "$answer"
      return 0
    fi
    ui_warn "⚠️ Not a label selector. Use key=value pairs, comma separated, or - for any node."
  done
}

apply_deployment_shape() {
  local deployment="$1" index="$2" requests_cpu="$3" requests_memory="$4"
  local limits_cpu="$5" limits_memory="$6" node_spec="$7" details patch had_license
  # A Deployment that carries no resources at all leaves these empty, and an
  # empty quantity is not something to send: the API server rejects it, and
  # cpu_to_milli reads it as 0, so the request-vs-limit check below would not
  # have caught it either.
  if [ -z "$requests_cpu" ] || [ -z "$limits_cpu" ] ||
    [ -z "$requests_memory" ] || [ -z "$limits_memory" ]; then
    ui_error "❌ Every request and limit needs a value before this can be applied."
    ui_detail "  Set the empty ones (shown as —) and try again."
    return 1
  fi
  # The API server rejects a request above its limit; say so before the rollout
  # rather than after it.
  if [ "$(cpu_to_milli "$requests_cpu")" -gt "$(cpu_to_milli "$limits_cpu")" ]; then
    ui_error "❌ The CPU request ($requests_cpu) is above the CPU limit ($limits_cpu)."
    return 1
  fi
  if awk -v r="$(memory_to_bytes "$requests_memory")" \
    -v l="$(memory_to_bytes "$limits_memory")" \
    'BEGIN { exit (r > l) ? 0 : 1 }'; then
    ui_error "❌ The memory request ($requests_memory) is above the memory limit ($limits_memory)."
    return 1
  fi
  had_license=$(deployment_override_get license || true)
  DEPLOYMENT_OVERRIDES="requests.cpu=$requests_cpu;requests.memory=$requests_memory"
  DEPLOYMENT_OVERRIDES="$DEPLOYMENT_OVERRIDES;limits.cpu=$limits_cpu;limits.memory=$limits_memory"
  [ -n "$node_spec" ] &&
    DEPLOYMENT_OVERRIDES="$DEPLOYMENT_OVERRIDES;nodeSelector=$node_spec"
  # The license marker shares this record; rewriting the sizing must not drop it.
  [ "$had_license" = 1 ] && DEPLOYMENT_OVERRIDES="$DEPLOYMENT_OVERRIDES;license=1"

  details="This replaces the kwatch container's resources with requests"
  details="$details $requests_cpu/$requests_memory and limits"
  details="$details $limits_cpu/$limits_memory"
  if [ -n "$node_spec" ]; then
    details="$details, and restricts the Pod to nodes matching $node_spec"
  else
    details="$details, and removes any node selector"
  fi
  details="$details. The Pod is replaced. The values are recorded on the"
  details="$details Deployment and in a ConfigMap that outlives it, so an"
  details="$details upgrade -- or a reinstall that keeps configuration --"
  details="$details keeps them instead of reverting to the release defaults."
  confirm_change "🧮 The manager will update the kwatch Deployment." \
    "$details" || {
    ui_info "↩️ Nothing was changed."
    MENU_READ_ONLY=true
    return 0
  }

  check_access patch deployments namespace
  patch=$(deployment_overrides_patch "$index" "$requests_cpu" "$requests_memory" \
    "$limits_cpu" "$limits_memory" "$node_spec")
  with_loading "Applying resources and placement" kubectl -n "$NAMESPACE" \
    patch deployment "$deployment" --type=json -p "$patch" >/dev/null || {
    ui_error "❌ Could not apply the new resources." \
      "$(compact_reason "${LAST_COMMAND_ERROR:-no diagnostic was returned}")"
    return 1
  }
  with_loading "Recording resources for future upgrades" \
    deployment_overrides_write "$deployment" "$DEPLOYMENT_OVERRIDES" || {
    ui_warn "⚠️ The Pod was resized, but the values could not be recorded;"
    ui_warn "   the next upgrade would revert them."
    return 1
  }
  if ! with_loading "Waiting for the resized kwatch Pod" \
    wait_for_kwatch_rollout "$deployment"; then
    ui_error "❌ The resized Pod did not become ready." \
      "$(compact_reason "${LAST_COMMAND_ERROR:-no diagnostic was returned}")"
    show_unready_pods "$(workload_selector)" || true
    return 1
  fi
  ui_success "✅ Resources applied and recorded; upgrades will keep them."
  ui_pause
  return 0
}

# The container list is patched by index, so find the kwatch container rather
# than assuming it is the first one.
kwatch_container_index() {
  local deployment="$1" names index=0 name
  names=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={range .spec.template.spec.containers[*]}{.name}{"\n"}{end}' \
    2>/dev/null || true)
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if [ "$name" = "$RELEASE" ] || [ "$name" = kwatch ]; then
      printf '%s' "$index"
      return 0
    fi
    index=$((index + 1))
  done <<< "$names"
  return 1
}

live_resource_value() {
  local deployment="$1" index="$2" section="$3" field="$4" value
  value=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o "jsonpath={.spec.template.spec.containers[$index].resources.$section.$field}" \
    2>/dev/null || true)
  printf '%s' "$value"
}

# jsonpath cannot iterate a map's keys, and there is no jq to lean on, so use
# go-template -- which kubectl has built in -- to render the selector back into
# the same key=value,key=value form the prompt accepts.
live_node_selector() {
  local deployment="$1" rendered
  rendered=$(kubectl -n "$NAMESPACE" get deployment "$deployment" -o go-template \
    --template='{{range $k, $v := .spec.template.spec.nodeSelector}}{{$k}}={{$v}},{{end}}' \
    2>/dev/null || true)
  printf '%s' "${rendered%,}"
}

# JSON Patch rather than a merge patch: `add` on an object member replaces it
# outright, so a node selector that lost a key does not keep the stale one, and
# the container list is addressed by index instead of being overwritten whole.
deployment_overrides_patch() {
  local index="$1" rcpu="$2" rmem="$3" lcpu="$4" lmem="$5" node_spec="$6"
  local pairs="" pair
  printf '['
  printf '{"op":"add","path":"/spec/template/spec/containers/%s/resources",' "$index"
  printf '"value":{"requests":{"cpu":"%s","memory":"%s"},' "$rcpu" "$rmem"
  printf '"limits":{"cpu":"%s","memory":"%s"}}}' "$lcpu" "$lmem"
  if [ -n "$node_spec" ]; then
    local IFS=','
    for pair in $node_spec; do
      [ -n "$pair" ] || continue
      if [ -n "$pairs" ]; then
        pairs="$pairs,"
      fi
      pairs="$pairs\"${pair%%=*}\":\"${pair#*=}\""
    done
    printf ',{"op":"add","path":"/spec/template/spec/nodeSelector","value":{%s}}' \
      "$pairs"
  else
    # `remove` on a missing path fails the whole patch, so replace with an empty
    # object, which Kubernetes drops.
    printf ',{"op":"add","path":"/spec/template/spec/nodeSelector","value":{}}'
  fi
  printf ']'
}

interactive_session() {
  while true; do
    MENU_EXIT=false
    MENU_READ_ONLY=false
    case "$INSTALL_STATE" in
      absent) show_absent_menu ;;
      legacy) show_legacy_menu ;;
      supported) show_supported_menu ;;
      broken) show_broken_menu ;;
      *) die "could not assess the kwatch installation" ;;
    esac
    [ "$MENU_EXIT" = true ] && return 0
    [ -t 0 ] || return 0
    # Viewing the status, the logs or the capabilities cannot have changed the
    # workload, so re-reading it afterwards is a wait for nothing -- and a
    # visible one now that the step announces itself. Only an action that could
    # have changed something pays for the re-assessment.
    if [ "$MENU_READ_ONLY" = true ]; then
      continue
    fi
    invalidate_deployment_name
    ui_busy "Re-reading the installation"
    assess_installation
    ui_busy_done
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
  ui_title_push
  ui_title_step ""
  ui_banner
  select_context
  with_loading "Checking Kubernetes cluster" kubectl cluster-info >/dev/null ||
    die "cannot reach the Kubernetes cluster: $(compact_reason "${LAST_COMMAND_ERROR:-no diagnostic was returned}")"
  check_cluster_version
  ui_busy "Checking the kwatch installation"
  assess_installation
  ui_busy_done
  interactive_session
}

if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
