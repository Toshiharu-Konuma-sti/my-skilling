#!/bin/bash

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh

# --- 設定項目 ---
KC_HOST="http://keycloak:8080"
USER="sios-user"
PASS="password123"

COOKIE_FILE="my-cookie.txt"
API_URL="http://localhost:8000/handson/oauth/v1/auth-code/oidc-bff"
LOGIN_URL="http://localhost:8000/handson/oauth/bff/login"

rm -f "$COOKIE_FILE"

# --- 関数定義 ---
invoke_api() {
    local url="$1"
    local cookie="$2"
    echo "🚀 API実行 (BFF Mode - Session Cookie): ${url}" >&2
    # セッションクッキーを使用してアクセス
    curl -i -b "$cookie" "$url"
    echo ""
}

# --- メイン処理 ---
main() {
    echo "0️⃣  前提条件の確認..."
    auth_test_check_name_resolution "keycloak"

    echo "1️⃣  未認証状態の確認 (Cookieなしで401が返ることを確認)..."
    echo "  - Target API: ${API_URL}"
    local http_status=$(auth_test_bff_check_unauth "$API_URL")
    if [ "$http_status" != "401" ]; then
        echo "❌ Error: 401 が期待されましたが HTTP ${http_status} が返りました。" >&2
        exit 1
    fi
    echo "✅ HTTP 401 Unauthorized を確認。ログインフローを開始します。"

    echo "2️⃣  BFFログインエンドポイントへアクセスし、認可リダイレクト先を取得中..."
    echo "  - BFF Login: ${LOGIN_URL}"
    local kc_init_url=$(auth_test_bff_init_flow "$LOGIN_URL" "$COOKIE_FILE")
    if [ -z "$kc_init_url" ]; then
        echo "❌ Error: リダイレクト先URLが取得できません。" >&2
        exit 1
    fi
    echo "  - Redirect to IdP: ${kc_init_url}"

    echo "3️⃣  Keycloak ログイン画面の action URL を解析中..."
    local login_form_url=$(auth_test_bff_get_login_url "$kc_init_url" "$COOKIE_FILE" "$KC_HOST")
    echo "  - Login Form Action: ${login_form_url}"

    echo "4️⃣  Keycloak へのログインを実行し、認可コードを取得中..."
    local kong_callback_url=$(auth_test_post_login "$login_form_url" "$USER" "$PASS" "$COOKIE_FILE")
    if [[ "$kong_callback_url" != *"code="* ]]; then
        echo "❌ Error: 認可コードの取得に失敗しました。" >&2
        echo "Location: $kong_callback_url" >&2
        exit 1
    fi
    echo "  - Callback URL with Code: ${kong_callback_url}"

    echo "5️⃣  コールバック処理を実行し、セッション Cookie を確立中..."
    auth_test_bff_finalize_login "$kong_callback_url" "$COOKIE_FILE"
    echo "✅ セッション確立完了（BFF 認証成功）"

    echo "6️⃣  セッション Cookie を使用して Kong 経由でアップストリーム API を実行中..."
    invoke_api "$API_URL" "$COOKIE_FILE"
}

start_banner
main
finish_banner $S_TIME