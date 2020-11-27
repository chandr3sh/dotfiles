#!/bin/bash

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

DOTFILES="$(home)/.dotfiles"

# ---------------------------------------------------------------------------- #

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

# ---------------------------------------------------------------------------- #


setup_dotfiles() {
    if dir_exists "$DOTFILES"; then
        return
    fi
    as_user git clone https://github.com/chandr3sh/dotfiles.git "$DOTFILES"
}

setup_symlinks() {
    for file in $(find "$DOTFILES" -maxdepth 1 -type f -name ".*"); do
        LINK_NAME="$(home)/$(basename $file)"
        TARGET="$DOTFILES/$(basename $file)"
        if symlink_exists "$LINK_NAME"; then
            as_user unlink "$LINK_NAME"
        elif file_exists "$LINK_NAME"; then
            as_user rm "$LINK_NAME"
        fi
        as_user ln -sr "$TARGET" "$LINK_NAME"
    done
}

# ---------------------------------------------------------------------------- #

main() {

    if [ $(id -u) -ne 0 ]; then
        echo "Please run as root"
        exit 1
    fi

    if ! command_exists git; then
        apt install -y git
    fi

    setup_dotfiles
    setup_symlinks
}

main "$@"