#!/bin/bash

set -e

# ---------------------------------------------------------------------------- #

# avoid 'root' user when run as sudo
# $(user) is better than ${USER}
user() {
    echo ${SUDO_USER:-${USER}}
}

# $(home) is better than ${HOME}
home() {
    grep "^$(user):" /etc/passwd | awk -F: '{print $6}'
}

# drop root user privilege when run as sudo
as_user() {
    if [ -z ${SUDO_USER} ]; then
        "$@"
    else
        sudo -u "${SUDO_USER}" -- "$@"
    fi
}

# ---------------------------------------------------------------------------- #

REINSTALL=no
DOTFILES=${DOTFILES:-"$(home)/.dotfiles"}

# ---------------------------------------------------------------------------- #

if [ -t 1 ]; then
    RED=$(printf '\033[31m')
    GREEN=$(printf '\033[32m')
    YELLOW=$(printf '\033[33m')
    BLUE=$(printf '\033[34m')
    RESET=$(printf '\033[m')
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    RESET=""
fi

fmt_error() {
    echo ${RED}"ERROR: $@"${RESET}
}

fmt_warning() {
    echo ${YELLOW}"$@"${RESET}
}

fmt_info() {
    echo ${GREEN}"$@"${RESET}
}

fmt_path() {
    echo "${@/$(home)/'~'}"
}

# ---------------------------------------------------------------------------- #

reinstall() {
    [ $REINSTALL = yes ]
}

command_exists() {
	command -v "$@" >/dev/null 2>&1
}

dir_exists() {
    [ -d "$@" ]
}

file_exists() {
    [ -f "$@" ]
}

symlink_exists() {
    [ -L "$@" ]
}

resolve_path() {
    retval=
    while read -r pathseg; do
        case "$pathseg" in
            '') ;;
            .)  if [ -z "${retval}" ]; then retval="$(readlink -f .)"; fi ;;
            ..) if [ -z "${retval}" ]; then retval="$(readlink -f ..)"; else retval="${retval%/*}"; fi ;;
            *)  if [ -z "${retval}" ]; then retval="$(readlink -f .)/${pathseg}"; else retval="${retval%/}/${pathseg}"; fi ;;
        esac
        if [ -z "${retval}" ]; then retval="/"; fi
    done <<< "$(sed 's/\//\n/g' <<< "$@")"
    echo "${retval}"
}

# ---------------------------------------------------------------------------- #

setup_dotfiles() {
    reinstall && as_user rm -rf "$DOTFILES"
    if dir_exists "$DOTFILES"; then
        fmt_warning "$(fmt_path "$DOTFILES") directory already exists, use --reinstall option to overwrite"
        return
    fi
    fmt_info "Install dotfiles"
    as_user git clone https://github.com/chandr3sh/dotfiles.git "$DOTFILES"
}

symlink() {
    if [ $# -ne 2 ]; then fmt_error "$(ln --help)"; fi
    bkp_save="$2.pre-dotfiles"
    if symlink_exists "$2"; then
        fmt_warning "$(fmt_path "$2") link already exists, it will be overwritten"
        as_user unlink "$2"
    elif file_exists "$2" && ! file_exists "$bkp_save"; then
        fmt_warning "$(fmt_path "$2") file already exists, saved as $(fmt_path "$bkp_save")"
        as_user mv "$2" "$bkp_save"
    fi
    fmt_info "symlink: $(fmt_path "$2") -> $(fmt_path "$1")"
    as_user ln -sr "$1" "$2"
}

setup_symlinks() {
    symlink "$DOTFILES/.bashrc" "$(home)/.bashrc"
}

# ---------------------------------------------------------------------------- #

main() {

    if [ $(id -u) -ne 0 ]; then
        fmt_error "Please run as root"
        exit 1
    fi

    if ! command_exists git; then
        apt install -y git
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
        --reinstall) REINSTALL=yes ;;
        --dotfiles) if [ ! -z "$2" ]; then DOTFILES="$(resolve_path "$2")"; shift; fi ;;
        esac
        shift
    done

    setup_dotfiles
    setup_symlinks
}

main "$@"