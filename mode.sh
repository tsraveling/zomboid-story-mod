#!/usr/bin/env bash
# Switches the game between the local repo mod (symlink in ~/Zomboid/mods) and the subscribed Workshop copy.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
ENV="$ROOT/.deploy.env"
LINK="$HOME/Zomboid/mods/CDCLastHope"
OLD_STAGE="$HOME/Zomboid/Workshop/CDCLastHope"
LOG="$HOME/Zomboid/console.txt"

[[ -f "$ENV" ]] && source "$ENV"
STEAM_COPY="$HOME/Library/Application Support/Steam/steamapps/workshop/content/108600/${WORKSHOP_ID:-0}"
# Steam copy is parked here in local mode; the game loads it over the symlink otherwise
HIDDEN="$ROOT/.deploy/workshop-hidden"

# stale pre-.deploy/stage copy shadows both modes
warn_old_stage() {
    [[ -e "$OLD_STAGE" ]] && echo "warning: $OLD_STAGE still exists and shadows the mod; delete it" >&2
    return 0
}

status() {
    if [[ -L "$LINK" ]]; then
        echo "mode: local ($LINK -> $(readlink "$LINK"))"
    elif [[ -e "$LINK" ]]; then
        echo "mode: unknown ($LINK is not a symlink)"
    else
        echo "mode: workshop"
    fi
    if [[ -d "$HIDDEN" ]]; then
        echo "steam copy: hidden in $HIDDEN"
    elif [[ -d "$STEAM_COPY" ]]; then
        echo "steam copy: $(stat -f '%Sm' "$STEAM_COPY/mods/CDCLastHope" 2>/dev/null || stat -f '%Sm' "$STEAM_COPY")"
    else
        echo "steam copy: not installed (subscribe to ${WORKSHOP_ID:-?} in Steam)"
    fi
    if [[ -f "$LOG" ]]; then
        echo "last run ($(stat -f '%Sm' "$LOG")) loaded from:"
        grep -o -E '/Users/[^ ]*CDCLastHope' "$LOG" | sort -u | sed 's/^/  /' || echo "  (no path in log)"
    fi
    warn_old_stage
}

case "${1:-status}" in
    local)
        if [[ -e "$LINK" && ! -L "$LINK" ]]; then
            echo "$LINK exists and is not a symlink; refusing to replace" >&2
            exit 1
        fi
        if [[ -d "$STEAM_COPY" ]]; then
            [[ -e "$HIDDEN" ]] && { echo "$HIDDEN already exists; refusing to overwrite" >&2; exit 1; }
            mkdir -p "$(dirname "$HIDDEN")"
            mv "$STEAM_COPY" "$HIDDEN"
            echo "steam copy hidden in $HIDDEN"
        fi
        ln -sfn "$ROOT/CDCLastHope" "$LINK"
        echo "local: $LINK -> $ROOT/CDCLastHope"
        warn_old_stage
        ;;
    workshop)
        [[ -L "$LINK" ]] && rm "$LINK"
        if [[ -d "$HIDDEN" ]]; then
            if [[ -e "$STEAM_COPY" ]]; then
                echo "warning: Steam re-downloaded $STEAM_COPY; leaving $HIDDEN in place" >&2
            else
                mv "$HIDDEN" "$STEAM_COPY"
                echo "steam copy restored"
            fi
        fi
        echo "workshop: local symlink removed; game uses subscribed copy"
        [[ -d "$STEAM_COPY" ]] || echo "warning: steam copy not installed at $STEAM_COPY" >&2
        warn_old_stage
        ;;
    status) status ;;
    *) echo "usage: $0 [local|workshop|status]" >&2; exit 1 ;;
esac
