#!/usr/bin/env bash
set -euo pipefail

# Wisdom independent image — startup
export HF_HOME="${HF_HOME:-/data/huggingface}"
export DATA_DIR="${DATA_DIR:-/data/open-webui}"
export WEBUI_DATA_DIR="${WEBUI_DATA_DIR:-$DATA_DIR}"
export MODEL_REPO="${MODEL_REPO:-coder3101/Cydonia-24B-v4.3-vision-heretic}"
export MAX_MODEL_LEN="${MAX_MODEL_LEN:-16384}"
export VLLM_HOST="${VLLM_HOST:-0.0.0.0}"
export VLLM_PORT="${VLLM_PORT:-8000}"
export OPENWEBUI_PORT="${OPENWEBUI_PORT:-3000}"
export GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.90}"
export TORCH_CUDA="${TORCH_CUDA:-cu128}"
export LOG_DIR="${LOG_DIR:-/data/logs}"

printf 'Wisdom startup | model=%s | HF_HOME=%s\n' "$MODEL_REPO" "$HF_HOME"
if ! touch /data/.wisdom-write-test 2>/dev/null; then
  echo 'ERROR: /data is not writable; refusing to start without persistent storage.' >&2
  exit 1
fi
rm -f /data/.wisdom-write-test
mkdir -p "$HF_HOME" "$DATA_DIR" "$LOG_DIR" /data/vllm-compile-cache
printf '\n===== boot %s | container %s =====\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(hostname)" >> "$LOG_DIR/boot.log"

if ! command -v nvidia-smi >/dev/null || ! nvidia-smi >/dev/null 2>&1; then
  echo 'ERROR: NVIDIA GPU is unavailable.' >&2
  exit 1
fi
DRIVER="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -1)"
DRIVER_MAJOR="${DRIVER%%.*}"
case "$TORCH_CUDA" in
  cu128|cu126) MIN_DRIVER=570 ;;
  cu130) MIN_DRIVER=580 ;;
  *) echo "ERROR: Unknown TORCH_CUDA=$TORCH_CUDA" >&2; exit 1 ;;
esac
if ! [[ "$DRIVER_MAJOR" =~ ^[0-9]+$ ]] || (( DRIVER_MAJOR < MIN_DRIVER )); then
  echo "ERROR: Driver $DRIVER does not meet the configured $TORCH_CUDA minimum ($MIN_DRIVER)." >&2
  exit 1
fi

mkdir -p /root/.cache
if [ ! -e /root/.cache/vllm ] && [ ! -L /root/.cache/vllm ]; then
  ln -s /data/vllm-compile-cache /root/.cache/vllm
fi

if ! curl -sf --max-time 5 https://huggingface.co >/dev/null 2>&1; then
  if find "$HF_HOME/hub" -maxdepth 3 -type d -name snapshots 2>/dev/null | grep -q .; then
    echo 'Hugging Face unreachable; attempting offline startup from cached models.'
    export HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1
  else
    echo 'ERROR: Hugging Face unreachable and no model snapshot cache found.' >&2
    exit 1
  fi
fi

# Persist the signing key across restarts; changing it can invalidate sessions.
SECRET_FILE="/data/.webui-secret-key"
if [ -z "${WEBUI_SECRET_KEY:-}" ]; then
  if [ -s "$SECRET_FILE" ]; then
    export WEBUI_SECRET_KEY="$(cat "$SECRET_FILE")"
  else
    umask 077
    /usr/bin/python3 -c 'import secrets; print(secrets.token_hex(32))' > "$SECRET_FILE"
    export WEBUI_SECRET_KEY="$(cat "$SECRET_FILE")"
  fi
fi

printf 'Starting supervised services: vLLM, Open WebUI, STT, TTS (no compactor).\n'
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
