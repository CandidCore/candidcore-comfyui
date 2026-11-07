<p align="center"><img src="brand/banner.png" alt="Candidcore" width="100%"></p>

# CANDIDCORE FOR COMFYUI

A ready ComfyUI for RunPod, built to run the Candidcore workflows. Start a pod, install the Candidcore nodes once, and you are working.

Candidcore makes candid, phone-photo-style images of **invented adult characters**, and the tools to finish, plan and post them.

## What is inside

- ComfyUI, pinned to the version the workflows were tested on
- ComfyUI's Manager, switched on from the first start (the Manager button: install missing nodes, update, model manager)
- rgthree-comfy (MIT), for the Power Lora Loader in the starter workflow
- Python, PyTorch (CUDA 12.8, RTX 4090 and 5090) and ffmpeg

Not inside: the Candidcore nodes and workflows (they come in your download), model files, LoRAs and keys. Those stay on your volume.

## Run it on RunPod

1. RunPod → **Templates** → **New Template**.
2. **Container image:** `ghcr.io/candidcore/candidcore-comfyui:latest`
3. **HTTP port:** `8188`.
4. **Volume mount path:** `/workspace`, with a network volume attached.
5. Deploy a pod from the template and press **Connect to HTTP Service [8188]**.

## Install the Candidcore nodes

**With your link (recommended).** In your copy of the template, add an environment variable `CANDIDCORE_LINK` and paste the download link from your order. On the next start the pod fetches your package, installs the nodes and puts the workflows in the workflow list under **Candidcore**. It only does this again when the link changes, so a new version means a new link.

**By hand.** In the pod's terminal, with `candidcore_nodes.zip` and `install_candidcore.sh` from your download in the current folder:

```bash
bash install_candidcore.sh candidcore_nodes.zip
```

Either way the nodes are kept on your volume and linked in again on every start.

Put your model files in `/workspace/ComfyUI/models/` (the guide lists which files and where each goes). Your images land in `/workspace/ComfyUI/output/Candidcore/`.

## Update the image

Push a change to `main`. GitHub builds the image (`.github/workflows/build.yml`) and tags it `latest` and with the number in `VERSION`.

## Three rules

- Every character is invented and clearly an adult. No real person, no lookalike.
- Nothing here hides that an image is AI-generated. Label your posts where a platform asks for it.
- Your API keys stay on your machine, never in a workflow or an image.

Candidcore is not affiliated with ComfyUI, RunPod, Anthropic or any model author. Their names belong to them, and their terms apply to their software and models.
