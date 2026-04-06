#!/bin/bash

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh

source ${CUR_DIR}/../setup/.env_keycloak_client

KC_HOST="http://keycloak:8080"
OWN_REALM="handson"
URL_IDP_CNF="$KC_HOST/realms/$OWN_REALM/.well-known/openid-configuration"
CLIENT_ID="${DECK_KC_CLIENT_ID_CLIENT_CRED}"
CLIENT_ST="${DECK_KC_CLIENT_SECRET_CLIENT_CRED}"

API_URL="http://localhost:8000/handson/oauth/v1/client-cred"

# {{{ invoke_api()
invoke_api() {
	local url="$1"
	local token="$2"
	echo "🚀 Invoking API (Client Credentials Mode): ${url}" >&2
	curl -v "${url}" -H "Authorization: Bearer ${token}"
	echo ""
}
# }}}

# {{{ main()
main() {
	# 0. 前提条件の確認 (名前解決)
	auth_test_check_name_resolution "keycloak"

	echo "1️⃣  OIDC 構成情報を取得してエンドポイントを特定中..."
	local config_json=$(auth_test_fetch_config "$URL_IDP_CNF")
	local token_endpoint=$(auth_test_get_endpoint "$config_json" "token_endpoint")

	echo "2️⃣  Keycloak からアクセストークンを直接取得します..."
	local token_json=$(auth_test_client_cred_get_token "$token_endpoint" "$CLIENT_ID" "$CLIENT_ST")
	local access_token=$(echo "$token_json" | jq -r '.access_token')

	if [ "$access_token" == "null" ] || [ -z "$access_token" ]; then
		echo "❌ Access Token の取得に失敗しました。" >&2
		echo "$token_json" | jq . >&2
		exit 1
	fi
	echo "✅ Access Token を取得しました。"

	echo "3️⃣  取得したトークンを使用して Kong 経由で API を実行します..."
	invoke_api "$API_URL" "$access_token"
}
# }}}

start_banner
main
finish_banner $S_TIME
