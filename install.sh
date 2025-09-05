#!/bin/bash
# set -x

code_dir="$(cd "$(dirname "$0")" && pwd)"

kitty_dir=~/.config/kitty
mkdir -p "$kitty_dir"

cd "$kitty_dir" || exit 1
ln -sf "$code_dir"/*.py .
find "$code_dir" -maxdepth 1 -name "*.conf" ! -name "*-macos.conf" -print0 | xargs -0 ln -sf -t .
# ln -sf "$code_dir"/kitty.sh ~/.sh.d/
cp -f "$code_dir"/kitty.sh ~/.sh.d/

if [[ "$(uname -s)" == Darwin ]]; then
    for conf_name in kitty-ext open-actions; do
        ln -sf {"$code_dir/${conf_name}-macos",$conf_name}.conf
    done
else
    ln -sf "$code_dir"/kitty-tool.desktop ~/.local/share/applications/
fi

# 其他三方组件安装
# vim-kitty-navigator
wget https://raw.githubusercontent.com/knubie/vim-kitty-navigator/refs/heads/master/get_layout.py -O get_layout.py
wget https://raw.githubusercontent.com/knubie/vim-kitty-navigator/refs/heads/master/pass_keys.py -O pass_keys.py

# termpdf.py
{ [[ -d termpdf.py ]] || git clone https://github.com/dsanson/termpdf.py; } &&
    cd termpdf.py && pip install -r requirements.txt
