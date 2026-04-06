#!/bin/bash
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh

source .env

KC_URL="http://localhost:8080"
KC_USER="${KC_BOOTSTRAP_ADMIN_USERNAME}"
KC_PASS="${KC_BOOTSTRAP_ADMIN_PASSWORD}"
REALM="handson"
USER_NAME="sios-user"
USER_PASS="password123"
USER_EMAIL="sios-user@example.com"
USER_FIRST="Sios"
USER_LAST="User"

# 登録したいクライアントIDを定義
CLIENT_ID_API_GW_PEP="kong-auth-code-api-gw-pep"
CLIENT_ID_OIDC_BFF="kong-auth-code-oidc-bff"
CLIENT_ID_CLIENT_CRED="kong-client-credential"

# {{{ main()
main()
{
	echo "🔐 Keycloak Adminトークンを取得中..."
	local token=$(get_kc_admin_token "$KC_URL" "$KC_USER" "$KC_PASS")

	echo "🏗️ Realm '$REALM' を作成中..."
	create_kc_realm "$KC_URL" "${token}" "$REALM"

	# 各クライアントを作成してシークレットを取得
	local secret_api_gw_pep=$(create_kc_client_get_secret "$KC_URL" "${token}" "$REALM" "$CLIENT_ID_API_GW_PEP" '["*"]')
	echo "✅ Secret (API Gateway PEP) を取得しました"

	local secret_oidc_bff=$(create_kc_client_get_secret "$KC_URL" "${token}" "$REALM" "$CLIENT_ID_OIDC_BFF" '["http://localhost:8000/*"]')
	echo "✅ Secret (OIDC BFF) を取得しました"

	local secret_client_cred=$(create_kc_client_get_secret "$KC_URL" "${token}" "$REALM" "$CLIENT_ID_CLIENT_CRED" '[]')
	echo "✅ Secret (Client Credentials) を取得しました"

	# まとめてenvファイルを生成
	cat <<EOF > .env_keycloak_client
DECK_KC_CLIENT_ID_API_GW_PEP="${CLIENT_ID_API_GW_PEP}"
DECK_KC_CLIENT_SECRET_API_GW_PEP="${secret_api_gw_pep}"
DECK_KC_CLIENT_ID_OIDC_BFF="${CLIENT_ID_OIDC_BFF}"
DECK_KC_CLIENT_SECRET_OIDC_BFF="${secret_oidc_bff}"
DECK_KC_CLIENT_ID_CLIENT_CRED="${CLIENT_ID_CLIENT_CRED}"
DECK_KC_CLIENT_SECRET_CLIENT_CRED="${secret_client_cred}"
EOF

	echo "📝 .env_keycloak_client を更新しました"

	echo "👤 ユーザー '$USER_NAME' を詳細情報付きで作成中..."
	create_kc_user "$KC_URL" "${token}" "$REALM" "$USER_NAME" "$USER_PASS" "$USER_EMAIL" "$USER_FIRST" "$USER_LAST"

	echo "🎉 Keycloakのフルセットアップが完了しました！"
}
# }}}

start_banner
main
finish_banner $S_TIME
