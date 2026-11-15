
# Wisdom — Independent AI Docker Image
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04

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

# Start Wisdom
ENTRYPOINT ["/entrypoint.sh"]
