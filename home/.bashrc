# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source ~/.local/share/omarchy/default/bash/rc

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'
alias gs='git status'
alias devserver='tdev ~/Projects/self-checkin'

# nvm (Arch-paketet levererar init-helper:n)
# Omarchy default kör `set +h` för mise; nvm anropar internt `hash -r`, vilket
# annars triggar "bash: hash: hashing disabled" vid shell-start. Slå på
# hashing tillfälligt under init.
set -h
source /usr/share/nvm/init-nvm.sh
set +h
