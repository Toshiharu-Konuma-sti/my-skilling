#!/bin/sh
# 認証情報の流れ:
#   RUN.sh → GOPROXY URL → Go (HTTPS) → nexus_go_proxy.py → Nexus HTTP

set -e

CUR_DIR=$(cd $(dirname $0); pwd)
. "${CUR_DIR}/../variables.sh"

LOCAL_PROXY_PORT=18444
LOCAL_PROXY_URL="https://${REPO_MANAGER_USERNAME}:${REPO_MANAGER_PASSWORD}@localhost:${LOCAL_PROXY_PORT}/repository/${GO_PROXY_REPO_NAME}"

CERT_FILE="/tmp/go-nexus-proxy.crt"
KEY_FILE="/tmp/go-nexus-proxy.key"
CA_BUNDLE="/tmp/go-nexus-ca-bundle.crt"

cd "$CUR_DIR"

# 終了時にブリッジを停止
cleanup() {
    [ -n "$PROXY_PID" ] && kill "$PROXY_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# 前回の残留プロセスをクリア
lsof -ti :"$LOCAL_PROXY_PORT" | xargs kill -9 2>/dev/null || true

# 自己署名証明書の生成（SAN 必須: Go 1.15+ は CN のみの証明書を拒否する）
echo "[INFO] 自己署名証明書を生成しています..."
openssl req -x509 -newkey rsa:2048 -keyout "$KEY_FILE" -out "$CERT_FILE" \
    -days 1 -nodes -subj "/CN=localhost" \
    -addext "subjectAltName=IP:127.0.0.1,DNS:localhost" 2>/dev/null
cat /etc/ssl/certs/ca-certificates.crt "$CERT_FILE" > "$CA_BUNDLE"

# HTTPS ブリッジの起動
echo "[INFO] HTTPS ブリッジを起動しています (port: ${LOCAL_PROXY_PORT})..."
python3 "${CUR_DIR}/nexus_go_proxy.py" \
    "$LOCAL_PROXY_PORT" "$REPO_MANAGER_URL" "$CERT_FILE" "$KEY_FILE" &
PROXY_PID=$!
sleep 1

# Go モジュールキャッシュをクリアしてリモートリポジトリ経由を強制
echo "[INFO] Go モジュールキャッシュをクリアしています..."
go clean -modcache

# Go は HTTP エンドポイントへの認証情報送信を許可していないためブリッジを経由
echo "[INFO] リモートリポジトリ経由でモジュールを取得して実行します..."
echo "       GOPROXY: ${LOCAL_PROXY_URL}"

SSL_CERT_FILE="$CA_BUNDLE" \
GOPROXY="${LOCAL_PROXY_URL}" \
GONOSUMDB="*" GOFLAGS="-mod=mod" \
go run .
