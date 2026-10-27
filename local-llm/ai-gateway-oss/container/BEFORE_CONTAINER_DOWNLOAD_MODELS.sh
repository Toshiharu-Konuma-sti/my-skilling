#!/bin/sh
# =============================================================================
# GGUF モデルを Hugging Face から curl -L -C - でダウンロードする (途中再開可能)
#
# 用途  : ollama pull がネットワーク不安定で失敗する環境向け
# 手順  : 1. ./BEFORE_CONTAINER_DOWNLOAD_MODELS.sh  (何度実行しても途中から再開される)
#         2. ./CREATE_CONTAINER.sh  (ローカル GGUF を ollama create で登録)
# =============================================================================
set -u

CUR_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${CUR_DIR}/common.sh"

MODELS_DIR="${CUR_DIR}/models"
mkdir -p "${MODELS_DIR}"

echo "============================================================"
echo "  Model download — $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Destination: ${MODELS_DIR}"
echo "============================================================"

# qwen2.5:0.5b  Q4_K_M  ~397 MB  (学習前後比較・軽量動作テスト用)
download_model "qwen2.5:0.5b" \
  "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf" \
  "${MODELS_DIR}" \
  "qwen2.5-0.5b.gguf"

# qwen2.5:1.5b  Q4_K_M  ~1.0 GB  (Apache 2.0 — HF認証不要)
download_model "qwen2.5:1.5b" \
  "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf" \
  "${MODELS_DIR}" \
  "qwen2.5-1.5b.gguf"

# qwen2.5:3b  Q4_K_M  ~1.9 GB  (proxy007 decorator 専用 — 指示追従性能が必要)
download_model "qwen2.5:3b" \
  "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf" \
  "${MODELS_DIR}" \
  "qwen2.5-3b.gguf"

# tinyllama  Q4_K_M  ~670 MB
download_model "tinyllama" \
  "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf" \
  "${MODELS_DIR}" \
  "tinyllama.gguf"

# phi3:mini  Q4_K_M  ~2.2 GB  (Microsoft MIT ライセンス — proxy009 レスポンス変換専用)
download_model "phi3:mini" \
  "https://huggingface.co/bartowski/Phi-3-mini-4k-instruct-GGUF/resolve/main/Phi-3-mini-4k-instruct-Q4_K_M.gguf" \
  "${MODELS_DIR}" \
  "phi3-mini.gguf"

# nomic-embed-text  Q8_0  ~270 MB  (埋め込みモデル — Q8 推奨)
download_model "nomic-embed-text" \
  "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.Q8_0.gguf" \
  "${MODELS_DIR}" \
  "nomic-embed-text.gguf"

echo ""
echo "🎉 All models downloaded to: ${MODELS_DIR}"
echo "   Next step: ./CREATE_CONTAINER.sh"
