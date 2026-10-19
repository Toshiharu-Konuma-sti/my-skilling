#!/bin/sh
# 学習済みモデル (workspace/finetune/output) を Ollama に登録する。docker-compose-ollama.yml で /trained にマウント済み
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh

start_banner

NAME="${1:-my-finetune-model}"

if [ ! -f "$(dirname "$0")/workspace/finetune/output/my_finetune_model.gguf" ]; then
	echo "❌ my_finetune_model.gguf がありません。先に ./step11_run_finetune_training.sh を実行してください"
	exit 1
fi

docker exec ollama ollama create "$NAME" -f /trained/Modelfile
echo
docker exec -it ollama ollama list
echo ">>> Ollama への登録が完了しました: $NAME"

finish_banner $S_TIME

