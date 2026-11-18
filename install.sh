#!/bin/bash
# Guided installer for `all` (https://github.com/leoyigit/shopify-scopes).
#
#   bash install.sh               install, or re-run the guided setup (safe to run again)
#   bash install.sh --update      install the latest version
#   bash install.sh --uninstall   remove it
#   options: --yes (no questions, use defaults)  --name <command>  --help
set -euo pipefail

# Everything runs inside main(), called on the last line: a download cut off half-way runs nothing.
main() {

REPO="leoyigit/shopify-scopes"
INSTALL_DIR="$HOME/.local/share/shopify-scopes"
BIN_DIR="$HOME/.local/bin"
DEFAULT_NAME="all"
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

ACTION="install" YES=false NAME=""
while [ $# -gt 0 ]; do
  case "$1" in
    --update) ACTION="update" ;;
    --uninstall) ACTION="uninstall" ;;
    --yes|-y) YES=true ;;
    --name) NAME="${2:?--name needs a value}"; shift ;;
    -h|--help) sed -n '2,7p' "${BASH_SOURCE[0]:-$0}" 2>/dev/null | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
  shift
done

# ── look ──────────────────────────────────────────────────────────────────────
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  B=$'\e[1m' D=$'\e[2m' G=$'\e[32m' R=$'\e[31m' Y=$'\e[33m' C=$'\e[36m' M=$'\e[35m' X=$'\e[0m'
else
  B="" D="" G="" R="" Y="" C="" M="" X=""
fi
TTY=false
if [ "$YES" != true ] && { : </dev/tty; } 2>/dev/null; then TTY=true; fi

STEP=0 STEPS=5
step() { STEP=$((STEP + 1)); printf '\n%s\n' "${M}${B}[$STEP/$STEPS]${X} ${B}$1${X}"; }
ok()   { printf '%s\n' "  ${G}✓${X} $1"; }
warn() { printf '%s\n' "  ${Y}!${X} $1"; }
bad()  { printf '%s\n' "  ${R}✗${X} $1"; }
info() { printf '%s\n' "    $1"; }
ask() {  # ask "question" default  → prints the answer (the default when not interactive)
  local a=""
  if $TTY; then printf '%s' "  ${C}?${X} $1 ${D}[$2]${X} " >/dev/tty; IFS= read -r a </dev/tty || a=""; fi
  printf '%s' "${a:-$2}"
}
yes_no() { case "$(ask "$1 (y/n)" "$2")" in [Yy]*) return 0 ;; *) return 1 ;; esac; }
wait_enter() { if $TTY; then printf '%s' "  ${D}$1${X}" >/dev/tty; IFS= read -r _ </dev/tty || true; fi; }

banner() {
  printf '%s\n' "" \
    "  ${B}┌──────────────────────────────────────────────┐${X}" \
    "  ${B}│${X}   ${G}✓${X} ${B}all${X}  ·  select every Shopify app scope   ${B}│${X}" \
    "  ${B}│${X}   ${D}one command or one key, in your browser${X}    ${B}│${X}" \
    "  ${B}└──────────────────────────────────────────────┘${X}"
}

git_gh() {  # git with the GitHub CLI as credential helper, so the private repo needs no password prompt
  if command -v gh >/dev/null 2>&1; then
    git -c credential.helper= -c 'credential.helper=!gh auth git-credential' "$@"
  else
    git "$@"
  fi
}

# ── where am I running from? ──────────────────────────────────────────────────
SELF="${BASH_SOURCE[0]:-}"
ROOT=""
if [ -n "$SELF" ] && [ -f "$SELF" ]; then
  here="$(cd "$(dirname "$SELF")" && pwd)"
  [ -f "$here/bin/all" ] && ROOT="$here"
fi

# ── uninstall ─────────────────────────────────────────────────────────────────
if [ "$ACTION" = "uninstall" ]; then
  target="${ROOT:-$INSTALL_DIR}"
  printf '\n%s\n' "${B}Removing all${X}"
  removed=0
  for f in "$BIN_DIR"/*; do
    [ -L "$f" ] || continue
    case "$(readlink "$f")" in
      "$target/bin/all"|"$INSTALL_DIR/bin/all") rm "$f"; ok "Removed the command ${C}$(basename "$f")${X}"; removed=1 ;;
    esac
  done
  [ "$removed" = 1 ] || warn "No command found in $BIN_DIR."
  if [ -d "$INSTALL_DIR" ] && yes_no "Delete the downloaded files in $INSTALL_DIR?" "y"; then
    rm -rf "$INSTALL_DIR" && ok "Deleted $INSTALL_DIR"
  fi
  info "If you made a keyboard shortcut, delete ${B}Select all scopes${X} in the Shortcuts app."
  info "You can turn off ${B}Allow JavaScript from Apple Events${X} in your browser if nothing else needs it."
  exit 0
fi

# ── update ────────────────────────────────────────────────────────────────────
if [ "$ACTION" = "update" ]; then
  target="${ROOT:-$INSTALL_DIR}"
  [ -d "$target/.git" ] || { bad "No downloaded copy at $target. Run the install line from the README."; exit 1; }
  before="$(git -C "$target" rev-parse --short HEAD)" v_before="$(cat "$target/VERSION" 2>/dev/null || echo "?")"
  if ! GIT_TERMINAL_PROMPT=0 git_gh -C "$target" pull --ff-only --quiet; then
    bad "Couldn't download the update."
    info "Check you're online, then run it again."
    exit 1
  fi
  after="$(git -C "$target" rev-parse --short HEAD)" v_after="$(cat "$target/VERSION" 2>/dev/null || echo "?")"
  touch "$target/.git/shopify-scopes-checked"
  if [ "$before" = "$after" ]; then
    ok "Already up to date (v$v_after)."
  else
    ok "Updated v$v_before → ${B}v$v_after${X}. What's new:"
    git -C "$target" log --no-merges --format='    • %s' "$before..$after"
  fi
  exit 0
fi

# ── install / guided setup ────────────────────────────────────────────────────
if [ "$(uname)" != "Darwin" ]; then
  printf '%s\n' "" "  ${B}This computer isn't a Mac${X}, so the ${C}all${X} command can't run here: it drives the browser" \
    "  through a macOS feature. The bookmark version works on any computer and in any browser:" "" \
    "    ${B}1.${X} Open ${C}https://leoyigit.github.io/shopify-scopes/${X}" \
    "    ${B}2.${X} Drag the ${B}Select all scopes${X} button to your bookmarks bar." \
    "    ${B}3.${X} On your app's page, click that bookmark." ""
  exit 0
fi
command -v git >/dev/null 2>&1 || { echo "git is missing. Run: xcode-select --install, then this again." >&2; exit 1; }

if [ -z "$ROOT" ]; then  # started from the one-line install: download, then run the downloaded copy
  printf '\n%s\n' "${B}Downloading shopify-scopes…${X}"
  if [ -d "$INSTALL_DIR/.git" ]; then
    GIT_TERMINAL_PROMPT=0 git_gh -C "$INSTALL_DIR" pull --ff-only --quiet && ok "Updated the existing copy."
  else
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git_gh clone --quiet "https://github.com/$REPO.git" "$INSTALL_DIR" && ok "Downloaded."
  fi
  args=()
  [ "$YES" = true ] && args+=(--yes)
  [ -n "$NAME" ] && args+=(--name "$NAME")
  exec bash "$INSTALL_DIR/install.sh" ${args[@]+"${args[@]}"}
fi

banner
printf '%s\n' "  ${D}v$(cat "$ROOT/VERSION" 2>/dev/null || echo "?")${X}"

step "Check this Mac"
ok "macOS $(sw_vers -productVersion)"
ok "Files are in ${D}$ROOT${X}"
info "${D}macOS may ask to let this terminal control your browser: click OK.${X}"
BROWSER_STATUS="$(osascript -l JavaScript "$ROOT/src/browser.js" status 2>/dev/null || true)"
names="$(printf '%s\n' "$BROWSER_STATUS" | awk -F'|' '$2!="unsupported" && $1!="" {print $1}' | paste -sd ',' - | sed 's/,/, /g')"
if [ -n "$names" ]; then ok "Browsers it can use: $names"; else bad "No supported browser found (Chrome, Safari, Brave, Edge, Arc, Vivaldi)."; fi

step "Install the command"
mkdir -p "$BIN_DIR"
current=""  # already installed? keep its name
for f in "$BIN_DIR"/*; do
  [ -L "$f" ] && [ "$(readlink "$f")" = "$ROOT/bin/all" ] && current="$(basename "$f")"
done
if [ -z "$NAME" ]; then
  NAME="${current:-$DEFAULT_NAME}"
  existing="$(command -v "$NAME" 2>/dev/null || true)"
  if [ -z "$current" ] && [ -n "$existing" ] && [ "$existing" != "$BIN_DIR/$NAME" ]; then
    warn "The name ${C}$NAME${X} is already taken on this Mac ($existing)."
    NAME="$(ask "Which name should the command have?" "allscopes")"
  fi
fi
if [ -e "$BIN_DIR/$NAME" ] && [ ! -L "$BIN_DIR/$NAME" ]; then
  bad "$BIN_DIR/$NAME is a real file, not ours. Choose another name with ${C}--name${X}."; exit 1
fi
ln -sfn "$ROOT/bin/all" "$BIN_DIR/$NAME"
chmod +x "$ROOT/bin/all" "$ROOT/install.sh"
ok "Command ${C}$NAME${X} → ${D}$BIN_DIR/$NAME${X}"

case ":$PATH:" in
  *":$BIN_DIR:"*) ok "$BIN_DIR is on your PATH" ;;
  *)
    rc="$HOME/.zshrc"; case "${SHELL:-}" in */bash) rc="$HOME/.bash_profile" ;; esac
    line='export PATH="$HOME/.local/bin:$PATH"'
    if grep -qsF "$line" "$rc"; then
      ok "PATH line already in $rc (open a new terminal tab to use it)"
    elif yes_no "Add $BIN_DIR to your PATH in $(basename "$rc")?" "y"; then
      printf '\n# added by shopify-scopes installer\n%s\n' "$line" >>"$rc"
      ok "Added to $rc. ${B}Open a new terminal tab${X} before typing ${C}$NAME${X}."
    else
      warn "Skipped. Run it with the full path: ${C}$BIN_DIR/$NAME${X}"
    fi
    export PATH="$BIN_DIR:$PATH" ;;
esac

step "Let your browser accept the command"
info "${D}Chrome-type browsers and Safari each need one setting before a command may run scripts in them.${X}"
js_off_help() {
  case "$1" in
    *Safari*) echo "${B}Safari → Settings → Advanced${X} → tick ${B}Show features for web developers${X}, then ${B}Develop → Allow JavaScript from Apple Events${X}" ;;
    *) echo "in $1's menu bar: ${B}View → Developer → Allow JavaScript from Apple Events${X}" ;;
  esac
}
prefs_on() { [ -n "$1" ] && grep -qs '"allow_javascript_apple_events":true' "$HOME/Library/Application Support/$1/"*/Preferences; }
check_browsers() {  # returns 1 when something still needs the user
  local pending=0 bname kind st dir
  while IFS='|' read -r bname kind st dir; do
    [ -n "$bname" ] || continue
    if [ "$kind" = unsupported ]; then
      info "• ${B}$bname${X} can't be controlled from the terminal: use the bookmark there (${C}$NAME --bookmarklet${X})."
      continue
    fi
    if [ "$st" = unknown ] || [ "$st" = notrunning ]; then prefs_on "$dir" && st=on-prefs; fi
    case "$st" in
      on) ok "$bname: ready" ;;
      on-prefs) ok "$bname: setting is on" ;;
      off) warn "$bname: one-time setting needed: $(js_off_help "$bname")."; pending=1 ;;
      denied)
        warn "$bname: macOS blocked this terminal from controlling it."
        info "System Settings → ${B}Privacy & Security → Automation${X} → your terminal app → turn on ${B}$bname${X}."
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation" 2>/dev/null || true
        pending=1 ;;
      notrunning) info "• ${B}$bname${X} isn't open, so it wasn't checked. ${D}If you use it for Shopify: $(js_off_help "$bname").${X}" ;;
      *) info "• ${B}$bname${X}: couldn't check (open any web page in it, then run ${C}$NAME --setup${X}). ${D}Setting: $(js_off_help "$bname").${X}" ;;
    esac
  done <<<"$BROWSER_STATUS"
  return $pending
}
for attempt in 1 2 3; do
  if check_browsers; then break; fi
  if ! $TTY || [ "$attempt" = 3 ]; then warn "You can finish this later and re-check with ${C}$NAME --setup${X}."; break; fi
  wait_enter "Press Enter once that's done (it can take a few seconds to save)…"
  sleep 2
  BROWSER_STATUS="$(osascript -l JavaScript "$ROOT/src/browser.js" status 2>/dev/null || true)"
  printf '\n'
done

step "Keyboard shortcut (optional)"
info "Run it with one key press instead of the terminal, using the Shortcuts app."
if yes_no "Set up a keyboard shortcut now?" "y"; then
  if $TTY; then
    printf '%s' "$BIN_DIR/$NAME" | pbcopy
    open -a Shortcuts 2>/dev/null || true
    ok "Opened Shortcuts and copied the command to your clipboard."
  fi
  printf '%s\n' \
    "    ${B}1.${X} In Shortcuts press ${B}⌘N${X} and name the shortcut ${B}Select all scopes${X}." \
    "    ${B}2.${X} Add the action ${B}Run Shell Script${X} and replace its text with ${C}$BIN_DIR/$NAME${X} ${D}(⌘V)${X}." \
    "    ${B}3.${X} Open ${B}ⓘ Details${X} on the right and tick ${B}Use as Quick Action${X} and ${B}Services Menu${X}." \
    "    ${B}4.${X} At the top it now says ${B}Receive Apps and 18 more…${X}: click the blue types and ${B}untick all${X}," \
    "       so it receives no input. ${D}Skip this and the key does nothing in the browser.${X}" \
    "    ${B}5.${X} In Details, click ${B}Run with${X} / ${B}Add Keyboard Shortcut${X} and press keys, e.g. ${B}⌃⌥⌘A${X}." \
    "       ${D}Avoid ⌃\` if you use VS Code: it opens VS Code's terminal.${X}" \
    "    ${B}6.${X} Shortcuts menu → ${B}Settings → Advanced${X} → tick ${B}Allow Running Scripts${X}." \
    "    ${B}7.${X} Test: on your app's page, press your keys, and click ${B}Allow${X} if macOS asks."
  if $TTY; then wait_enter "Press Enter when you're done…"; fi
else
  info "Skipped. ${C}$NAME --setup${X} shows these steps again any time."
fi

step "Try it"
check="$("$BIN_DIR/$NAME" --check 2>&1 || true)"
case "$check" in
  *"popup found"*|*"would open"*) ok "Found your app's scopes. Run ${C}$NAME${X} now to select everything." ;;
  *) info "${D}Live check: $(printf '%s' "$check" | head -1)${X}" ;;
esac

printf '%s\n' "" \
  "  ${G}${B}Ready.${X} Open your app's page (the one with ${B}Scopes${X}) in your browser, then:" \
  "    ${C}$NAME${X}                 ${D}open the list if needed, select every scope, press Done${X}" \
  "    ${C}$NAME --check${X}         ${D}look for it, change nothing${X}" \
  "    ${C}$NAME --bookmarklet${X}   ${D}a bookmark button instead (any browser, no setup)${X}" \
  "    ${C}$NAME --help${X}          ${D}all commands · ${C}$NAME --setup${X}${D} re-runs this guide${X}" \
  "  ${D}When a new version is out, ${C}$NAME${X}${D} tells you; ${C}$NAME --update${X}${D} installs it.${X}" ""
}

main "$@"
