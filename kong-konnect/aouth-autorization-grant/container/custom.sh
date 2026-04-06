
# {{{ create_container()
# $1: the current directory
create_container()
{
	CUR_DIR=$1
	echo "\n### START: Create new containers ##########"
	docker compose \
		-f $CUR_DIR/docker-compose.yml \
		up -d -V --remove-orphans
}
# }}}

# {{{ destory_container()
# $1: the current directory
destory_container()
{
	CUR_DIR=$1
	echo "\n### START: Destory existing containers ##########"
	docker compose \
		-f $CUR_DIR/docker-compose.yml \
		down -v --remove-orphans
}
# }}}


# {{{ util_ask_input()
# $1: pronpt message (eg.: "Enter Name: ")
util_ask_input() {
	local prompt="$1"
	local answer
	printf "%s" "$prompt" >&2
	read answer
	echo "$answer"
}
# }}}

# {{{ util_ask_secret()
# $1: prompt message
util_ask_secret() {
	local prompt="$1"
	local answer
	printf "%s" "$prompt" >&2
	stty -echo
	read answer
	stty echo
	printf "\n" >&2
	echo "$answer"
}
# }}}

# {{{ check_prerequisite_create_container()
# $1: Base directory (CUR_DIR)
check_prerequisite_create_container() {
	_base_dir="$1"
	_missing=0

	# 1. Konnect設定ファイルの確認
	if [ ! -f "$_base_dir/.env_kong_konnect" ]; then
		echo "❌ エラー: .env_kong_konnect が見つかりません。"
		_missing=1
	fi

	# 2. 証明書の確認 (ディレクトリだけでなく中身のファイルまで見るのが確実)
	if [ ! -f "$_base_dir/certs/tls.crt" ] || [ ! -f "$_base_dir/certs/tls.key" ]; then
		echo "❌ エラー: DP用証明書 (certs/tls.*) が不足しています。"
		_missing=1
	fi

	# 3. 足りないものがあれば終了
	if [ "$_missing" -eq 1 ]; then
		echo "👉 先に ./BEFORE_CREATE_CONTAINER.sh を実行してください。"
		exit 1
	fi

	echo "✅ 事前準備の確認完了"
}
# }}}

# {{{ show_url()
show_url()
{
echo "--------------------------------------------------"
echo "🎉 構築完了！"
echo "Kong Proxy:    http://localhost:8000"
echo "Keycloak:      http://localhost:8080"
echo "Redis Insight: http://localhost:8001"
echo "- - - - - - - - - - - - - - - - - - - - - - - - - "
echo "URL"
echo "  - http://localhost:8000/handson/oauth/v1/auth-code/api-gw-pep"
echo "  - http://localhost:8000/handson/oauth/v1/auth-code/oidc-bff"
echo "  - http://localhost:8000/handson/oauth/v1/client-cred"
echo "  - http://localhost:8000/handson/oauth/bff/login"
echo "--------------------------------------------------"
echo "* hosts ファイルを編集"
echo "  - Windows:    C:\Windows\System32\drivers\etc\hosts"
echo "  - Linux(WSL): /etc/hosts"
echo "  - MacOS:      /private/etc/hosts"
echo "  - 127.0.0.1 keycloak"
echo "--------------------------------------------------"
}
# }}}


# {{{ fetch_kong_cp_data()
# $1: API base URL 
# $2: Personal access token
# $3: Control plane name
fetch_kong_cp_data()
{
	local api_base_url="$1"
	local pat="$2"
	local cp_name="$3"

	curl -s -X GET \
		"${api_base_url}/control-planes" \
		-H "Authorization: Bearer ${pat}" \
		| jq -r --arg NAME "$cp_name" '.data[] | select(.name == $NAME)'
}
# }}}

# {{{ extract_kong_cp_id()
# $1: Response for control plane info 
extract_kong_cp_id()
{
	local cp_data="$1"
	echo "${cp_data}" | jq -r '.id // empty'
}
# }}}

# {{{ check_kong_cp_id()
check_kong_cp_id()
{
	local cp_id="$1"
	local cp_name="$2"

	if [ -z "$cp_id" ] || [ "$cp_id" = "null" ]; then
		echo "❌ 失敗: '${cp_name}' の情報を取得できませんでした。"
		exit 1
	fi
	echo "✅ CP_ID: $cp_id"
}
# }}}

# {{{ prepare_kong_cluster_info()
prepare_kong_cluster_info()
{
	local cp_data="$1"

	# エンドポイントの抽出
	local cluster_endpoint=$(echo "${cp_data}" | jq -r '.config.control_plane_endpoint')
	local telemetry_endpoint=$(echo "${cp_data}" | jq -r '.config.telemetry_endpoint')

	# プレフィックス(https://)を削除してホスト名のみにする
	local cluster_host=$(echo ${cluster_endpoint} | sed -e 's|https://||' -e 's|:443||')
	local telemetry_host=$(echo ${telemetry_endpoint} | sed -e 's|https://||' -e 's|:443||')

	echo "✅ Cluster Host: ${cluster_host}"

	# Docker Compose 用の動的環境変数を一時ファイルに書き出し
	cat <<EOF > .env_kong_konnect
KONG_CLUSTER_CONTROL_PLANE=${cluster_host}:443
KONG_CLUSTER_SERVER_NAME=${cluster_host}
KONG_CLUSTER_TELEMETRY_ENDPOINT=${telemetry_host}:443
KONG_CLUSTER_TELEMETRY_SERVER_NAME=${telemetry_host}
EOF
}
# }}}

# {{{ prepare_kong_dp_certs()
# $1: the current directory
# $2: API base URL 
# $3: Control plane ID
# $4: Personal access token
prepare_kong_dp_certs()
{
	local cur_dir="$1"
	local api_base_url="$2"
	local cp_id="$3"
	local konnect_pat="$4"

    local certs_dir="${cur_dir}/certs"

    echo "\n### START: Fetch DP Certificates from Kong Konnect ##########"

    mkdir -p "${certs_dir}"

	# 既存の登録済み DP 証明書をクリーンアップ
	echo "🧹 既存の DP 証明書を Konnect から削除中..."
	local existing_cert_ids
	existing_cert_ids=$(curl -s -X GET \
		"${api_base_url}/control-planes/${cp_id}/dp-client-certificates" \
		-H "Authorization: Bearer ${konnect_pat}" \
		| jq -r '.items[].id // empty')

	local cert_id
	for cert_id in ${existing_cert_ids}; do
		echo "  → 削除: ${cert_id}"
		curl -s -X DELETE \
			"${api_base_url}/control-planes/${cp_id}/dp-client-certificates/${cert_id}" \
			-H "Authorization: Bearer ${konnect_pat}" > /dev/null
	done

    # 一時ディレクトリで秘密鍵 & 自己署名証明書を生成
    local tmp_dir
    tmp_dir=$(mktemp -d)

	local tmp_key="${tmp_dir}/tls.key"
	local tmp_crt="${tmp_dir}/tls.crt"

	openssl genrsa -out "${tmp_key}" 2048 2>/dev/null
	openssl req -new -x509 \
		-key "${tmp_key}" \
		-out "${tmp_crt}" \
		-days 3650 \
		-subj "/CN=kong-dp/O=kong" 2>/dev/null

	echo "✅ 証明書の生成完了"

    # 証明書 PEM を JSON 文字列に変換して Konnect に登録
    local cert_json
    cert_json=$(jq -Rs . < "${tmp_crt}")

    echo "📤 Kong Konnect に証明書を登録中 (CP_ID: ${cp_id})..."
    local response
	response=$(curl -s -X POST \
		"${api_base_url}/control-planes/${cp_id}/dp-client-certificates" \
		-H "Authorization: Bearer ${konnect_pat}" \
		-H "Content-Type: application/json" \
		-d "{\"cert\": ${cert_json}}")

    local registered_id
    registered_id=$(echo "${response}" | jq -r '.item.id // .id // empty')

    if [ -z "${registered_id}" ] || [ "${registered_id}" = "null" ]; then
        echo "❌ 証明書の登録に失敗しました:"
        echo "${response}" | jq . 2>/dev/null || echo "${response}"
        rm -rf "${tmp_dir}"
        return 1
    fi

    echo "✅ 登録完了 (Konnect ID: ${registered_id})"

    # certs/ ディレクトリに配置
    cp "${tmp_key}" "${certs_dir}/tls.key"
    cp "${tmp_crt}" "${certs_dir}/tls.crt"
    chmod 644 "${certs_dir}/tls.key"
    chmod 644 "${certs_dir}/tls.crt"

    rm -rf "${tmp_dir}"

    echo "✅ 証明書を ${certs_dir}/ に保存しました"
    echo "   - tls.crt  (Konnect 登録 ID: ${registered_id})"
    echo "   - tls.key"
}
# }}}


# {{{ get_kc_admin_token()
get_kc_admin_token() {
	local kc_url="$1"
	local admin_user="$2"
	local admin_pass="$3"

	echo "🔐 Keycloak Admin トークンを取得中 (待機リトライ有効)..." >&2

	# コマンド全体を文字列として渡す
	local cmd="curl -s -X POST ${kc_url}/realms/master/protocol/openid-connect/token \
		-d client_id=admin-cli \
		-d username=${admin_user} \
		-d password=${admin_pass} \
		-d grant_type=password"

	local response=$(loop_curl_until_success "$cmd")
	local tkn=$(echo "${response}" | jq -r .access_token)

	if [ "$tkn" == "null" ] || [ -z "$tkn" ]; then
		echo "❌ Keycloak Admin トークン取得失敗" >&2
		exit 1
	fi
	echo "${tkn}"
}
# }}}

# {{{ create_kc_realm()
create_kc_realm() {
	local kc_url="$1"
	local tkn="$2"
	local realm="$3"

	echo "🏗️ Realm '${realm}' を作成中..." >&2

	local cmd="curl -s -X POST ${kc_url}/admin/realms \
		-H 'Authorization: Bearer ${tkn}' \
		-H 'Content-Type: application/json' \
		-d '{\"realm\": \"${realm}\", \"enabled\": true}'"

	loop_curl_until_success "$cmd" > /dev/null || echo "⚠️ Realm '${realm}' はすでに存在します" >&2
}
# }}}

# {{{ create_kc_client_get_secret()
create_kc_client_get_secret() {
local kc_url="$1"
local tkn="$2"
local realm="$3"
local cid="$4"
local redirect_uris="$5"

echo "🤖 Client '${cid}' を作成中..." >&2

# 1. クライアント作成
	local cmd_create="curl -s -X POST ${kc_url}/admin/realms/${realm}/clients \
		-H 'Authorization: Bearer ${tkn}' \
		-H 'Content-Type: application/json' \
		-d '{
  \"clientId\": \"${cid}\",
  \"enabled\": true,
  \"clientAuthenticatorType\": \"client-secret\",
  \"redirectUris\": ${redirect_uris},
  \"standardFlowEnabled\": true,
  \"serviceAccountsEnabled\": true,
  \"publicClient\": false
}'"
	loop_curl_until_success "$cmd_create" > /dev/null || echo "⚠️ Client '${cid}' はすでに存在します" >&2

	# 2. 内部ID取得
	local cmd_get_id="curl -s -H 'Authorization: Bearer ${tkn}' ${kc_url}/admin/realms/${realm}/clients?clientId=${cid}"
	local internal_id=$(loop_curl_until_success "$cmd_get_id" | jq -r '.[0].id')

	# 3. シークレット取得
	local cmd_get_secret="curl -s -H 'Authorization: Bearer ${tkn}' ${kc_url}/admin/realms/${realm}/clients/${internal_id}/client-secret"
	local secret=$(loop_curl_until_success "$cmd_get_secret" | jq -r '.value')

	echo "${secret}"
}
# }}}

# {{{ create_kc_user()
create_kc_user() {
	local kc_url="$1"
	local tkn="$2"
	local realm="$3"
	local uname="$4"
	local upass="$5"
	local uemail="$6"
	local ufirst="$7"
	local ulast="$8"

	echo "👤 User '${uname}' を作成中..." >&2

	local cmd="curl -s -X POST ${kc_url}/admin/realms/${realm}/users \
		-H 'Authorization: Bearer ${tkn}' \
		-H 'Content-Type: application/json' \
		-d '{
  \"username\": \"${uname}\",
  \"email\": \"${uemail}\",
  \"firstName\": \"${ufirst}\",
  \"lastName\": \"${ulast}\",
  \"emailVerified\": true,
  \"enabled\": true,
  \"credentials\": [{\"type\": \"password\", \"value\": \"${upass}\", \"temporary\": false}]
}'"

	loop_curl_until_success "$cmd" > /dev/null || echo "⚠️ User '${uname}' はすでに存在します" >&2
}
# }}}


# {{{ auth_test_check_name_resolution()
auth_test_check_name_resolution() {
	local host="$1"
	echo "🔍 Checking name resolution for: ${host} ..." >&2
    
	# getent で名前解決ができるか確認
	if ! getent hosts "${host}" > /dev/null; then
		echo "❌ Error: '${host}' の名前解決ができません。" >&2
		echo "   /etc/hosts に '127.0.0.1 ${host}' が登録されているか確認してください。" >&2
		return 1
	fi
	echo "✅ Name resolution OK." >&2
}
# }}}

# {{{ auth_test_gen_verifier()
auth_test_gen_verifier() {
	openssl rand -base64 32 | tr -d '\n' | tr '/+' '_-' | tr -d '='
}
# }}}

# {{{ auth_test_calc_challenge()
auth_test_calc_challenge() {
	local verifier="$1"
	echo -n "${verifier}" | openssl dgst -binary -sha256 | base64 | tr -d '\n' | tr '/+' '_-' | tr -d '='
}
# }}}

# {{{ auth_test_fetch_config()
auth_test_fetch_config() {
	local url="$1"
	curl -s "${url}"
}
# }}}

# {{{ auth_test_get_endpoint()
auth_test_get_endpoint() {
	local json="$1"
	local key="$2"
	echo "${json}" | jq -r ".${key}"
}
# }}}

# {{{ auth_test_post_login()
auth_test_post_login() {
	local login_url="$1"
	local user="$2"
	local pass="$3"
	local cookie="$4"

	curl -s --include -X POST "${login_url}" \
		-b "${cookie}" \
		-d "username=${user}" \
		-d "password=${pass}" | \
		grep -i "Location:" | sed -e 's/Location: //' | tr -d '\r\n' | xargs
}
# }}}


# {{{ auth_test_pep_get_login_url()
auth_test_pep_get_login_url() {
	local auth_ep="$1"
	local cid="$2"
	local redir="$3"
	local chalng="$4"
	local cookie="$5"
	local kc_host="$6"

	# HTMLからactionのURLを抽出し、&amp; を & に正確に置換
	local action=$(curl -s -G "${auth_ep}" \
		--data-urlencode "scope=openid" \
		--data-urlencode "response_type=code" \
		--data-urlencode "client_id=${cid}" \
		--data-urlencode "redirect_uri=${redir}" \
		--data-urlencode "code_challenge=${chalng}" \
		--data-urlencode "code_challenge_method=S256" \
		-c "${cookie}" | \
		grep -i "action=" | \
		sed -n 's/.*action="\([^"]*\)".*/\1/p' | head -n 1 | \
		sed 's/&amp;/\&/g')

	# 相対パス（/realms/...）ならベースURLを付与
	if [[ "${action}" == /* ]]; then
		echo "${kc_host}$action"
	else
		echo "${action}"
	fi
}
# }}}

# {{{ auth_test_pep_extract_code()
auth_test_pep_extract_code() {
	local url="$1"
	# [超重要] code= の直後から「&」または「URLの終端」までを切り出す
	echo -n "${url}" | grep -oP 'code=\K[^& ]+' || true
}
# }}}

# {{{ auth_test_pep_exchange_token()
auth_test_pep_exchange_token() {
	local token_ep="$1"
	local code="$2"
	local cid="$3"
	local secret="$4"
	local redir="$5"
	local verifier="$6"

	curl -s -X POST "${token_ep}" \
		-d "grant_type=authorization_code" \
		-d "code=${code}" \
		-d "client_id=${cid}" \
		-d "client_secret=${secret}" \
		-d "redirect_uri=${redir}" \
		-d "code_verifier=${verifier}"
}
# }}}


# {{{ auth_test_bff_init_flow()
# BFF ログインエンドポイントにアクセスして、Keycloak へのリダイレクト先を取得
auth_test_bff_init_flow() {
    local bff_url="$1"
    local cookie="$2"
    # Kong が発行する一時的な Cookie を保存しつつリダイレクト先を表示
    curl -s -o /dev/null -c "$cookie" -w "%{redirect_url}" "$bff_url"
}
# }}}

# {{{ auth_test_bff_check_unauth()
# API エンドポイントへ Cookie なしでアクセスし、HTTP ステータスコードを返す
# SPA BFF パターンでは 401 が返ることを期待する
auth_test_bff_check_unauth() {
    local url="$1"
    curl -s -o /dev/null -w "%{http_code}" "$url"
}
# }}}

# {{{ auth_test_bff_get_login_url()
# 2️⃣ Keycloak ログイン画面の action URL を解析（BFF/PEP 汎用）
auth_test_bff_get_login_url()
{
    local init_url="$1"
    local cookie="$2"
    local kc_host="$3"

    local action=$(curl -s -b "$cookie" -c "$cookie" "$init_url" | \
        sed -n 's/.*action="\([^"]*\)".*/\1/p' | head -n 1 | \
        sed 's/&amp;/\&/g')

    # 相対パスの場合はホストを補完
    if [[ "$action" == /* ]]; then
        echo "${kc_host}${action}"
    else
        echo "${action}"
    fi
}
# }}}

# {{{ auth_test_bff_finalize_login()
# 4️⃣ Kong のコールバックへ戻り、最終的なセッション Cookie を取得
auth_test_bff_finalize_login() {
    local callback_url="$1"
    local cookie="$2"
    # 全てのクッキー（State等）を携えて Kong に戻り、セッションを確立させる
    curl -s -L -b "$cookie" -c "$cookie" "$callback_url" > /dev/null
}
# }}}


# {{{ auth_test_client_cred_get_token()
# Client Credentials Grant でトークンを直接取得する
auth_test_client_cred_get_token() {
	local token_ep="$1"
	local cid="$2"
	local secret="$3"

	curl -s -X POST "${token_ep}" \
		-d "grant_type=client_credentials" \
		-d "client_id=${cid}" \
		-d "client_secret=${secret}"
}
# }}}

