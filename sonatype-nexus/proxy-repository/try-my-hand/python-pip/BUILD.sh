#!/bin/sh
set -e

CUR_DIR=$(cd $(dirname $0); pwd)
VENV_DIR="${CUR_DIR}/.venv"

# リモートリポジトリ経由を毎回確認するため .venv を削除して再取得する
rm -rf "$VENV_DIR"
python3 -m venv "$VENV_DIR"

# pip install をリポジトリマネージャー経由で実行（キャッシュ無効）
echo "[INFO] 依存パッケージをインストールしています (pip.conf 経由)..."
PIP_CONFIG_FILE="${CUR_DIR}/pip.conf" \
    "${VENV_DIR}/bin/pip" install -r "${CUR_DIR}/requirements.txt" --no-cache-dir

echo "[INFO] アプリを起動します..."
"${VENV_DIR}/bin/python" "${CUR_DIR}/app.py"
