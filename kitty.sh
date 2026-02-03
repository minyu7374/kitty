#!/bin/bash

# alias ls='ls --color=auto --hyperlink=always'
alias rg="rg --hyperlink-format=kitty --smart-case"

alias kt='kitty +kitten'
alias kcat='kitty +kitten icat'
alias kssh='kitty +kitten ssh'
alias kdiff='kitty +kitten diff'
alias kgrep='kitty +kitten hyperlinked_grep --smart-case'
alias kcby='kitty +kitten clipboard'
alias kcbp='kitty +kitten clipboard -g'
alias kpdf='"$HOME"/.config/kitty/termpdf.py/termpdf.py'
alias kgdiff='git difftool -t kitty'

function kplot {
    cat <<EOF | gnuplot
    set terminal pngcairo enhanced font 'Fira Sans,10'
    set autoscale
    set samples 1000
    set output '|kitten icat --stdin yes'
    set object 1 rectangle from screen 0,0 to screen 1,1 fillcolor rgb"#fdf6e3" behind
    plot $@
    set output '/dev/null'
EOF
}

alias kat=kcat ks=kssh kd=kdiff kgd=kgdiff kg=kgrep kp=kplot
