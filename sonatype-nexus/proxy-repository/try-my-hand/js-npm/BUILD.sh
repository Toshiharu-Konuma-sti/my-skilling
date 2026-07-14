#!/bin/sh
set -e
CUR_DIR=$(cd $(dirname $0); pwd)
cd "$CUR_DIR"

# リモートリポジトリ経由するためキャッシュを削除
rm -rf node_modules
npm cache clean --force

echo "[INFO] 依存パッケージをインストールしています (npmrc 経由)..."
npm install

echo "[INFO] アプリを起動します..."
node app.js
