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

# API Catalog 設定 (スペース区切りでディレクトリを複数指定可能)
API_LIST="api001"
PORTAL_JSON="${CUR_DIR}/portal/portal.json"

# {{{ main()
main()
{
	# 実行環境に必須コマンドの存在を確認
	check_required_commands "curl" "jq"

	local api_dir
	for api_dir in ${API_LIST}; do
		local dir_path="${CUR_DIR}/${api_dir}"

		if [ ! -d "${dir_path}" ]; then
			echo "⚠️  ディレクトリが見つかりません: ${dir_path} - スキップします"
			continue
		fi

		local api_json
		for api_json in "${dir_path}"/*-api.json; do
			# グロブが一致しない場合はスキップ
			if [ ! -f "${api_json}" ]; then
				echo "⚠️  ${api_dir} に *-api.json が見つかりません - スキップします"
				continue
			fi

			# ベース名から対応 OAS ファイルを導出
			local base_name oas_file
			base_name=$(basename "${api_json}" "-api.json")
			oas_file="${dir_path}/${base_name}-oas.yaml"

			echo ""
			echo "=========================================="
			echo "📦 処理中: ${api_dir}/${base_name}"
			echo "   - API JSON : ${api_json}"
			echo "   - OAS File : ${oas_file}"
			echo "=========================================="

			local api_name
			api_name=$(jq -r '.name' "${api_json}")

			# -------------------------------------------------------
			# Step 1: 既存 API の検索 (name フィルターで完全一致検索)
			# -------------------------------------------------------
			echo "### 🔍 Catalog API の検索 ..."
			local existing_apis existing_id
			existing_apis=$(fetch_konnect_api_by_name "${KONNECT_ADDR}" "${KONNECT_TOKEN}" "${api_name}")

			if ! echo "${existing_apis}" | jq -e '.data' > /dev/null 2>&1; then
				echo "❌ Konnect API へのアクセスに失敗しました。Token / Region を確認してください。"
				echo "${existing_apis}" | jq '.' 2>/dev/null || echo "${existing_apis}"
				exit 1
			fi

			existing_id=$(echo "${existing_apis}" | \
				jq -r --arg NAME "${api_name}" '(.data // [])[] | select(.name == $NAME) | .id // empty')

			echo "   - API Name : ${api_name}"
			echo "   - API ID   : ${existing_id:-(未登録)}"

			# -------------------------------------------------------
			# Step 2: 新規作成 または 更新
			# -------------------------------------------------------
			local tmp_body http_code expected_code action_label api_id
			tmp_body=$(mktemp /tmp/konnect_api_XXXXXX.json)

			if [ -n "${existing_id}" ]; then
				echo "### ♻️  Catalog API 更新 (PATCH): ${api_name} (ID: ${existing_id}) ..."
				action_label="更新"
				expected_code="200"
				api_id="${existing_id}"
				http_code=$(update_konnect_api \
					"${KONNECT_ADDR}" \
					"${KONNECT_TOKEN}" \
					"${existing_id}" \
					"${api_json}" \
					"${tmp_body}")
			else
				echo "### 🚀 Catalog API 新規作成 (POST): ${api_name} ..."
				action_label="作成"
				expected_code="201"
				http_code=$(create_konnect_api \
					"${KONNECT_ADDR}" \
					"${KONNECT_TOKEN}" \
					"${api_json}" \
					"${tmp_body}")
			fi

			local body
			body=$(cat "${tmp_body}")
			rm -f "${tmp_body}"

			if [ "${http_code}" != "${expected_code}" ]; then
				echo "❌ Catalog API の${action_label}に失敗しました (HTTP: ${http_code})"
				echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
				exit 1
			fi

			# 新規作成の場合は body から ID を取得
			if [ "${action_label}" = "作成" ]; then
				api_id=$(echo "${body}" | jq -r '.id // empty')
			fi

			if [ -z "${api_id}" ] || [ "${api_id}" = "null" ]; then
				echo "❌ API ID の取得に失敗しました。"
				exit 1
			fi

			# -------------------------------------------------------
			# Step 3: OAS Specification の登録 (versions)
			# -------------------------------------------------------
			if [ -f "${oas_file}" ]; then
				echo "### 📄 API Specification 登録 ..."

				# OAS から version を抽出
				local oas_version
				oas_version=$(awk '/^[[:space:]]*version:/ {gsub(/["\047]/, "", $2); print $2; exit}' "${oas_file}")
				echo "   - OAS Version: ${oas_version}"

				# OAS コンテンツを埋め込んだペイロードを構築
				local version_payload
				version_payload=$(jq -n \
					--arg version "${oas_version}" \
					--rawfile content "${oas_file}" \
					'{version: $version, spec: {content: $content}}')

				# 既存バージョンを検索
				local versions_resp version_id
				versions_resp=$(fetch_konnect_api_versions "${KONNECT_ADDR}" "${KONNECT_TOKEN}" "${api_id}")
				version_id=$(echo "${versions_resp}" | \
					jq -r --arg v "${oas_version}" '(.data // [])[] | select(.version == $v) | .id // empty')

				local tmp_ver http_ver expected_ver ver_label
				tmp_ver=$(mktemp /tmp/konnect_ver_XXXXXX.json)

				if [ -n "${version_id}" ]; then
					echo "### ♻️  API Version 更新 (PATCH): ${oas_version} (ID: ${version_id}) ..."
					ver_label="更新"
					expected_ver="200"
					http_ver=$(update_konnect_api_version \
						"${KONNECT_ADDR}" \
						"${KONNECT_TOKEN}" \
						"${api_id}" \
						"${version_id}" \
						"${version_payload}" \
						"${tmp_ver}")
				else
					echo "### 🚀 API Version 新規作成 (POST): ${oas_version} ..."
					ver_label="作成"
					expected_ver="201"
					http_ver=$(create_konnect_api_version \
						"${KONNECT_ADDR}" \
						"${KONNECT_TOKEN}" \
						"${api_id}" \
						"${version_payload}" \
						"${tmp_ver}")
				fi

				local ver_body
				ver_body=$(cat "${tmp_ver}")
				rm -f "${tmp_ver}"

				if [ "${http_ver}" != "${expected_ver}" ]; then
					echo "❌ API Version の${ver_label}に失敗しました (HTTP: ${http_ver})"
					echo "${ver_body}" | jq '.' 2>/dev/null || echo "${ver_body}"
					exit 1
				fi

				# 新規作成の場合は body から ID を取得
				if [ "${ver_label}" = "作成" ]; then
					version_id=$(echo "${ver_body}" | jq -r '.id // empty')
				fi

				echo "✅ API Specification を${ver_label}しました！"
				echo "   - Version    : ${oas_version}"
				echo "   - Version ID : ${version_id}"
			else
				echo "⚠️  OAS ファイルなし: ${oas_file} - Specification 登録をスキップします"
			fi

			# -------------------------------------------------------
			# Step 4: Documentation の登録 (*-doc-*.json + .md)
			# -------------------------------------------------------
			echo "### 📝 API Documentation 登録 ..."
			local docs_resp
			docs_resp=$(fetch_konnect_api_documents "${KONNECT_ADDR}" "${KONNECT_TOKEN}" "${api_id}")

			local doc_json
			for doc_json in "${dir_path}/${base_name}"-doc-*.json; do
				if [ ! -f "${doc_json}" ]; then
					echo "   ⚠️  *-doc-*.json が見つかりません - Documentation 登録をスキップします"
					break
				fi

				local doc_md
				doc_md="${doc_json%.json}.md"
				if [ ! -f "${doc_md}" ]; then
					echo "   ⚠️  対応 .md ファイルなし: ${doc_md} - スキップします"
					continue
				fi

				# slug とペイロードを構築
				local doc_slug doc_payload
				doc_slug=$(jq -r '.slug' "${doc_json}")
				doc_payload=$(jq --rawfile content "${doc_md}" '. + {content: $content}' "${doc_json}")

				echo "   - slug: ${doc_slug}"

				# slug で既存ドキュメントを検索
				local doc_id
				doc_id=$(echo "${docs_resp}" | \
					jq -r --arg SLUG "${doc_slug}" '(.data // [])[] | select(.slug == $SLUG) | .id // empty')

				local tmp_doc http_doc expected_doc doc_label
				tmp_doc=$(mktemp /tmp/konnect_doc_XXXXXX.json)

				if [ -n "${doc_id}" ]; then
					echo "### ♻️  Document 更新 (PATCH): ${doc_slug} (ID: ${doc_id}) ..."
					doc_label="更新"
					expected_doc="200"
					http_doc=$(update_konnect_api_document \
						"${KONNECT_ADDR}" \
						"${KONNECT_TOKEN}" \
						"${api_id}" \
						"${doc_id}" \
						"${doc_payload}" \
						"${tmp_doc}")
				else
					echo "### 🚀 Document 新規作成 (POST): ${doc_slug} ..."
					doc_label="作成"
					expected_doc="201"
					http_doc=$(create_konnect_api_document \
						"${KONNECT_ADDR}" \
						"${KONNECT_TOKEN}" \
						"${api_id}" \
						"${doc_payload}" \
						"${tmp_doc}")
				fi

				local doc_body
				doc_body=$(cat "${tmp_doc}")
				rm -f "${tmp_doc}"

				if [ "${http_doc}" != "${expected_doc}" ]; then
					echo "❌ Document の${doc_label}に失敗しました (HTTP: ${http_doc})"
					echo "${doc_body}" | jq '.' 2>/dev/null || echo "${doc_body}"
					continue
				fi

				# 新規作成の場合は body から ID を取得
				if [ "${doc_label}" = "作成" ]; then
					doc_id=$(echo "${doc_body}" | jq -r '.id // empty')
				fi
				echo "✅ Document を${doc_label}しました！ (slug: ${doc_slug}, ID: ${doc_id})"
			done  # doc_json ループ終端

			# -------------------------------------------------------
			# Step 5: Dev Portal への紐付け (publication)
			# -------------------------------------------------------
			if [ -f "${PORTAL_JSON}" ]; then
				echo "### 🌐 Dev Portal への公開 ..."

				local portal_name portals_resp portal_id
				portal_name=$(jq -r '.name' "${PORTAL_JSON}")

				# portal 名で ID を検索
				portals_resp=$(fetch_konnect_portals "${KONNECT_ADDR}" "${KONNECT_TOKEN}")
				portal_id=$(echo "${portals_resp}" | \
					jq -r --arg NAME "${portal_name}" \
					'.data[] | select(.name == $NAME or .display_name == $NAME) | .id // empty' | \
					head -1)

				if [ -z "${portal_id}" ]; then
					echo "⚠️  Dev Portal '${portal_name}' が見つかりません。stepXX.sh を先に実行してください。"
				else
					echo "   - Portal Name: ${portal_name}"
					echo "   - Portal ID  : ${portal_id}"

					local pub_payload tmp_pub http_pub
					pub_payload=$(jq -n '{visibility: "public", auth_strategy_ids: null}')
					tmp_pub=$(mktemp /tmp/konnect_pub_XXXXXX.json)
					http_pub=$(publish_api_to_portal \
						"${KONNECT_ADDR}" \
						"${KONNECT_TOKEN}" \
						"${api_id}" \
						"${portal_id}" \
						"${pub_payload}" \
						"${tmp_pub}")

					local pub_body
					pub_body=$(cat "${tmp_pub}")
					rm -f "${tmp_pub}"

					if [ "${http_pub}" = "200" ]; then
						local pub_visibility
						pub_visibility=$(echo "${pub_body}" | jq -r '.visibility // "N/A"')
						echo "✅ Dev Portal に公開しました！"
						echo "   - Portal    : ${portal_name}"
						echo "   - Visibility: ${pub_visibility}"
					else
						echo "⚠️  Dev Portal への公開に失敗しました (HTTP: ${http_pub})"
						echo "${pub_body}" | jq '.' 2>/dev/null || echo "${pub_body}"
					fi
				fi
			fi

			# -------------------------------------------------------
			# Step 6: 結果の表示
			# -------------------------------------------------------
			echo "✅ Catalog API を${action_label}しました！"
			echo "   - API Name : ${api_name}"
			echo "   - API ID   : ${api_id}"

		done  # *-api.json ループ終端
	done  # API_LIST ループ終端

	echo ""
	echo "🎉 全ての API 登録プロセスが完了しました！"
}
# }}}

start_banner
main
finish_banner $S_TIME
