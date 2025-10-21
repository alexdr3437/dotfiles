#!/usr/bin/env bash
layout="${ZELLIJ_LAYOUT:-$HOME/.config/zellij/layouts/tires.kdl}"

inside() { [ -n "$ZELLIJ" ]; }
exists() { zellij list-sessions | grep -q tires; }
is_exited() { zellij list-sessions | grep -E "tires " | grep -q "(EXITED"; }

if inside; then
    if exists && ! is_exited; then
        zellij action switch-session --name tires 2>/dev/null && exit 0
        # fallback: detach then attach if switch failed
        zellij action detach
        zellij attach tires
    elif exists && is_exited; then
        zellij action detach
        zellij attach tires
    else
        zellij action detach
        zellij -n tires -s tires
    fi
else
	echo "Not inside zellij"
    if exists && ! is_exited; then
		echo "trying to attach to existing session"
        zellij attach tires
    elif exists && is_exited; then
		echo "reattaching to exited session"
        zellij attach tires
    else
		echo "creating new session"
		zellij delete-session tires
        zellij -n tires -s tires
    fi
fi
