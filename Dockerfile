# syntax=docker/dockerfile:1

# clean base image containing only comfyui, comfy-cli and comfyui-manager
FROM runpod/worker-comfyui:5.10.0-base

# build-time tokens for gated downloads are read from BuildKit secret
# mounts — they are never written to a layer or to image history.
# pass via: docker buildx build --secret id=hf_token,env=HF_TOKEN .

# download models into comfyui
RUN --mount=type=secret,id=hf_token BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do HF_TOKEN="$(cat /run/secrets/hf_token 2>/dev/null || true)" comfy model download --url 'https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_video_vae_int8_convrot.safetensors' --relative-path models/vae --filename 'minimax_h3_video_vae_int8_convrot.safetensors' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done
RUN --mount=type=secret,id=hf_token BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do HF_TOKEN="$(cat /run/secrets/hf_token 2>/dev/null || true)" comfy model download --url 'https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_audio_vae_fp32.safetensors' --relative-path models/vae --filename 'minimax_h3_audio_vae_fp32.safetensors' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done
RUN --mount=type=secret,id=hf_token BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do HF_TOKEN="$(cat /run/secrets/hf_token 2>/dev/null || true)" comfy model download --url 'https://huggingface.co/FastVideo/FastH3-OmniRef-Comfy/resolve/main/diffusion_models/fasth3_omniref_8step_pruned_int8_convrot.safetensors' --relative-path models/diffusion_models --filename 'fasth3_omniref_8step_pruned_int8_convrot.safetensors' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done
RUN --mount=type=secret,id=hf_token BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do HF_TOKEN="$(cat /run/secrets/hf_token 2>/dev/null || true)" comfy model download --url 'https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors' --relative-path models/text_encoders --filename 'qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

# Update after model downloads so changing these arguments preserves their cache.
# master selects the latest development source when this layer actually runs.
# Set COMFYUI_REF to a tag or commit to reproduce a tested version.
# Bump COMFYUI_UPDATE on each new build to fetch again, e.g. --build-arg COMFYUI_UPDATE=2.
ARG COMFYUI_REF=master
ARG COMFYUI_UPDATE=1

RUN echo "Updating ComfyUI: ref=${COMFYUI_REF}, update=${COMFYUI_UPDATE}" \
    && git -C /comfyui fetch --depth 1 https://github.com/Comfy-Org/ComfyUI.git "${COMFYUI_REF}" \
    && git -C /comfyui checkout --detach FETCH_HEAD \
    && git -C /comfyui rev-parse HEAD > /comfyui/COMFYUI_BUILD_COMMIT \
    && /opt/venv/bin/python -m pip install --no-cache-dir \
       -r /comfyui/requirements.txt \
       "transformers>=4.50.3,<5" "huggingface-hub<1.0"

# Disable the model compiler (including CUDA graphs) for the OOM comparison.
# Patch both startup modes while retaining the inherited RunPod handler.
RUN sed -i 's|/comfyui/main[.]py |/comfyui/main.py --disable-comfy-compiler |g' /start.sh

# Match the base image's transformer/hub constraints and runtime Python above.
# Fail the image build if the sparse-attention module cannot import or ComfyUI
# cannot initialize on CPU. This does not run a model or verify GPU rendering.
RUN cd /comfyui \
    && /opt/venv/bin/python -c 'import sys; sys.argv = ["verify_nodes", "--cpu", "--disable-comfy-compiler"]; import comfy.options; comfy.options.enable_args_parsing(); from comfy_extras.nodes_sparse_attention import BlockSparseAttention; print("BlockSparseAttention import OK")' \
    && timeout 300 /opt/venv/bin/python main.py --quick-test-for-ci --cpu --disable-comfy-compiler

# Retain the base image's /start.sh command and RunPod handler.
