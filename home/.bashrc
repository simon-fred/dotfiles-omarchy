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

# dotnet global tools (dotnet-ef m.fl.)
export PATH="$HOME/.dotnet/tools:$PATH"

# ASP.NET Core dev-certs HTTPS trust för OpenSSL-baserade klienter (curl m.fl.)
export SSL_CERT_DIR="$HOME/.aspnet/dev-certs/trust:/etc/ssl/certs"

# Pinna self-checkin SQL Server 2025-containern till P-cores (0-11) på denna
# Core Ultra 9 185H — workaround för sosnumap.cpp-assertet på hybrid-CPU.
# Läses av backend/docker-compose.base.yml.
export SQLSERVER_CPUSET=0-11
