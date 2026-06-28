FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    cmake \
    ninja-build \
    build-essential \
    curl \
    ca-certificates \
    wget \
    openssl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir --upgrade \
    "huggingface_hub[cli,hf_xet]" \
    jupyterlab

ENV HF_HOME=/workspace/.cache/huggingface
ENV HF_HUB_CACHE=/workspace/.cache/huggingface/hub
ENV HF_XET_CACHE=/workspace/.cache/huggingface/xet
ENV TMPDIR=/workspace/tmp
ENV TEMP=/workspace/tmp
ENV TMP=/workspace/tmp
ENV HF_XET_HIGH_PERFORMANCE=1

RUN mkdir -p /workspace/tmp

WORKDIR /opt

ARG LLAMA_CPP_REF=master
RUN git clone --depth 1 https://github.com/ggml-org/llama.cpp.git \
    && cd /opt/llama.cpp \
    && git fetch --depth 1 origin "${LLAMA_CPP_REF}" \
    && git checkout "${LLAMA_CPP_REF}"

WORKDIR /opt/llama.cpp

RUN cmake -B build -G Ninja -DGGML_CUDA=ON -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build --config Release

RUN mkdir -p \
    /workspace/models \
    /workspace/projectors \
    /workspace/ai-readable \
    /workspace/.cache/huggingface/hub \
    /workspace/.cache/huggingface/xet \
    /workspace/tmp

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8080 8888 8082

CMD ["/start.sh"]
