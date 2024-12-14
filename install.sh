#!/bin/bash

code_dir="$(cd "$(dirname "$0")" && pwd)"

kitty_dir=~/.config/kitty
mkdir -p "$kitty_dir"
cd "$kitty_dir" || exit 1

ln -sf "$code_dir"/*.conf "$code_dir"/*.py .
ln -sf "$code_dir"/kitty.sh ~/.sh.d/

[[ "$(uname -s)" == Darwin ]] && _os=macos || _os=gentoo
ln -sf font_size-"${_os}".conf font_size.conf

# 其他三方组件安装
# vim-kitty-navigator
wget https://raw.githubusercontent.com/knubie/vim-kitty-navigator/refs/heads/master/get_layout.py -O get_layout.py
wget https://raw.githubusercontent.com/knubie/vim-kitty-navigator/refs/heads/master/pass_keys.py -O pass_keys.py

# termpdf.py
git clone https://github.com/dsanson/termpdf.py && \
    cd termpdf.py && pip install -r requirements.txt
