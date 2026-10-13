#!/usr/bin/env bash
# Compiles the story, stages the mod in ~/Zomboid/Workshop, and uploads it to the Steam Workshop via steamcmd.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
ENV="$ROOT/.deploy.env"
STAGE="$HOME/Zomboid/Workshop/CDCLastHope"
VDF="$ROOT/.deploy/workshop.vdf"
TITLE="CDC Last Hope"

[[ -f "$ENV" ]] || { echo "missing .deploy.env; copy .deploy.env.example" >&2; exit 1; }
source "$ENV"
[[ -n "${STEAM_USER:-}" ]] || { echo "STEAM_USER not set in .deploy.env" >&2; exit 1; }
command -v steamcmd >/dev/null || { echo "steamcmd not found" >&2; exit 1; }

VERSION="$(sed -n 's/^modversion=//p' "$ROOT/CDCLastHope/42/mod.info")"
SHA="$(git -C "$ROOT" rev-parse --short HEAD)"
DIRTY=""
if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
    DIRTY="-dirty"
    echo "warning: uncommitted changes will be uploaded" >&2
fi
NOTE="${1:-v$VERSION ($SHA$DIRTY)}"

"$ROOT/compile.sh"

mkdir -p "$STAGE/Contents/mods" "$(dirname "$VDF")"
rsync -a --delete --exclude '.DS_Store' "$ROOT/CDCLastHope/" "$STAGE/Contents/mods/CDCLastHope/"
cp "$ROOT/CDCLastHope/poster.png" "$STAGE/preview.png"

DESC="$(sed -n 's/^description=//p' "$ROOT/CDCLastHope/mod.info")"
cat > "$VDF" <<VDF
"workshopitem"
{
    "appid"           "108600"
    "publishedfileid" "${WORKSHOP_ID:-0}"
    "contentfolder"   "$STAGE/Contents"
    "previewfile"     "$STAGE/preview.png"
    "visibility"      "${VISIBILITY:-3}"
    "title"           "$TITLE"
    "description"     "$DESC"
    "changenote"      "$NOTE"
}
VDF

echo "uploading v$VERSION as ${WORKSHOP_ID:-new item}: $NOTE"
steamcmd +login "$STEAM_USER" +workshop_build_item "$VDF" +quit

if [[ -z "${WORKSHOP_ID:-}" ]]; then
    ID="$(sed -n 's/.*"publishedfileid"[[:space:]]*"\([0-9]*\)".*/\1/p' "$VDF")"
    if [[ -n "$ID" && "$ID" != "0" ]]; then
        sed -i '' "s/^WORKSHOP_ID=.*/WORKSHOP_ID=$ID/" "$ENV"
        echo "created workshop item $ID; saved to .deploy.env"
    else
        echo "could not read new item id from $VDF; set WORKSHOP_ID manually" >&2
    fi
fi

echo "done. restart the server to pull the update."
