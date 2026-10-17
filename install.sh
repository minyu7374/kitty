#!/bin/bash
# set -x

code_dir="$(cd "$(dirname "$0")" && pwd)"

kitty_dir=~/.config/kitty
mkdir -p "$kitty_dir"

session_tabs="${KITTY_SESSION_TABS:-main,herdr,tool}"
IFS=',' read -r -a selected_tabs <<<"$session_tabs"

(
    for tab_name in "${selected_tabs[@]}"; do
        cat "$code_dir/session.d/$tab_name.conf"
        printf '\n'
    done
) >"$kitty_dir/session.conf"

ln -nsf "$code_dir/session.d" "$kitty_dir/session.d"

cd "$kitty_dir" || exit 1
ln -sf "$code_dir"/*.py .
#find "$code_dir" -maxdepth 1 -name "*.conf" ! -name "*-macos.conf" -print0 | xargs -0 ln -sf -t .
find "$code_dir" -maxdepth 1 -name "*.conf" ! -name "*-macos.conf" -exec ln -sf {} . \;

# ln -sf "$code_dir"/kitty.sh ~/.sh.d/
cp -f "$code_dir"/kitty.sh ~/.sh.d/

local_conf_dir="$HOME/.config"
if [[ "$(uname -s)" == Darwin ]]; then
    local_conf_dir="$HOME/Library/Application Support/"
    for conf_name in kitty-ext open-actions; do
        ln -sf {"$code_dir/${conf_name}-macos",$conf_name}.conf
    done
else
    ln -sf "$code_dir"/kitty-tool.desktop ~/.local/share/applications/
fi
mkdir -p "$local_conf_dir" && ln -nsf {"$code_dir","$local_conf_dir"}/clock-rs

# 其他三方组件安装
# # vim-kitty-navigator
# for file in get_layout.py pass_keys.py; do
#   wget https://raw.githubusercontent.com/knubie/vim-kitty-navigator/refs/heads/master/$file -O $file
# done
# smart-splits v3 通过 socket 通信；Shell 方向缩放使用仓库内的 relative_resize.py。

printf '\nCompanion configs are not installed automatically.\n'

printf '\ntmux:\n'
printf 'Merge %s into %s.\n' "$code_dir/tmux/tmux.conf" "$HOME/.tmux.conf"
printf 'Refer to %s for predefined session management.\n' "$code_dir/tmux/tmuxrc"

printf '\nHerdr:\n'
printf 'Merge %s into %s.\n' "$code_dir/herdr/workspace-management.toml" "$HOME/.config/herdr/config.toml"
printf 'Install the shared smart-splits v3 backend and Herdr navigation plugin:\n'
printf '  bash %s\n' "$code_dir/herdr/install.sh"
