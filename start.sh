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

# custom_nodes lives on the volume, so nodes you install with the Manager survive a stop.
# The image's own nodes (Manager, rgthree, Impact Pack and Subpack) are linked in; a folder of your own with the same name is left alone.
mkdir -p "$VOL/custom_nodes"
rm -rf "$COMFY/custom_nodes"
ln -s "$VOL/custom_nodes" "$COMFY/custom_nodes"
for n in /opt/baseline_nodes/*/; do
  t="$VOL/custom_nodes/$(basename "$n")"
  if [ -L "$t" ] || [ ! -e "$t" ]; then
    rm -f "$t"; ln -s "${n%/}" "$t"
  else
    echo ">> keeping your own $(basename "$n") in custom_nodes"
  fi
done

# A volume that ran another Manager (for example RunPod's own ComfyUI template) keeps a channel list that this Manager rejects,
# which makes "Custom Nodes Manager" fail with "Failed to get custom node list". Set the old list aside; a fresh one is written on start.
CH="$VOL/user/__manager/channels.list"
if grep -qs "Comfy-Org/ComfyUI-Manager" "$CH"; then
  mv "$CH" "$CH.bak"
  echo ">> Manager channel list from another setup set aside (channels.list.bak)"
fi

# One-link install: CANDIDCORE_LINK is the download link of your Candidcore package (set it in the template's environment variables).
# The package is fetched once per link and again when the link changes (a new version has a new link). A failure never stops ComfyUI.
install_from_link() {
  local tmp inst
  tmp=$(mktemp -d) || return 1
  # Accept: text/html because Shopify download links answer the plain curl default (Accept: */*) with a "file not found" page
  curl -fsSL -H 'Accept: text/html' --retry 3 --max-time 900 -o "$tmp/pkg.zip" "$CANDIDCORE_LINK" \
    || { echo ">> Candidcore download failed: check that the link is complete and has not expired"; rm -rf "$tmp"; return 1; }
  unzip -oq "$tmp/pkg.zip" -d "$tmp/pkg" \
    || { echo ">> Candidcore download is not a zip: check the link"; rm -rf "$tmp"; return 1; }
  inst=$(find "$tmp/pkg" -maxdepth 3 -name install_candidcore.sh | head -1)
  [ -n "$inst" ] || { echo ">> install_candidcore.sh not found in the package"; rm -rf "$tmp"; return 1; }
  local root; root=$(dirname "$(dirname "$inst")")
  CANDIDCORE_VOLUME=/workspace COMFYUI_DIR="$COMFY" bash "$inst" "$root/nodes/candidcore_nodes.zip" "$COMFY" > /dev/null \
    || { echo ">> Candidcore nodes could not be installed"; rm -rf "$tmp"; return 1; }
  if [ -d "$root/models" ]; then   # the model list and downloader that come with the package
    mkdir -p /workspace/candidcore_extra/models && cp "$root"/models/* /workspace/candidcore_extra/models/ 2>/dev/null || true
  fi
  mkdir -p "$VOL/user/default/workflows/Candidcore"
  cp "$root"/workflows/*.json "$VOL/user/default/workflows/Candidcore/" 2>/dev/null || true
  echo "$STAMP_NOW" > "$STAMP"
  rm -rf "$tmp"
  echo ">> Candidcore installed from your link: nodes and workflows (folder Candidcore in the workflow list)"
}

STAMP=/workspace/candidcore_extra/link.sha
if [ -n "${CANDIDCORE_LINK:-}" ]; then
  case "$CANDIDCORE_LINK" in
    http://*|https://*)
      STAMP_NOW=$(printf %s "$CANDIDCORE_LINK" | sha256sum | cut -d' ' -f1)   # the link itself is never stored
      if [ -f /workspace/candidcore_extra/candidcore_nodes/__init__.py ] && [ "$(cat "$STAMP" 2>/dev/null)" = "$STAMP_NOW" ]; then
        echo ">> Candidcore already installed from this link"
      else
        mkdir -p /workspace/candidcore_extra
        echo ">> Installing Candidcore from your link (first start with this link takes a minute)"
        install_from_link || true
      fi ;;
    *) echo ">> CANDIDCORE_LINK must be a web link starting with https://" ;;
  esac
fi

# Models: CANDIDCORE_MODELS (for example base, or base,qwen,loras) downloads those groups in the background; ComfyUI opens at once.
# Files that are already on the volume are skipped, so this is quick on later starts. CIVITAI_TOKEN is needed for the loras group.
if [ -n "${CANDIDCORE_MODELS:-}" ]; then
  DL=/workspace/candidcore_extra/models/download_models.sh
  if [ -f "$DL" ]; then
    echo ">> Downloading Candidcore models in the background ($CANDIDCORE_MODELS): press Refresh in ComfyUI when it says done"
    ( MODELS_DIR="$VOL/models" bash "$DL" "$CANDIDCORE_MODELS" 2>&1 | tee -a /workspace/candidcore_extra/models.log ) &
  else
    echo ">> CANDIDCORE_MODELS is set but the downloader is not installed yet: set CANDIDCORE_LINK with your package link"
  fi
fi

# The Candidcore nodes: install_candidcore.sh keeps them on the volume, so link them in again on every start.
KEEP=/workspace/candidcore_extra/candidcore_nodes
if [ -f "$KEEP/__init__.py" ]; then
  rm -rf "$COMFY/custom_nodes/candidcore_nodes"
  ln -s "$KEEP" "$COMFY/custom_nodes/candidcore_nodes"
  echo ">> Candidcore nodes linked"
else
  echo ">> Candidcore nodes not installed yet: set CANDIDCORE_LINK in the template, or run install_candidcore.sh from your download, then restart the pod"
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

# Python packages live in the image, so a fresh start loses what nodes installed earlier (for example with the Manager).
# Reinstall the requirements of every node on the volume; the pip cache on the volume keeps this quick. A failure never stops ComfyUI.
export PIP_CACHE_DIR=/workspace/candidcore_extra/pip-cache
for r in "$VOL"/custom_nodes/*/requirements.txt "$VOL"/extra_nodes/*/requirements.txt; do
  [ -f "$r" ] || continue
  case "$(readlink -f "$r")" in /opt/baseline_nodes/*) continue ;; esac   # the image's own nodes already have theirs
  name="$(basename "$(dirname "$r")")"
  if /opt/venv/bin/pip install -q -r "$r" > /dev/null 2>&1; then
    echo ">> requirements installed: $name"
  else
    echo ">> requirements of $name could not be installed: that node may not load"
  fi
done

cd "$COMFY"
# ComfyUI answers 403 to a page opened from another site (the RunPod link) unless CORS is switched on. The pod is already reachable by its link, so this adds no exposure.
exec /opt/venv/bin/python main.py --listen 0.0.0.0 --port 8188 --enable-cors-header "*" "$@"
