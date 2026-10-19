# 汎用の Ollama モデル登録イメージ。登録するモデルは環境変数 OLLAMA_INIT_MODELS で指定する (ollama-init.sh 参照)
ARG OLLAMA_VERSION=0.32.5
FROM ollama/ollama:${OLLAMA_VERSION}
COPY ollama-init.sh /usr/local/bin/ollama-init.sh
ENTRYPOINT ["/bin/sh", "/usr/local/bin/ollama-init.sh"]
CMD []
