# Fast H3 — Latest ComfyUI

Public copy of [pareekshit28/comfyui-fast-h3](https://github.com/pareekshit28/comfyui-fast-h3), preserving its Git history and workflows.
ComfyUI workflow Dockerized via [comfyui-wizard](https://comfy.getrunpod.io).
Submission: https://comfy.getrunpod.io/dashboard/submissions/kd7b1gsznzd2rr7bfyp563ct158gp984
## ComfyUI update

The Dockerfile fetches the latest ComfyUI development source from `master` during the image build, then installs that checkout's requirements into the worker's `/opt/venv` runtime. It retains the base image's transformers/huggingface-hub compatibility constraints, model downloads, and RunPod startup handler.

- `COMFYUI_REF` defaults to `master`; set it to a tag or commit for a repeatable version.
- `COMFYUI_UPDATE` defaults to `1`. Change it for a new build to invalidate the update layer while reusing cached model downloads. For RunPod GitHub builds, increment its Dockerfile default before triggering the next build.
- The selected commit is recorded at `/comfyui/COMFYUI_BUILD_COMMIT` inside the image.
- Image builds check that `BlockSparseAttention` imports and that ComfyUI initializes on CPU. These are build checks, not a GPU render test.

Example refresh with locally cached model layers:

```bash
docker buildx build --platform linux/amd64 --build-arg COMFYUI_UPDATE=2 --load -t my-comfy-workflow .
```

Docker build and live GPU rendering have not been verified for this change.

## Build it yourself
```bash
docker buildx build -t my-comfy-workflow .
docker run --rm --gpus all -p 8188:8188 my-comfy-workflow
```
If the workflow uses gated HuggingFace or CivitAI models, pass tokens at build time as BuildKit secrets (never as `--build-arg`, which would bake them into the image history):
```bash
export HF_TOKEN=...  CIVITAI_API_KEY=...
docker buildx build \
  --secret id=hf_token,env=HF_TOKEN \
  --secret id=civitai_api_key,env=CIVITAI_API_KEY \
  -t my-comfy-workflow .
```
## Deploy on Runpod
1. Connect this repository at https://runpod.io/console/serverless
2. Create a new endpoint, select **Deploy from GitHub**
3. Pick `pareekshit28/comfyui-fast-h3-latest`, branch `main`, Dockerfile path `/Dockerfile`, and endpoint type **Queue**
4. Runpod's builder will build the Dockerfile and host the resulting image
5. Hit the endpoint with the API workflow JSON (`api-workflow.json` in this repo)
## Files
- `Dockerfile` — generated model downloads plus build-time ComfyUI update and CPU checks
- `workflow.json` — the raw workflow, as you designed it in ComfyUI
- `api-workflow.json` — converted to ComfyUI's `/prompt` API shape (use this for serverless)
- `README.md` — this file