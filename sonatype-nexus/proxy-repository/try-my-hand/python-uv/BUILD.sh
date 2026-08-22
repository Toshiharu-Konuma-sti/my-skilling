#!/bin/sh
set -e

CUR_DIR=$(cd $(dirname $0); pwd)
cd "$CUR_DIR"

# /tmp から .venv へのファイル共有をコピーモードに固定（警告防止）
export UV_LINK_MODE=copy

# .venv を削除して、キャッシュを使わずにリモートリポジトリを強制する
rm -rf .venv
UV=~/.local/bin/uv
$UV run --no-cache app.py
