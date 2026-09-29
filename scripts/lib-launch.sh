# shellcheck shell=bash
# lib-launch.sh — shared launcher for start-team.sh and recycle-sibling.sh (orchestration-kit).
# Sourced, never run. One copy of the Windows+WSL launch logic so the two scripts can't drift.
#
# Opens a NEW Windows console running `claude --name <Name> <prompt>` inside this WSL distro,
# in the repo's main checkout. Windows Terminal (wt.exe) when present, else a plain conhost
# window via PowerShell Start-Process — the fallback also covers a Windows Terminal that
# answers rc 0 to new-tab and opens nothing.
#
# Command-line rules (why names/prompts are whitelisted):
#   * wt.exe splits its own subcommands on `;`, and embedded `"` / `'` cross Windows argv and
#     PowerShell quoting badly — the generated command line must contain none of them.
#   * wsl.exe stays BARE inside the wt.exe / conhost command line — Windows resolves it there;
#     the /mnt/c/Windows/System32/wsl.exe form can return rc 0 and spawn nothing.
#   * wt.exe / cmd.exe / powershell.exe are called by FULL path: the shell's PATH may lack them.
#   * `bash -lc` is non-interactive, so ~/.bashrc usually returns before loading nvm; if nvm is
#     installed it is sourced explicitly, or the new session has no node on PATH.
#
# Sessions are identified by `pgrep -f "^claude --name <Name>( |$)"` — they MUST be started
# with the long flag, first.

LAUNCH_NAME_RE='^[A-Za-z0-9_-]+$'
LAUNCH_PROMPT_RE='^[A-Za-z0-9 /._:,@=+-]*$'

launch_valid_name()   { [[ "$1" =~ $LAUNCH_NAME_RE ]]; }
launch_valid_prompt() { [[ "$1" =~ $LAUNCH_PROMPT_RE ]]; }

launch_check_args() {  # <name> <prompt> — exit 64 on unsafe input
  launch_valid_name "$1" || { echo "name must match [A-Za-z0-9_-]+ : '$1'" >&2; exit 64; }
  launch_valid_prompt "$2" || {
    echo "prompt may only contain letters, digits, spaces and / . _ : , @ = + -  (no ; \" ' ): '$2'" >&2
    exit 64
  }
}

launch_is_wsl() { [ -n "${WSL_DISTRO_NAME:-}" ]; }

# Main checkout of the current repo (not the current worktree), unless REPO_DIR/--repo set it.
launch_repo() {
  local repo="${1:-${REPO_DIR:-}}" common
  if [ -z "$repo" ]; then
    common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [ -n "$common" ] && [ "$(basename "$common")" = ".git" ]; then
      repo="$(dirname "$common")"
    else
      repo="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    fi
  fi
  if [ -z "$repo" ] || [ ! -d "$repo" ]; then
    echo "no repo dir: run inside the repo, or pass --repo DIR / set REPO_DIR" >&2; exit 64
  fi
  case "$repo" in *[\;\"\'\ ]*) echo "repo path must not contain spaces or ; \" ' : $repo" >&2; exit 64 ;; esac
  printf '%s\n' "$repo"
}

_launch_win() { command -v "$1" 2>/dev/null || echo "$2"; }

# Sets LAUNCH_DISTRO LAUNCH_REPO LAUNCH_WT LAUNCH_PS LAUNCH_NVM. Call once, after launch_is_wsl.
launch_init() {
  LAUNCH_DISTRO="$WSL_DISTRO_NAME"
  LAUNCH_REPO="$(launch_repo "${1:-}")" || exit 64
  LAUNCH_PS="$(_launch_win powershell.exe /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe)"
  local cmd_exe winuser
  cmd_exe="$(_launch_win cmd.exe /mnt/c/Windows/System32/cmd.exe)"
  LAUNCH_WT="${WT_EXE:-}"
  if [ -z "$LAUNCH_WT" ]; then
    # cd /mnt/c first: cmd.exe warns about UNC paths when started from a Linux directory.
    winuser="$( (cd /mnt/c 2>/dev/null; "$cmd_exe" /c "echo %USERNAME%" 2>/dev/null) | tr -d '\r')" || winuser=""
    [ -n "$winuser" ] && LAUNCH_WT="/mnt/c/Users/${winuser}/AppData/Local/Microsoft/WindowsApps/wt.exe"
  fi
  if [ -n "$LAUNCH_WT" ] && [ ! -e "$LAUNCH_WT" ]; then LAUNCH_WT=""; fi
  LAUNCH_NVM=""
  if [ -s "$HOME/.nvm/nvm.sh" ]; then LAUNCH_NVM=". $HOME/.nvm/nvm.sh && "; fi
}

launch_pattern() { printf '^claude --name %s( |$)' "$1"; }
launch_pids()    { pgrep -f "$(launch_pattern "$1")" || true; }
launch_cmd()     { printf '%sclaude --name %s %s' "$LAUNCH_NVM" "$1" "$(printf '%q' "$2")"; }

_launch_wt_args() {  # fills the global array LAUNCH_WT_ARGS
  LAUNCH_WT_ARGS=(-w 0 new-tab --title "$1" wsl.exe -d "$LAUNCH_DISTRO" --cd "$LAUNCH_REPO" -e bash -lc "$(launch_cmd "$1" "$2")")
}
_launch_ps_cmd() {
  printf "Start-Process conhost.exe -ArgumentList 'wsl.exe -d %s --cd %s -e bash -lc \"%s\"'" \
    "$LAUNCH_DISTRO" "$LAUNCH_REPO" "$(launch_cmd "$1" "$2")"
}

launch_describe_env() {
  echo "distro     $LAUNCH_DISTRO"
  echo "repo       $LAUNCH_REPO"
  echo "wt.exe     ${LAUNCH_WT:-absent -> conhost windows}"
  if [ -n "$LAUNCH_NVM" ]; then echo "nvm        sourced ($HOME/.nvm/nvm.sh)"; else echo "nvm        not installed (skipped)"; fi
}

launch_describe() {  # <name> <prompt> — print what launch_open would run
  echo "command    $(launch_cmd "$1" "$2")"
  if [ -n "$LAUNCH_WT" ]; then
    _launch_wt_args "$1" "$2"
    printf 'would run  %q' "$LAUNCH_WT"; printf ' %q' "${LAUNCH_WT_ARGS[@]}"; echo
    echo "fallback   $LAUNCH_PS -NoProfile -Command \"$(_launch_ps_cmd "$1" "$2")\""
  else
    echo "would run  $LAUNCH_PS -NoProfile -Command \"$(_launch_ps_cmd "$1" "$2")\""
  fi
}

# launch_wait_fresh <name> <old-pids> <polls of 2s> — sets LAUNCH_FRESH; 0 when a new pid exists
launch_wait_fresh() {
  local name="$1" old="$2" polls="$3" _
  LAUNCH_FRESH=""
  for _ in $(seq 1 "$polls"); do
    LAUNCH_FRESH="$(launch_pids "$name" | grep -vxF -e "${old:-__none__}" || true)"
    [ -n "$LAUNCH_FRESH" ] && return 0
    sleep 2
  done
  return 1
}

# launch_open <name> <prompt> <old-pids> — open a window, wait for the fresh process.
# 0 + LAUNCH_FRESH on success; 1 if neither wt.exe nor conhost produced one.
launch_open() {
  local name="$1" prompt="$2" old="$3"
  if [ -n "$LAUNCH_WT" ]; then
    _launch_wt_args "$name" "$prompt"
    if "$LAUNCH_WT" "${LAUNCH_WT_ARGS[@]}" && launch_wait_fresh "$name" "$old" 10; then return 0; fi
    echo "wt.exe did not produce a '$name' session; falling back to a conhost window" >&2
  fi
  "$LAUNCH_PS" -NoProfile -Command "$(_launch_ps_cmd "$name" "$prompt")" || true
  launch_wait_fresh "$name" "$old" 15
}
