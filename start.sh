#!/usr/bin/env bash
set -e

COMFY=/opt/ComfyUI
VOL=/workspace/ComfyUI   # your volume: models, input, output and your own workflows live here

echo ">> Candidcore for ComfyUI starting ($(date))"

# Link the folders you want to keep from the volume. Code and nodes stay in the image.
for d in models input output user; do
  mkdir -p "$VOL/$d"
  rm -rf "$COMFY/$d"
  ln -s "$VOL/$d" "$COMFY/$d"
done

# The Candidcore nodes: install_candidcore.sh keeps them on the volume, so link them in again on every start.
KEEP=/workspace/candidcore_extra/candidcore_nodes
if [ -f "$KEEP/__init__.py" ]; then
  rm -rf "$COMFY/custom_nodes/candidcore_nodes"
  ln -s "$KEEP" "$COMFY/custom_nodes/candidcore_nodes"
  echo ">> Candidcore nodes linked"
else
  echo ">> Candidcore nodes not installed yet: run install_candidcore.sh from your download, then restart the pod"
fi

# Your own extra nodes: every folder in $VOL/extra_nodes with an __init__.py is linked, unless the image has that node.
mkdir -p "$VOL/extra_nodes"
for n in "$VOL"/extra_nodes/*/; do
  name="$(basename "$n")"
  if [ -f "$n/__init__.py" ] && [ ! -e "$COMFY/custom_nodes/$name" ]; then
    ln -s "${n%/}" "$COMFY/custom_nodes/$name"
    echo ">> extra node linked: $name"
  fi
done

cd "$COMFY"
exec /opt/venv/bin/python main.py --listen 0.0.0.0 --port 8188 "$@"
