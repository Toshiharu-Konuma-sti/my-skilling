#!/bin/bash
# ベースモデル取得 → データセット作成 → LoRA 学習 → GGUF 変換 を一括実行する (/workspace で実行)
#   成果物: /workspace/finetune/output/my_finetune_model.gguf と Modelfile (Ollama コンテナの /trained から参照される)
set -euo pipefail
cd /workspace

# 経過時間は実行ごとに 0 から数える (常駐コンテナでは前回の開始時刻が残るため)
rm -f /tmp/start_epoch
mkdir -p finetune/output

echo
python /app/progress.py '【1/4】ベースモデルの確認'
if [ ! -f ./finetune/base_model/model.safetensors ]; then
  python /app/progress.py '- ベースモデルをダウンロード中...'
  hf download Qwen/Qwen2.5-0.5B-Instruct --local-dir ./finetune/base_model
else
  python /app/progress.py 'ダウンロード済みのためスキップ'
fi

echo
python /app/progress.py '【2/4】学習データの作成 (dataset.jsonl)'
python /app/make_finetune_dataset.py

echo
python /app/progress.py '【3/4】学習データを用いたモデルの学習 (LoRA)'
python /app/train_finetune.py

echo
python /app/progress.py '【4/4】GGUF 形式への変換'
python /llama.cpp/convert_hf_to_gguf.py ./finetune/model --outfile ./finetune/output/my_finetune_model.gguf --outtype f16
cp /app/Modelfile.finetune ./finetune/output/Modelfile

echo
python /app/progress.py '*** 全処理が完了しました ***'
