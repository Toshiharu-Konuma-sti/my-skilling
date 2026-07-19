#!/bin/sh
# 使い方:
#   sh BUILD.sh       認証アクセス（HTTPS ブリッジ経由）
#   sh BUILD.sh ano   匿名アクセス（HTTP 直接接続・認証情報なし）
#
# 認証情報の流れ（認証あり）:
#   go run → GOPROXY (HTTPS) → nexus_go_proxy.py ─(HTTP)→ Nexus go-proxy（認証アクセス）
#
# 認証情報の流れ（認証なし）:
#   go run → GOPROXY (HTTP) → Nexus go-proxy（匿名アクセス）

set -e

CUR_DIR=$(cd $(dirname $0); pwd)
. "${CUR_DIR}/../variables.sh"

# ------------------------------------------------------------
# 定数
# ------------------------------------------------------------
LOCAL_PROXY_PORT=18444
CERT_FILE="/tmp/go-nexus-proxy.crt"
KEY_FILE="/tmp/go-nexus-proxy.key"
CA_BUNDLE="/tmp/go-nexus-ca-bundle.crt"
PROXY_PID=""

# ------------------------------------------------------------
# サブルーチン: ブリッジのクリーンアップ（終了時に自動呼び出し）
# ------------------------------------------------------------
cleanup_bridge() {
    [ -n "$PROXY_PID" ] && kill "$PROXY_PID" 2>/dev/null || true
}

# ------------------------------------------------------------
# サブルーチン: 前回残留したブリッジプロセスを停止
# ------------------------------------------------------------
kill_stale_bridge() {
    echo "[INFO] 残留ブリッジプロセスを確認・停止しています..."
    lsof -ti :"$LOCAL_PROXY_PORT" | xargs kill -9 2>/dev/null || true
}

# ------------------------------------------------------------
# サブルーチン: 自己署名証明書の生成
#   SAN 必須: Go 1.15+ は CN のみの証明書を拒否する
# ------------------------------------------------------------
generate_cert() {
    echo "[INFO] 自己署名証明書を生成しています..."
    openssl req -x509 -newkey rsa:2048 -keyout "$KEY_FILE" -out "$CERT_FILE" \
        -days 1 -nodes -subj "/CN=localhost" \
        -addext "subjectAltName=IP:127.0.0.1,DNS:localhost" 2>/dev/null
    cat /etc/ssl/certs/ca-certificates.crt "$CERT_FILE" > "$CA_BUNDLE"
    echo "[INFO] 証明書を生成しました: ${CERT_FILE}"
}

# ------------------------------------------------------------
# サブルーチン: HTTPS ブリッジの起動
# ------------------------------------------------------------
start_bridge() {
    echo "[INFO] HTTPS ブリッジを起動しています (port: ${LOCAL_PROXY_PORT})..."
    python3 "${CUR_DIR}/nexus_go_proxy.py" \
        "$LOCAL_PROXY_PORT" "$REPO_MANAGER_URL" "$CERT_FILE" "$KEY_FILE" &
    PROXY_PID=$!
    sleep 1
    echo "[INFO] ブリッジ起動完了 (PID: ${PROXY_PID})"
}

# ------------------------------------------------------------
# サブルーチン: Go モジュールキャッシュのクリア
# ------------------------------------------------------------
clean_module_cache() {
    echo "[INFO] Go モジュールキャッシュをクリアしています..."
    go clean -modcache
}

# ------------------------------------------------------------
# サブルーチン: Go プログラムの実行（認証あり / HTTPS ブリッジ経由）
#   GOPROXY: https://user:pass@localhost:PORT/repository/go-proxy/
#   Go は HTTP への認証情報送信を禁止しているため HTTPS ブリッジを経由で Nexus へ接続する
# ------------------------------------------------------------
run_with_auth() {
    local _goproxy_url="https://${REPO_MANAGER_USERNAME}:${REPO_MANAGER_PASSWORD}@localhost:${LOCAL_PROXY_PORT}/repository/${GO_PROXY_REPO_NAME}"
    echo "[INFO] [認証あり / HTTPS ブリッジ] でモジュールを取得して実行します..."
    echo "       GOPROXY: ${_goproxy_url}"

    trap cleanup_bridge EXIT INT TERM
    kill_stale_bridge
    generate_cert
    start_bridge

    SSL_CERT_FILE="$CA_BUNDLE" \
    GOPROXY="${_goproxy_url}" \
    GONOSUMDB="*" GOFLAGS="-mod=mod" \
    go run .
}

# ------------------------------------------------------------
# サブルーチン: Go プログラムの実行（匿名 / HTTP 直接接続）
#   GOPROXY: http://nexus.local:8081/repository/go-proxy/
#   認証情報なしのため Go は HTTP で Nexus へ直接接続する
# ------------------------------------------------------------
run_anonymous() {
    local _goproxy_url="${REPO_MANAGER_URL}/repository/${GO_PROXY_REPO_NAME}"
    echo "[INFO] [匿名 / HTTP 直接] でモジュールを取得して実行します..."
    echo "       GOPROXY: ${_goproxy_url}"
    echo "       ※ Nexus の匿名アクセスが有効である必要があります"

    GOPROXY="${_goproxy_url}" \
    GONOSUMDB="*" GOFLAGS="-mod=mod" \
    go run .
}

# ------------------------------------------------------------
# サブルーチン: 使い方の表示
# ------------------------------------------------------------
show_usage() {
    cat << EOS
Usage: $(basename $0) [options]

Build and run the Go application, fetching modules via Nexus repository manager.

Options:
  (none)   Fetch modules via HTTPS bridge with authentication.
           Credentials are sent over HTTPS to the local bridge,
           which forwards requests to Nexus over HTTP.
  ano      Fetch modules via HTTP directly without credentials.
           Requires Nexus anonymous access to be enabled.
  h        Show this usage message.

EOS
}

# ------------------------------------------------------------
# メイン
# ------------------------------------------------------------
main() {
    case "${1:-}" in
        ano)
            cd "$CUR_DIR"
            clean_module_cache
            run_anonymous
            ;;
        "")
            cd "$CUR_DIR"
            clean_module_cache
            run_with_auth
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
