#!/bin/bash

alias ls='ls --color=auto --hyperlink=always'

alias kt='kitty +kitten'
alias kcat='kitty +kitten icat'
alias kssh='kitty +kitten ssh'
alias kdiff='kitty +kitten diff'
alias kgrep='kitty +kitten hyperlinked_grep --smart-case'
alias kcb='kitty +kitten clipboard'
alias kcbp='kitty +kitten clipboard -p'

alias kpdf='"$HOME"/.config/kitty/termpdf.py/termpdf.py'

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

alias ka=kcat kat=kcat ks=kssh kd=kdiff kg=kgrep kc=kcb kp=kplot
