#!/bin/sh
# 環境変数で指定されたモデルを Ollama に登録する (登録済みはスキップ)
#   OLLAMA_INIT_MODELS   : 1 行 1 モデル "<モデル名> [<GGUF ファイル名>|-] [chatml|<Modelfile 断片のパス>]"
#                          "#" で始まる行と空行は無視する
#   OLLAMA_INIT_GGUF_DIR : GGUF ファイルの置き場所 (既定: /models)
#   OLLAMA_HOST          : 接続先の Ollama サーバー
# GGUF が無い場合や登録に失敗した場合は ollama pull で取得する。
set -u

GGUF_DIR="${OLLAMA_INIT_GGUF_DIR:-/models}"

# ChatML テンプレートを明示しないと qwen2.5 は system プロンプトが無視される
chatml_template() {
  cat <<'EOF'
TEMPLATE """{{- if .System }}<|im_start|>system
{{ .System }}<|im_end|>
{{ end }}{{- range .Messages }}<|im_start|>{{ .Role }}
{{ .Content }}<|im_end|>
{{ end }}<|im_start|>assistant
"""
PARAMETER stop "<|im_end|>"
PARAMETER stop "<|im_start|>"
PARAMETER temperature 0
EOF
}

pull_model() {
  until ollama pull "$1"; do
    echo "⚠️  Pull interrupted, resuming in 15s ..."
    sleep 15
  done
  echo "✅ $1 ready"
}

register_model() {
  local name="$1" gguf="${2:--}" tmpl="${3:-}"

  if ollama list 2>/dev/null | grep -q "^${name}"; then
    echo "✅ ${name} already registered, skipping"
    return 0
  fi

  if [ "$gguf" = "-" ] || [ ! -f "${GGUF_DIR}/${gguf}" ]; then
    echo "📦 Pulling ${name} from Ollama registry ..."
    pull_model "$name"
    return 0
  fi

  echo "📦 Registering ${name} from local GGUF ${gguf} ..."
  {
    echo "FROM ${GGUF_DIR}/${gguf}"
    case "$tmpl" in
      "") ;;
      chatml) chatml_template ;;
      *) cat "$tmpl" ;;
    esac
  } > /tmp/modelfile

  if ollama create "$name" -f /tmp/modelfile; then
    echo "✅ ${name} registered from GGUF"
    return 0
  fi
  echo "⚠️  ollama create failed, falling back to ollama pull ..."
  pull_model "$name"
}

until ollama list >/dev/null 2>&1; do
  echo "⏳ Waiting for Ollama (${OLLAMA_HOST:-localhost}) ..."
  sleep 2
done

if [ -z "${OLLAMA_INIT_MODELS:-}" ]; then
  echo "⚠️  OLLAMA_INIT_MODELS is empty, nothing to register"
fi

printf '%s\n' "${OLLAMA_INIT_MODELS:-}" | while read -r name gguf tmpl; do
  case "$name" in ""|"#"*) continue ;; esac
  register_model "$name" "$gguf" "$tmpl"
done

echo '✅ All models ready'
echo ''
ollama list
