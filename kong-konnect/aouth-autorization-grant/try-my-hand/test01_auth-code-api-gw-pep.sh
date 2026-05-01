#!/bin/bash

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh

source ${CUR_DIR}/../setup/.env_keycloak_client

# --- 設定項目 ---
KC_HOST="http://keycloak:8080"
OWN_REALM="handson"
URL_IDP_CNF="$KC_HOST/realms/$OWN_REALM/.well-known/openid-configuration"
CLIENT_ID="${DECK_KC_CLIENT_ID_API_GW_PEP}"
CLIENT_ST="${DECK_KC_CLIENT_SECRET_API_GW_PEP}"
REDIRECT="http://localhost:8222/"
USER="sios-user"
PASS="password123"

COOKIE_FILE="my-cookie.txt"
API_URL="http://localhost:8000/handson/oauth/v1/auth-code/api-gw-pep"

rm -f "$COOKIE_FILE"

# --- 関数定義 ---
invoke_api() {
    local url="$1"
    local token="$2"
    echo "🚀 API実行 (PEP Mode): ${url}" >&2
    curl -v "${url}" -H "Authorization: Bearer ${token}"
    echo ""
}

# --- メイン処理 ---
main() {
    echo "0️⃣  前提条件の確認..."
    auth_test_check_name_resolution "keycloak"

    echo "1️⃣  PKCE 準備中 (Code Verifier/Challenge 生成)..."
    local verifier=$(auth_test_gen_verifier)
    local challenge=$(auth_test_calc_challenge "$verifier")

    echo "2️⃣  OIDC Discovery 構成情報を取得中..."
    echo "  - URL: ${URL_IDP_CNF}"
    local config_json=$(auth_test_fetch_config "$URL_IDP_CNF")
    local auth_endpoint=$(auth_test_get_endpoint "$config_json" "authorization_endpoint")
    local token_endpoint=$(auth_test_get_endpoint "$config_json" "token_endpoint")
    echo "  - Auth Endpoint: ${auth_endpoint}"
    echo "  - Token Endpoint: ${token_endpoint}"

    echo "3️⃣  認可エンドポイントからログインURLを抽出中..."
    local login_url=$(auth_test_pep_get_login_url "$auth_endpoint" "$CLIENT_ID" "$REDIRECT" "$challenge" "$COOKIE_FILE" "${KC_HOST}")
    echo "  - Login URL: ${login_url}"

    echo "4️⃣  Keycloak へのログインを実行し、認可コードを取得中..."
    local redirect_url=$(auth_test_post_login "$login_url" "$USER" "$PASS" "$COOKIE_FILE")
    local auth_code=$(auth_test_pep_extract_code "$redirect_url")

    if [ -z "$auth_code" ]; then
        echo "❌ Error: 認可コードの取得に失敗しました。ログインが拒否された可能性があります。" >&2
        exit 1
    fi
    echo "✅ 認可コードを取得しました: ${auth_code}"

    echo "5️⃣  認可コードからトークンへ交換を実行中..."
    echo "  - Endpoint: ${token_endpoint}"
    local token_json=$(auth_test_pep_exchange_token "$token_endpoint" "$auth_code" "$CLIENT_ID" "$CLIENT_ST" "$REDIRECT" "$verifier")
    local access_token=$(echo "$token_json" | jq -r '.access_token')

    if [ "$access_token" == "null" ] || [ -z "$access_token" ]; then
        echo "❌ Error: Access Token の取得に失敗しました。" >&2
        echo "$token_json" | jq . >&2
        exit 1
    fi
    echo "✅ Access Token を取得しました。"

    echo "6️⃣  Access Token を使用して Kong 経由でアップストリーム API を実行中..."
    invoke_api "$API_URL" "$access_token"
}

start_banner
main
finish_banner $S_TIME