#!/usr/bin/env bash
set -euo pipefail

source_dir="$(cd "$(dirname "$0")" && pwd)/smart-splits"
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}"
target="$data_dir/smart-splits-herdr"

mkdir -p "$data_dir"
ln -sfn "$source_dir" "$target"
herdr plugin link "$target"
printf 'Shared Herdr backend installed at %s\n' "$target"
