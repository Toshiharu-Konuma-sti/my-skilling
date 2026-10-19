#!/bin/sh
# ゼロから学習したモデル (workspace/scratch/output) を Ollama に登録する。docker-compose-ollama.yml で /trained-scratch にマウント済み
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh

start_banner

NAME="${1:-my-scratch-model}"

if [ ! -f "$CUR_DIR/workspace/scratch/output/my_scratch_model.gguf" ]; then
	echo "❌ my_scratch_model.gguf がありません。先に ./step01_run_scratch_training.sh を実行してください"
	exit 1
fi

docker exec ollama ollama create "$NAME" -f /trained-scratch/Modelfile
echo
docker exec -it ollama ollama list
echo ">>> Ollama への登録が完了しました: $NAME"

finish_banner $S_TIME
