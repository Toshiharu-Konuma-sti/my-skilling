# 学習用イメージ: PyTorch + LoRA 学習ライブラリ + llama.cpp (GGUF 変換用)
FROM pytorch/pytorch:2.6.0-cuda12.4-cudnn9-runtime

# 1. 安定版ライブラリのインストール
RUN pip install --default-timeout=1000 --retries=10 --progress-bar on \
    huggingface_hub 'transformers<4.48' datasets accelerate peft sentencepiece gguf protobuf

# 2. git の導入と llama.cpp のクローン (GGUF 変換スクリプトをコンテナ内に保持)
RUN apt-get update && apt-get install -y --no-install-recommends git \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && git clone --depth 1 https://github.com/ggml-org/llama.cpp.git /llama.cpp

WORKDIR /workspace
CMD ["sleep", "infinity"]
