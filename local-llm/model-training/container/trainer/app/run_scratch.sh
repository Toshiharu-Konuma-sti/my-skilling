#!/bin/bash
# ゼロからの学習: トークナイザー取得 → 極小モデルの学習 → GGUF 変換 を一括実行する (/workspace で実行)
#   成果物: /workspace/scratch/output/my_scratch_model.gguf と Modelfile (Ollama コンテナの /trained-scratch から参照される)
set -euo pipefail
cd /workspace

# 経過時間は実行ごとに 0 から数える (常駐コンテナでは前回の開始時刻が残るため)
rm -f /tmp/start_epoch
mkdir -p scratch/output

echo
python /app/progress.py '【1/3】トークナイザーの確認'
if [ ! -f ./scratch/tokenizer/tokenizer.json ]; then
  python /app/progress.py '- トークナイザーをダウンロード中...'
  hf download Qwen/Qwen2.5-0.5B-Instruct tokenizer.json tokenizer_config.json vocab.json merges.txt \
    --local-dir ./scratch/tokenizer
else
  python /app/progress.py '- ダウンロード済みのためスキップ'
fi

echo
python /app/progress.py '【2/3】ゼロからの学習 (重みはランダムな値から開始)'
python /app/train_scratch.py

echo
python /app/progress.py '【3/3】GGUF 形式への変換'
python /llama.cpp/convert_hf_to_gguf.py ./scratch/model --outfile ./scratch/output/my_scratch_model.gguf --outtype f16
cp /app/Modelfile.scratch ./scratch/output/Modelfile

echo
python /app/progress.py '*** 全処理が完了しました ***'
