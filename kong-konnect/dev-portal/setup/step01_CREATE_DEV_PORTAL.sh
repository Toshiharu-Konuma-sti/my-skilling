#!/bin/bash
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh

ENV_AUTH="${CUR_DIR}/.env-konnect-auth"
#	ENV_KC_CLIENT="${CUR_DIR}/.env_keycloak_client"

create_konnect_auth_file "$ENV_AUTH"
load_env_file "$ENV_AUTH"
#	load_env_file "$ENV_KC_CLIENT"

# 基本設定
KONNECT_ADDR="https://${REGION}.api.konghq.com"
CP_NM=${CP_NAME}
KONNECT_TOKEN=${KONNECT_PAT}

# Dev Portal 設定
PORTAL_JSON="${CUR_DIR}/portal/portal.json"
DESIGN_JSON="${CUR_DIR}/portal/design.json"
LOGO_FILE="${CUR_DIR}/portal/logo.png"
FAVICON_FILE="${CUR_DIR}/portal/favicon.png"

# {{{ main()
main()
{
	# 実行環境に必須コマンドの存在を確認
	check_required_commands "curl" "jq"

	# JSON ファイルの存在確認
	if [ ! -f "${PORTAL_JSON}" ]; then
		echo "❌ Portal JSON ファイルが見つかりません: ${PORTAL_JSON}"
		exit 1
	fi

	local portal_name
	portal_name=$(jq -r '.name' "${PORTAL_JSON}")

	# -------------------------------------------------------
	# Step 1: 既存 Dev Portal の一覧を取得し、重複を確認
	# -------------------------------------------------------
	echo "### 🔍 既存 Dev Portal の一覧を確認 ..."
	local existing_portals
	existing_portals=$(fetch_konnect_portals "${KONNECT_ADDR}" "${KONNECT_TOKEN}")

	if ! echo "${existing_portals}" | jq -e '.data' > /dev/null 2>&1; then
		echo "❌ Konnect API へのアクセスに失敗しました。Token / Region を確認してください。"
		echo "${existing_portals}" | jq '.' 2>/dev/null || echo "${existing_portals}"
		exit 1
	fi

	local existing_id
	existing_id=$(echo "${existing_portals}" | jq -r --arg NAME "${portal_name}" '.data[] | select(.name == $NAME) | .id')

	# -------------------------------------------------------
	# Step 2: 新規作成 または 更新
	# -------------------------------------------------------
	local tmp_body http_code expected_code action_label
	tmp_body=$(mktemp /tmp/konnect_portal_XXXXXX.json)

	if [ -n "${existing_id}" ]; then
		echo "### ♻️  Dev Portal 更新 (PATCH): ${portal_name} (ID: ${existing_id}) ..."
		action_label="更新"
		expected_code="200"
		http_code=$(update_konnect_portal \
			"${KONNECT_ADDR}" \
			"${KONNECT_TOKEN}" \
			"${existing_id}" \
			"${PORTAL_JSON}" \
			"${tmp_body}")
	else
		echo "### 🚀 Dev Portal 新規作成 (POST): ${portal_name} ..."
		action_label="作成"
		expected_code="201"
		http_code=$(create_konnect_portal \
			"${KONNECT_ADDR}" \
			"${KONNECT_TOKEN}" \
			"${PORTAL_JSON}" \
			"${tmp_body}")
	fi

	local body
	body=$(cat "${tmp_body}")
	rm -f "${tmp_body}"

	if [ "${http_code}" != "${expected_code}" ]; then
		echo "❌ Dev Portal の${action_label}に失敗しました (HTTP: ${http_code})"
		echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
		exit 1
	fi

	# -------------------------------------------------------
	# Step 3: カスタマイズの更新 (design.json がある場合)
	# -------------------------------------------------------
	local portal_id portal_url
	portal_id=$(echo "${body}" | jq -r '.id // empty')
	portal_url=$(echo "${body}" | jq -r '.portal_url // "N/A"')

	if [ -f "${DESIGN_JSON}" ]; then
		echo "### 🎨 Dev Portal カスタマイズ更新 (PATCH): ${portal_id} ..."
		local tmp_design
		tmp_design=$(mktemp /tmp/konnect_portal_design_XXXXXX.json)

		local design_code
		design_code=$(update_konnect_portal_customization \
			"${KONNECT_ADDR}" \
			"${KONNECT_TOKEN}" \
			"${portal_id}" \
			"${DESIGN_JSON}" \
			"${tmp_design}")

		local design_body
		design_body=$(cat "${tmp_design}")
		rm -f "${tmp_design}"

		if [ "${design_code}" = "200" ]; then
			local primary_color
			primary_color=$(echo "${design_body}" | jq -r '.theme.colors.primary // "N/A"')
			echo "✅ カスタマイズを更新しました！"
			echo "   - Brand Color: ${primary_color}"
		else
			echo "⚠️  カスタマイズの更新に失敗しました (HTTP: ${design_code})"
			echo "${design_body}" | jq '.' 2>/dev/null || echo "${design_body}"
		fi
	fi

	# ロゴ / ファビコンのアップロード
	local asset_name asset_file
	for asset_name in logo favicon; do
		if [ "${asset_name}" = "logo" ]; then
			asset_file="${LOGO_FILE}"
		else
			asset_file="${FAVICON_FILE}"
		fi

		if [ ! -f "${asset_file}" ]; then
			continue
		fi

		echo "### 🖼️  Dev Portal ${asset_name} アップロード (PUT): ${portal_id} ..."
		local tmp_asset
		tmp_asset=$(mktemp /tmp/konnect_portal_asset_XXXXXX.json)

		local asset_code
		asset_code=$(upload_konnect_portal_asset \
			"${KONNECT_ADDR}" \
			"${KONNECT_TOKEN}" \
			"${portal_id}" \
			"${asset_name}" \
			"${asset_file}" \
			"${tmp_asset}")

		local asset_body
		asset_body=$(cat "${tmp_asset}")
		rm -f "${tmp_asset}"

		if [ "${asset_code}" = "200" ]; then
			echo "✅ ${asset_name} をアップロードしました！"
		else
			echo "⚠️  ${asset_name} のアップロードに失敗しました (HTTP: ${asset_code})"
			echo "${asset_body}" | jq '.' 2>/dev/null || echo "${asset_body}"
		fi
	done

	# -------------------------------------------------------
	# Step 4: 結果の表示
	# -------------------------------------------------------
	echo "✅ Dev Portal を${action_label}しました！"
	echo "   - Portal Name : ${portal_name}"
	echo "   - Portal ID   : ${portal_id}"
	echo "   - Portal URL  : ${portal_url}"
}
# }}}

start_banner
main
finish_banner $S_TIME
