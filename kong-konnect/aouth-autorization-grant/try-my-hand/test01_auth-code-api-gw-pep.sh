#!/bin/bash

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh

source ${CUR_DIR}/../setup/.env_keycloak_client

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

# 実行前にクッキーを確実にリセット
rm -f "$COOKIE_FILE"

# {{{ invoke_api()
invoke_api() {
    local url="$1"
    local token="$2"
    echo "🚀 Invoking API (PEP Mode): ${url}" >&2
    curl -v "${url}" -H "Authorization: Bearer ${token}"
	echo ""
}
# }}}

# {{{ main()
main() {
	# 0. 前提条件の確認 (名前解決)
	auth_test_check_name_resolution "keycloak"

	# 1. PKCE準備
	local verifier=$(auth_test_gen_verifier)
	local challenge=$(auth_test_calc_challenge "$verifier")

	# 2. OIDC Dicoveryエンドポイントから各種エンドポイントを取得
	local config_json=$(auth_test_fetch_config "$URL_IDP_CNF")
	local auth_endpoint=$(auth_test_get_endpoint "$config_json" "authorization_endpoint")
	local token_endpoint=$(auth_test_get_endpoint "$config_json" "token_endpoint")

	# 3. 認可エンドポイントから得たHTMLからログインURLを抽出
	local login_url=$(auth_test_pep_get_login_url "$auth_endpoint" "$CLIENT_ID" "$REDIRECT" "$challenge" "$COOKIE_FILE" "${KC_HOST}")
    
	# 4. ログインURLへログイン実行とレスポンスから認可コードを抽出
	local redirect_url=$(auth_test_post_login "$login_url" "$USER" "$PASS" "$COOKIE_FILE")
	local auth_code=$(auth_test_pep_extract_code "$redirect_url")

	# 認可コードの抽出確認
	if [ -z "$auth_code" ]; then
		echo "❌ Error: 認可コードの取得に失敗しました。ログインが拒否された可能性があります。" >&2
		exit 1
	fi

	# 5. トークンエンドポイントで認可コードからトークンへ交換
	local token_json=$(auth_test_pep_exchange_token "$token_endpoint" "$auth_code" "$CLIENT_ID" "$CLIENT_ST" "$REDIRECT" "$verifier")
	local access_token=$(echo "$token_json" | jq -r '.access_token')

	# Access Tokenの抽出確認
	if [ "$access_token" == "null" ] || [ -z "$access_token" ]; then
		echo "❌ Access Token の取得に失敗しました。" >&2
		echo "$token_json" | jq . >&2
		exit 1
	fi

	# 6. Kong経由でアップストリームAPIを実行
	invoke_api "$API_URL" "$access_token"
}
# }}}

start_banner
main
finish_banner $S_TIME
