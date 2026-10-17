#!/usr/bin/env bash
#
# smart-splits.nvim — herdr side
#
# Invoked by a herdr keybind as: herdr-navigate.sh <left|down|up|right>
#
# Decision table per keypress:
#   1. Focused pane's foreground process matches Vim:
#      forward the key into the pane and let the editor/app decide.
#   2. Otherwise, try `herdr pane focus --direction DIR`:
#      - there is a neighbor (changed == true): focus moved, done.
#      - no neighbor (reason == "no_neighbor"): try the outer Kitty window.
#   3. No outer neighbor, or the focus command fails: send the key back to the
#      pane so the shell/app keeps its default binding (e.g. C-l = clear screen).
#
# Requires `jq`.

set -euo pipefail

dir="$1"
herdr="${HERDR_BIN_PATH:-herdr}"
pane="${HERDR_PANE_ID:-$HERDR_ACTIVE_PANE_ID}"

kitty_dir="$dir"
case "$dir" in
  left)  key="ctrl+h" ;;
  down)  key="ctrl+j"; kitty_dir="bottom" ;;
  up)    key="ctrl+k"; kitty_dir="top" ;;
  right) key="ctrl+l" ;;
esac

# Foreground process names that mean "Vim is in control of this pane".
# Same matcher vim-tmux-navigator uses: vi, vim, nvim, view, gvim, *diff, ...
vim_re='^g?(view|l?n?vim?x?)(diff)?$'

is_vim="$("$herdr" pane process-info --pane "$pane" \
  | jq -r --arg vim "$vim_re" \
      '[.result.process_info.foreground_processes[]?.name | ascii_downcase | test($vim)] | any')"
if [ "$is_vim" = true ]; then
  exec "$herdr" pane send-keys "$pane" "$key"
fi

# Non-Vim pane: prefer Herdr neighbors, then the outer Kitty window.
if focus="$("$herdr" pane focus --direction "$dir" --pane "$pane" \
  | jq -r '.result.focus | if .changed then "changed" else .reason end')"; then
  if [ "$focus" = changed ]; then
    exit 0
  fi
  if [ "$focus" = no_neighbor ] && [ -n "${KITTY_LISTEN_ON:-}" ]; then
    runtime_dir="${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}"
    IFS= read -r kitty_socket < "$runtime_dir/smart-splits-herdr-kitty"
    if kitten @ --to "$kitty_socket" focus-window --match "neighbor:$kitty_dir" 2>/dev/null; then
      exit 0
    fi
  fi
fi
# No neighbor: preserve the app's key (shell C-l = clear, etc.).
exec "$herdr" pane send-keys "$pane" "$key"
