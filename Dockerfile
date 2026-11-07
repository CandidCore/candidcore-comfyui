# Candidcore for ComfyUI: a ready ComfyUI for RunPod, built to run the Candidcore workflows.
# The Candidcore nodes and workflows are not in this image: you install them from your download (install_candidcore.sh).
# Models and your own files live on the volume (/workspace), never in the image.

# CUDA 12.8 covers RTX 4090 and RTX 5090 (Blackwell).
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-venv python3-dev git ffmpeg libgl1 libglib2.0-0 \
      fonts-dejavu-core curl ca-certificates unzip \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"
RUN pip install --upgrade pip

# The Qwen Image 2.1 nodes need ComfyUI 0.43 or newer. 0.44.1 is the version the workflows were tested on.
ARG COMFYUI_REF=v0.44.1
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /opt/ComfyUI \
    && cd /opt/ComfyUI && git checkout ${COMFYUI_REF}
WORKDIR /opt/ComfyUI

RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
RUN pip install -r requirements.txt

# Nodes that belong to the image live in /opt/baseline_nodes. start.sh links them into custom_nodes on the volume,
# so nodes you install later survive a stop and the image's own nodes still update with the image.
RUN mkdir -p /opt/baseline_nodes

# The classic ComfyUI Manager (the blue Manager button in the top bar): install missing nodes, update, model manager.
# GPL-3.0, cloned at build time and pinned. It is a custom node, so ComfyUI is started without --enable-manager.
ARG MANAGER_REF=bd88cffa7166484cbd16c3eba8a5a377a20b01dc
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git /opt/baseline_nodes/ComfyUI-Manager \
    && git -C /opt/baseline_nodes/ComfyUI-Manager checkout ${MANAGER_REF} \
    && pip install -r /opt/baseline_nodes/ComfyUI-Manager/requirements.txt \
    && python -c "import git, toml, chardet"

# The Manager's dialogs come out transparent in the current ComfyUI frontend; this small node gives them a background.
COPY ui_fix /opt/baseline_nodes/candidcore_ui_fix

# rgthree-comfy (MIT) gives the Power Lora Loader that one starter workflow uses.
ARG RGTHREE_REF=bc48c6aaeca87bedbc14245d89f9bc6be37a630e
RUN git clone https://github.com/rgthree/rgthree-comfy.git /opt/baseline_nodes/rgthree-comfy \
    && git -C /opt/baseline_nodes/rgthree-comfy checkout ${RGTHREE_REF} \
    && if [ -f /opt/baseline_nodes/rgthree-comfy/requirements.txt ]; then pip install -r /opt/baseline_nodes/rgthree-comfy/requirements.txt; fi

# Fail the build if torch or the libraries the nodes use cannot import.
RUN python -c "import torch, PIL, scipy, av; print('torch', torch.__version__)"

RUN find /opt/ComfyUI -name "__pycache__" -type d -prune -exec rm -rf {} + || true

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8188
ENTRYPOINT ["/start.sh"]
