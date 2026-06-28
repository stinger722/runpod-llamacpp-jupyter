#!/usr/bin/env bash
set -euo pipefail

export HF_HOME="${HF_HOME:-/workspace/.cache/huggingface}"
export HF_HUB_CACHE="${HF_HUB_CACHE:-/workspace/.cache/huggingface/hub}"
export HF_XET_CACHE="${HF_XET_CACHE:-/workspace/.cache/huggingface/xet}"
export TMPDIR="${TMPDIR:-/workspace/tmp}"
export TEMP="${TEMP:-/workspace/tmp}"
export TMP="${TMP:-/workspace/tmp}"
export HF_XET_HIGH_PERFORMANCE="${HF_XET_HIGH_PERFORMANCE:-1}"

MODEL_REPO="${MODEL_REPO:-}"
MODEL_FILE="${MODEL_FILE:-*.gguf}"
MODEL_DIR="${MODEL_DIR:-/workspace/models/model}"

PROJECTOR_REPO="${PROJECTOR_REPO:-}"
PROJECTOR_FILE="${PROJECTOR_FILE:-}"
PROJECTOR_DIR="${PROJECTOR_DIR:-/workspace/projectors/model}"

MODEL_PATH="${MODEL_PATH:-}"
MMPROJ_PATH="${MMPROJ_PATH:-}"

HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8080}"
CTX_SIZE="${CTX_SIZE:-32768}"
GPU_LAYERS="${GPU_LAYERS:-auto}"
PARALLEL="${PARALLEL:-1}"
LLAMA_EXTRA_ARGS="${LLAMA_EXTRA_ARGS:-}"

JUPYTER_ENABLE="${JUPYTER_ENABLE:-1}"
JUPYTER_PORT="${JUPYTER_PORT:-8888}"
JUPYTER_IP="${JUPYTER_IP:-0.0.0.0}"
JUPYTER_ROOT_DIR="${JUPYTER_ROOT_DIR:-/workspace}"

mkdir -p \
  "$MODEL_DIR" \
  "$PROJECTOR_DIR" \
  /workspace/models \
  /workspace/projectors \
  /workspace/ai-readable \
  "$HF_HUB_CACHE" \
  "$HF_XET_CACHE" \
  /workspace/tmp

start_jupyter() {
  if [ "$JUPYTER_ENABLE" != "1" ]; then
    echo "JupyterLab disabled: JUPYTER_ENABLE=$JUPYTER_ENABLE"
    return 0
  fi

  if ! command -v jupyter >/dev/null 2>&1; then
    echo "WARNING: jupyter command not found. Skipping JupyterLab."
    return 0
  fi

  if [ -z "${JUPYTER_TOKEN:-}" ]; then
    if command -v openssl >/dev/null 2>&1; then
      export JUPYTER_TOKEN="$(openssl rand -hex 32)"
      echo "WARNING: JUPYTER_TOKEN was not set, so a random token was generated."
      echo "WARNING: Set JUPYTER_TOKEN in the RunPod template for stable access."
    else
      echo "ERROR: JUPYTER_TOKEN is not set and openssl is unavailable."
      exit 1
    fi
  fi

  cat > /workspace/tmp/jupyter_server_config.py <<'PY'
import os

c.ServerApp.ip = os.environ.get("JUPYTER_IP", "0.0.0.0")
c.ServerApp.port = int(os.environ.get("JUPYTER_PORT", "8888"))
c.ServerApp.root_dir = os.environ.get("JUPYTER_ROOT_DIR", "/workspace")
c.ServerApp.open_browser = False
c.ServerApp.allow_root = True
c.ServerApp.token = os.environ.get("JUPYTER_TOKEN", "")
c.ServerApp.password = ""
c.ServerApp.allow_origin = "*"
PY

  echo "Starting JupyterLab on ${JUPYTER_IP}:${JUPYTER_PORT}, root=${JUPYTER_ROOT_DIR}"
  nohup jupyter lab --config=/workspace/tmp/jupyter_server_config.py \
    > /workspace/jupyter.log 2>&1 &
  JUPYTER_PID=$!
  echo "$JUPYTER_PID" > /workspace/tmp/jupyter.pid
}

find_first_gguf() {
  local dir="$1"
  local pattern="$2"
  find "$dir" -type f -name "$pattern" | sort | head -n 1
}

download_if_needed() {
  local repo="$1"
  local include_pattern="$2"
  local local_dir="$3"
  local label="$4"

  if find_first_gguf "$local_dir" "$include_pattern" | grep -q .; then
    echo "Existing $label found. Skipping $label download."
    return 0
  fi

  if [ -z "$repo" ]; then
    echo "ERROR: ${label} repo is not set and no matching GGUF exists in $local_dir"
    exit 1
  fi

  echo "Downloading $label from Hugging Face..."
  hf download "$repo" \
    --include "$include_pattern" \
    --local-dir "$local_dir"
}

echo "=== RunPod llama.cpp startup ==="
echo "MODEL_REPO=$MODEL_REPO"
echo "MODEL_FILE=$MODEL_FILE"
echo "MODEL_DIR=$MODEL_DIR"
echo "PROJECTOR_REPO=$PROJECTOR_REPO"
echo "PROJECTOR_FILE=$PROJECTOR_FILE"
echo "PROJECTOR_DIR=$PROJECTOR_DIR"
echo "CTX_SIZE=$CTX_SIZE"
echo "GPU_LAYERS=$GPU_LAYERS"
echo "PARALLEL=$PARALLEL"
echo "HOST=$HOST"
echo "PORT=$PORT"

start_jupyter

if [ -z "$MODEL_PATH" ]; then
  download_if_needed "$MODEL_REPO" "$MODEL_FILE" "$MODEL_DIR" "model"
  MODEL_PATH="$(find_first_gguf "$MODEL_DIR" "$MODEL_FILE")"
fi

if [ ! -f "$MODEL_PATH" ]; then
  echo "ERROR: Model file not found: $MODEL_PATH"
  exit 1
fi

EXTRA_ARGS=()

if [ -n "$MMPROJ_PATH" ]; then
  if [ -f "$MMPROJ_PATH" ]; then
    EXTRA_ARGS+=(--mmproj "$MMPROJ_PATH")
  else
    echo "WARNING: MMPROJ_PATH set but file not found: $MMPROJ_PATH"
  fi
else
  if [ -n "$PROJECTOR_REPO" ] && [ -n "$PROJECTOR_FILE" ]; then
    download_if_needed "$PROJECTOR_REPO" "$PROJECTOR_FILE" "$PROJECTOR_DIR" "projector"
    MMPROJ_PATH="$(find_first_gguf "$PROJECTOR_DIR" "$PROJECTOR_FILE")"

    if [ -f "$MMPROJ_PATH" ]; then
      EXTRA_ARGS+=(--mmproj "$MMPROJ_PATH")
    fi
  fi
fi

if [ -n "${LLAMA_API_KEY:-}" ]; then
  EXTRA_ARGS+=(--api-key "$LLAMA_API_KEY")
else
  echo "WARNING: LLAMA_API_KEY is not set. llama-server will be reachable without API-key auth."
fi

if [ -n "$GPU_LAYERS" ]; then
  EXTRA_ARGS+=(--n-gpu-layers "$GPU_LAYERS")
fi

if [ -n "$PARALLEL" ]; then
  EXTRA_ARGS+=(--parallel "$PARALLEL")
fi

# Optional raw extra arguments. Example:
# LLAMA_EXTRA_ARGS='--jinja --cache-reuse 256'
if [ -n "$LLAMA_EXTRA_ARGS" ]; then
  # shellcheck disable=SC2206
  EXTRA_ARGS+=($LLAMA_EXTRA_ARGS)
fi

cleanup() {
  if [ -f /workspace/tmp/jupyter.pid ]; then
    kill "$(cat /workspace/tmp/jupyter.pid)" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

echo "Starting llama-server..."
echo "Model: $MODEL_PATH"
echo "mmproj: ${MMPROJ_PATH:-none}"
echo "Context: $CTX_SIZE"
echo "API key: $([ -n "${LLAMA_API_KEY:-}" ] && echo enabled || echo disabled)"
echo "Jupyter log: /workspace/jupyter.log"

exec /opt/llama.cpp/build/bin/llama-server \
  --host "$HOST" \
  --port "$PORT" \
  --model "$MODEL_PATH" \
  --ctx-size "$CTX_SIZE" \
  "${EXTRA_ARGS[@]}"
