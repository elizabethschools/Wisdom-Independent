 # Wisdom — Independent AI Docker Image
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04

# Wisdom's runtime environment
ENV TORCH_CUDA=cu128 \
    HF_HOME=/data/models \
    DATA_DIR=/data/openwebui \
    LOG_DIR=/data/logs \
    MODEL_REPO=coder3101/Cydonia-24B-v4.3-vision-heretic \
    MAX_MODEL_LEN=32768 \
    VLLM_EXTRA_ARGS="--quantization fp8" \
    GPU_MEMORY_UTILIZATION=0.90 \
    VLLM_HOST=0.0.0.0 \
    VLLM_PORT=8000 \
    VLLM_URL=http://localhost:8000 \
    VLLM_VENV=/opt/vllm-venv \
    OPENWEBUI_PORT=3000 \
    OPENAI_API_BASE_URL=http://localhost:8080/v1 \
    OPENAI_API_KEY="" \
    WEBUI_AUTH=true \
    ENABLE_OLLAMA_API=false \
    ENABLE_OPENAI_API=true \
    OLLAMA_BASE_URL=""

# Context compactor configuration
ENV COMPACTOR_HOST=0.0.0.0 \
    COMPACTOR_PORT=8080 \
    COMPACTOR_ADMIN_BIND=127.0.0.1 \
    COMPACTOR_BACKUP_ENABLED=true \
    COMPACTOR_SELFTEST_ON_BOOT=true \
    COMPACTOR_EMBEDDING_MODEL=BAAI/bge-small-en-v1.5 \
    COMPACTOR_FACTS_EXTRACTION=true \
    COMPACTOR_KEEP_RECENT_TURNS=4 \
    COMPACTOR_MAX_FACTS_TOKENS=1500 \
    COMPACTOR_RAG_ENABLED=true \
    COMPACTOR_RAG_TOP_K=5 \
    COMPACTOR_SUMMARY_MAX_TOKENS=1024 \
    COMPACTOR_TARGET_TOKENS="" \
    FASTEMBED_CACHE_PATH=/opt/embeddings

# Database configuration
ENV DATABASE_ENABLE_SQLITE_WAL=false \
    DATABASE_SQLITE_PRAGMA_BUSY_TIMEOUT=10000 \
    DATABASE_SQLITE_PRAGMA_MMAP_SIZE=0

# Speech-to-text configuration
ENV STT_ENABLED=true \
    STT_HOST=0.0.0.0 \
    STT_PORT=9000 \
    WHISPER_DEVICE=cpu \
    WHISPER_DOWNLOAD_ROOT=/opt/whisper-models \
    WHISPER_MODEL=base \
    WHISPER_MODEL_ID=whisper-1

# Text-to-speech configuration
ENV TTS_ENABLED=true \
    TTS_HOST=0.0.0.0 \
    TTS_PORT=9001 \
    TTS_MODEL_ID=tts-1 \
    TTS_VOICE=en_US-lessac-medium \
    TTS_VOICE_DIR=/opt/tts-voices

# Open WebUI audio configuration
ENV AUDIO_STT_ENGINE=openai \
    AUDIO_STT_MODEL=whisper-1 \
    AUDIO_STT_OPENAI_API_BASE_URL=http://localhost:9000/v1 \
    AUDIO_TTS_ENGINE=openai \
    AUDIO_TTS_MODEL=tts-1 \
    AUDIO_TTS_OPENAI_API_BASE_URL=http://localhost:9001/v1 \
    AUDIO_TTS_VOICE=alloy

# System tools required by Wisdom
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    git \
    curl \
    wget \
    ca-certificates \
    supervisor \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Create separate Python environments for Wisdom's services
RUN python3 -m venv /opt/vllm-venv \
    && python3 -m venv /app/venv \
    && python3 -m venv /opt/whisper-venv \
    && python3 -m venv /opt/tts-venv \
    && python3 -m venv /opt/compactor-venv

# Install Wisdom's AI inference versions
RUN /opt/vllm-venv/bin/pip install --no-cache-dir \
    "torch==2.10.0" \
    --index-url https://download.pytorch.org/whl/cu128

RUN /opt/vllm-venv/bin/pip install --no-cache-dir \
    "vllm==0.19.0"

# Install Wisdom's Open WebUI
RUN /app/venv/bin/pip install --no-cache-dir \
    "open-webui==0.11.0"

# Create directories for Wisdom's supporting services
RUN mkdir -p \
    /opt/compactor \
    /opt/stt \
    /opt/tts \
    /data/logs \
    /data/vllm-compile-cache

# Copy supporting service dependency lists
COPY requirements/stt-requirements.txt /tmp/stt-requirements.txt
COPY requirements/tts-requirements.txt /tmp/tts-requirements.txt

# Install speech-to-text dependencies
RUN /opt/whisper-venv/bin/pip install --no-cache-dir \
    -r /tmp/stt-requirements.txt

# Install text-to-speech dependencies
RUN /opt/tts-venv/bin/pip install --no-cache-dir \
    -r /tmp/tts-requirements.txt

# Copy Wisdom's speech service source code
COPY services/stt/ /opt/stt/
COPY services/tts/ /opt/tts/

# Install Wisdom's compactor dependencies
COPY services/compactor/requirements.txt /tmp/compactor-requirements.txt
RUN /opt/compactor-venv/bin/pip install --no-cache-dir \
    -r /tmp/compactor-requirements.txt

# Copy Wisdom's compactor source code
COPY services/compactor/ /opt/compactor/

# Copy Wisdom's startup and service configuration
COPY entrypoint.sh /entrypoint.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Make the startup script executable
RUN chmod +x /entrypoint.sh

# Wisdom's application ports
EXPOSE 3000 8000 8080

# Set Wisdom's working directory
WORKDIR /app

# Start Wisdom
ENTRYPOINT ["/entrypoint.sh"]
