#!/bin/bash

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh

#	source .env_keycloak_client

KC_HOST="http://keycloak:8080"
USER="sios-user"
PASS="password123"

COOKIE_FILE="my-cookie.txt"
API_URL="http://localhost:8000/handson/oauth/v1/auth-code/oidc-bff"
LOGIN_URL="http://localhost:8000/handson/oauth/bff/login"

# 実行前にクッキーを確実にリセット
rm -f "$COOKIE_FILE"

# {{{ invoke_api()
invoke_api() {
    local url="$1"
    local cookie="$2"
    echo "🚀 Invoking API (BFF Mode - Session Cookie): ${url}" >&2
    # セッションクッキーのみでアクセス
    curl -i -b "$cookie" "$url"
    echo ""
}
# }}}

# {{{ main()
main() {
    # 0. 前提条件の確認
    auth_test_check_name_resolution "keycloak"

    echo "1️⃣ API に Cookie なしでアクセスして 401 を確認します..."
    local http_status=$(auth_test_bff_check_unauth "$API_URL")
    if [ "$http_status" != "401" ]; then
        echo "❌ Error: 401 が期待されましたが HTTP ${http_status} が返りました。" >&2
        exit 1
    fi
    echo "✅ HTTP 401 Unauthorized を確認。ログインフローへ進みます。"

    echo "2️⃣ ${LOGIN_URL} にアクセスして Keycloak へのリダイレクト先を取得します..."
    local kc_init_url=$(auth_test_bff_init_flow "$LOGIN_URL" "$COOKIE_FILE")
    if [ -z "$kc_init_url" ]; then
        echo "❌ Error: ${LOGIN_URL} からのリダイレクト先が取得できません。" >&2
        exit 1
    fi

    echo "3️⃣ Keycloak ログイン画面の action URL を解析中..."
    local login_form_url=$(auth_test_bff_get_login_url "$kc_init_url" "$COOKIE_FILE" "$KC_HOST")

    echo "4️⃣ Keycloak でログインを実行中..."
    local kong_callback_url=$(auth_test_post_login "$login_form_url" "$USER" "$PASS" "$COOKIE_FILE")
    if [[ "$kong_callback_url" != *"code="* ]]; then
        echo "❌ Error: 認可コードの取得に失敗しました。" >&2
        echo "Location: $kong_callback_url" >&2
        exit 1
    fi

    echo "5️⃣ /${LOGIN_URL} のコールバックへ戻り、セッション Cookie を確立します..."
    auth_test_bff_finalize_login "$kong_callback_url" "$COOKIE_FILE"

    # 結果確認
    echo "✅ セッション確立完了（BFF 認証成功）"
    invoke_api "$API_URL" "$COOKIE_FILE"
}
# }}}

start_banner
main
finish_banner $S_TIME
