#!/bin/sh
set -e

CUR_DIR=$(cd $(dirname $0); pwd)
cd "$CUR_DIR"

# .venv を削除して、キャッシュを使わずにリモートリポジトリを強制する
rm -rf .venv
UV=~/.local/bin/uv
$UV run --no-cache app.py