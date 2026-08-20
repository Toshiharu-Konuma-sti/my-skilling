#!/bin/bash
# =============================================================================
# GGUF モデルを Hugging Face から curl -L -C - でダウンロードする (途中再開可能)
#
# 用途  : ollama pull がネットワーク不安定で失敗する環境向け
# 手順  : 1. ./BEFORE_CONTAINER_DOWNLOAD_MODELS.sh  (何度実行しても途中から再開される)
#         2. ./CREATE_CONTAINER.sh  (ローカル GGUF を ollama create で登録)
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODELS_DIR="${SCRIPT_DIR}/models"
mkdir -p "${MODELS_DIR}"

download() {
  local name="$1" url="$2" dest="${MODELS_DIR}/$3"
  echo ""
  echo "📦 ${name}"
  echo "   ${url}"
  # -L: リダイレクト追跡 (HuggingFace CDN 必須)  -C -: バイト単位再開  --progress-bar: 進捗表示
  if curl -L --show-error --progress-bar -C - -o "${dest}" "${url}"; then
    echo "✅ ${name} ready ($(du -sh "${dest}" | cut -f1))"
  else
    local exit_code=$?
    echo "❌ ${name} failed (exit=${exit_code}). 部分ファイルは保持されます。再実行で再開されます。"
    return ${exit_code}
  fi
}

echo "============================================================"
echo "  Model download — $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Destination: ${MODELS_DIR}"
echo "============================================================"

# qwen2.5:1.5b  Q4_K_M  ~1.0 GB  (Apache 2.0 — HF認証不要)
download "qwen2.5:1.5b" \
  "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf" \
  "qwen2.5-1.5b.gguf"

# qwen2.5:3b  Q4_K_M  ~1.9 GB  (proxy007 decorator 専用 — 指示追従性能が必要)
download "qwen2.5:3b" \
  "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf" \
  "qwen2.5-3b.gguf"

# tinyllama  Q4_K_M  ~670 MB
download "tinyllama" \
  "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf" \
  "tinyllama.gguf"

# phi3:mini  Q4_K_M  ~2.2 GB  (Microsoft MIT ライセンス — proxy009 レスポンス変換専用)
download "phi3:mini" \
  "https://huggingface.co/bartowski/Phi-3-mini-4k-instruct-GGUF/resolve/main/Phi-3-mini-4k-instruct-Q4_K_M.gguf" \
  "phi3-mini.gguf"

# nomic-embed-text  Q8_0  ~270 MB  (埋め込みモデル — Q8 推奨)
download "nomic-embed-text" \
  "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.Q8_0.gguf" \
  "nomic-embed-text.gguf"

echo ""
echo "🎉 All models downloaded to: ${MODELS_DIR}"
echo "   Next step: ./CREATE_CONTAINER.sh"
