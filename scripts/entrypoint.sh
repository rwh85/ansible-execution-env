#!/bin/bash
set -e

# Fix SSH key permissions if mounted
if [ -d "$HOME/.ssh" ]; then
    # Copy to writable location if mounted read-only
    if ! touch "$HOME/.ssh/.write_test" 2>/dev/null; then
        cp -r "$HOME/.ssh" "$HOME/.ssh-tmp"
        export HOME_SSH="$HOME/.ssh-tmp"
    else
        rm -f "$HOME/.ssh/.write_test"
        export HOME_SSH="$HOME/.ssh"
    fi
    chmod 700 "$HOME_SSH" 2>/dev/null || true
    chmod 600 "$HOME_SSH"/* 2>/dev/null || true
    chmod 644 "$HOME_SSH"/*.pub 2>/dev/null || true
    chmod 644 "$HOME_SSH"/known_hosts 2>/dev/null || true
    chmod 644 "$HOME_SSH"/config 2>/dev/null || true

    # Start SSH agent if keys exist
    if ls "$HOME_SSH"/id_* 1>/dev/null 2>&1; then
        eval "$(ssh-agent -s)" >/dev/null 2>&1
        for key in "$HOME_SSH"/id_*; do
            [ -f "$key" ] && [[ "$key" != *.pub ]] && ssh-add "$key" 2>/dev/null || true
        done
    fi
fi

exec "$@"
