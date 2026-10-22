#!/bin/bash
# render.sh <name>: renders <name>.html at its .stage size to out/<name>.png (blog/_asset_sources/listen.md explains the shots/ and frames/ folders)
cd "$(dirname "$0")"; mkdir -p out
size=$(grep -o 'class="stage[^"]*" style="width:[0-9]*px;height:[0-9]*px' "$1.html" | head -1 | sed -E 's/.*width:([0-9]+)px;height:([0-9]+)px/\1,\2/')
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars \
  --allow-file-access-from-files --force-device-scale-factor=1 --default-background-color=00000000 \
  --virtual-time-budget=4000 --window-size="$size" --screenshot="out/$1.png" "file://$PWD/$1.html" 2>/dev/null
echo "rendered out/$1.png at $size"
