#!/bin/bash
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh

ENV_AUTH="${CUR_DIR}/.env-konnect-auth"

create_konnect_auth_file "$ENV_AUTH"
load_env_file "$ENV_AUTH"

# 基本設定
KONNECT_ADDR="https://${REGION}.api.konghq.com"
CP_NM=${CP_NAME}
KONNECT_TOKEN=${KONNECT_PAT}

# 設定 (スペース区切りでディレクトリを複数指定可能)
API_LIST="api001"

# {{{ main()
main()
{
	# 実行環境に必須コマンドの存在を確認
	check_required_commands "curl" "jq" "awk"

	# -------------------------------------------------------
	# Step 1: Control Plane ID の取得
	# -------------------------------------------------------
	echo "### 🔍 Control Plane ID の取得: ${CP_NM} ..."
	local cp_resp cp_id
	cp_resp=$(curl -s -X GET \
		"${KONNECT_ADDR}/v2/control-planes" \
		-H "Authorization: Bearer ${KONNECT_TOKEN}")
	cp_id=$(echo "${cp_resp}" | \
		jq -r --arg CP "${CP_NM}" '(.data // [])[] | select(.name == $CP) | .id // empty')

	if [ -z "${cp_id}" ] || [ "${cp_id}" = "null" ]; then
		echo "❌ Control Plane '${CP_NM}' が見つかりませんでした。"
		exit 1
	fi
	echo "   - CP Name : ${CP_NM}"
	echo "   - CP ID   : ${cp_id}"

	local api_dir
	for api_dir in ${API_LIST}; do
		local dir_path="${CUR_DIR}/${api_dir}"

		if [ ! -d "${dir_path}" ]; then
			echo "⚠️  ディレクトリが見つかりません: ${dir_path} - スキップします"
			continue
		fi

		local oas_file
		for oas_file in "${dir_path}"/*-oas.yaml; do
			if [ ! -f "${oas_file}" ]; then
				echo "⚠️  ${api_dir} に *-oas.yaml が見つかりません - スキップします"
				continue
			fi

			local base_name api_json
			base_name=$(basename "${oas_file}" "-oas.yaml")
			api_json="${dir_path}/${base_name}-api.json"

			if [ ! -f "${api_json}" ]; then
				echo "⚠️  API JSON が見つかりません: ${api_json} - スキップします"
				continue
			fi

			echo ""
			echo "=========================================="
			echo "📦 処理中: ${api_dir}/${base_name}"
			echo "=========================================="

			# -------------------------------------------------------
			# Step 2: Catalog API ID の取得
			# -------------------------------------------------------
			local api_name existing_apis api_id
			api_name=$(jq -r '.name' "${api_json}")
			echo "### 🔍 Catalog API の検索: ${api_name} ..."
			existing_apis=$(fetch_konnect_api_by_name "${KONNECT_ADDR}" "${KONNECT_TOKEN}" "${api_name}")
			api_id=$(echo "${existing_apis}" | \
				jq -r --arg NAME "${api_name}" '(.data // [])[] | select(.name == $NAME) | .id // empty')

			if [ -z "${api_id}" ]; then
				echo "### ➕ Catalog API が見つからないため新規作成します: ${api_name} ..."
				local tmp_api
				tmp_api=$(mktemp /tmp/konnect_api_XXXXXX.json)
				local http_api api_body
				http_api=$(create_konnect_api "${KONNECT_ADDR}" "${KONNECT_TOKEN}" "${api_json}" "${tmp_api}")
				api_body=$(cat "${tmp_api}")
				rm -f "${tmp_api}"

				if [ "${http_api}" != "201" ]; then
					echo "❌ Catalog API の作成に失敗しました (HTTP: ${http_api})"
					echo "${api_body}" | jq '.' 2>/dev/null || echo "${api_body}"
					continue
				fi
				api_id=$(echo "${api_body}" | jq -r '.id // empty')
				echo "✅ Catalog API を作成しました！"
			fi
			echo "   - API Name : ${api_name}"
			echo "   - API ID   : ${api_id}"

			# -------------------------------------------------------
			# Step 3: Gateway Service ID の取得
			# -------------------------------------------------------
			local svc_name svc_resp svc_id
			svc_name=$(awk '/^[[:space:]]*x-kong-name:/ {gsub(/["\047\r]/, "", $2); print $2; exit}' "${oas_file}")
			echo "### 🔍 Gateway Service の検索: ${svc_name} ..."
			svc_resp=$(curl -s -X GET \
				"${KONNECT_ADDR}/v2/control-planes/${cp_id}/core-entities/services/${svc_name}" \
				-H "Authorization: Bearer ${KONNECT_TOKEN}")
			svc_id=$(echo "${svc_resp}" | jq -r '.id // empty')

			if [ -z "${svc_id}" ] || [ "${svc_id}" = "null" ]; then
				echo "⚠️  Gateway Service '${svc_name}' が見つかりません。step02 を先に実行してください。"
				continue
			fi
			echo "   - Service Name: ${svc_name}"
			echo "   - Service ID  : ${svc_id}"

			# -------------------------------------------------------
			# Step 4: Gateway Service を Catalog API に紐付ける
			# -------------------------------------------------------
			echo "### 🔗 Catalog API ↔ Gateway Service の紐付け ..."
			local impl_payload tmp_impl http_impl
			impl_payload=$(jq -n \
				--arg cp_id "${cp_id}" \
				--arg svc_id "${svc_id}" \
				'{service: {control_plane_id: $cp_id, id: $svc_id}}')
			tmp_impl=$(mktemp /tmp/konnect_impl_XXXXXX.json)
			http_impl=$(curl -s \
				-o "${tmp_impl}" \
				-w "%{http_code}" \
				-X POST \
				"${KONNECT_ADDR}/v3/apis/${api_id}/implementations" \
				-H "Authorization: Bearer ${KONNECT_TOKEN}" \
				-H "Content-Type: application/json" \
				-d "${impl_payload}")

			local impl_body impl_id
			impl_body=$(cat "${tmp_impl}")
			rm -f "${tmp_impl}"

			if [ "${http_impl}" = "201" ]; then
				impl_id=$(echo "${impl_body}" | jq -r '.id // empty')
				echo "✅ 紐付け完了！"
				echo "   - Implementation ID: ${impl_id}"
				echo "   - API Name         : ${api_name}"
				echo "   - Service Name     : ${svc_name}"
			elif [ "${http_impl}" = "409" ]; then
				echo "⚠️  紐付けは既に存在します (HTTP: ${http_impl}) - 後続処理を継続します"
				echo "${impl_body}" | jq '.' 2>/dev/null || echo "${impl_body}"
			else
				echo "❌ 紐付けに失敗しました (HTTP: ${http_impl})"
				echo "${impl_body}" | jq '.' 2>/dev/null || echo "${impl_body}"
				continue
			fi

			# -------------------------------------------------------
			# Step 5: OAS ファイルを API Specification として登録する
			# -------------------------------------------------------
			echo "### 📄 API Specification の登録 ..."
			local version oas_content ver_payload tmp_ver http_ver ver_body
			version=$(awk '/^info:/{f=1} f && /^  version:/{gsub(/["\r]/, "", $2); print $2; exit}' "${oas_file}")
			oas_content=$(cat "${oas_file}")
			ver_payload=$(jq -n --arg content "${oas_content}" \
				'{spec: {content: $content}}')
			tmp_ver=$(mktemp /tmp/konnect_ver_XXXXXX.json)
			http_ver=$(create_konnect_api_version "${KONNECT_ADDR}" "${KONNECT_TOKEN}" \
				"${api_id}" "${ver_payload}" "${tmp_ver}")
			ver_body=$(cat "${tmp_ver}")
			rm -f "${tmp_ver}"

			if [ "${http_ver}" = "201" ]; then
				echo "✅ API Specification を登録しました！ (v${version})"
			elif [ "${http_ver}" = "409" ]; then
				echo "⚠️  API Specification は既に存在します (HTTP: ${http_ver}) - 後続処理を継続します"
				echo "${ver_body}" | jq '.' 2>/dev/null || echo "${ver_body}"
			else
				echo "⚠️  API Specification の登録に失敗しました (HTTP: ${http_ver})"
				echo "${ver_body}" | jq '.' 2>/dev/null || echo "${ver_body}"
			fi

			# -------------------------------------------------------
			# Step 6: Documentation の登録
			# -------------------------------------------------------
			echo "### 📝 Documentation の登録 ..."
			local existing_docs
			existing_docs=$(fetch_konnect_api_documents "${KONNECT_ADDR}" "${KONNECT_TOKEN}" "${api_id}")

			local doc_json
			for doc_json in "${dir_path}/${base_name}"-doc-*.json; do
				if [ ! -f "${doc_json}" ]; then
					echo "   - ドキュメントファイルが見つかりません - スキップします"
					continue
				fi

				local doc_md
				doc_md="${doc_json%.json}.md"
				if [ ! -f "${doc_md}" ]; then
					echo "⚠️  ドキュメント本文が見つかりません: ${doc_md} - スキップします"
					continue
				fi

				local doc_title doc_slug doc_status doc_content
				doc_title=$(jq -r '.title' "${doc_json}")
				doc_slug=$(jq -r '.slug' "${doc_json}")
				doc_status=$(jq -r '.status' "${doc_json}")
				doc_content=$(cat "${doc_md}")

				local existing_doc_id
				existing_doc_id=$(echo "${existing_docs}" | \
					jq -r --arg SLUG "${doc_slug}" '(.data // [])[] | select(.slug == $SLUG) | .id // empty')

				local doc_payload tmp_doc http_doc doc_body
				doc_payload=$(jq -n \
					--arg title "${doc_title}" \
					--arg slug "${doc_slug}" \
					--arg status "${doc_status}" \
					--arg content "${doc_content}" \
					'{title: $title, slug: $slug, status: $status, content: $content}')
				tmp_doc=$(mktemp /tmp/konnect_doc_XXXXXX.json)

				if [ -n "${existing_doc_id}" ]; then
					echo "   - ドキュメント '${doc_slug}' が既に存在します。更新します..."
					http_doc=$(update_konnect_api_document "${KONNECT_ADDR}" "${KONNECT_TOKEN}" \
						"${api_id}" "${existing_doc_id}" "${doc_payload}" "${tmp_doc}")
				else
					http_doc=$(create_konnect_api_document "${KONNECT_ADDR}" "${KONNECT_TOKEN}" \
						"${api_id}" "${doc_payload}" "${tmp_doc}")
				fi
				doc_body=$(cat "${tmp_doc}")
				rm -f "${tmp_doc}"

				if [ "${http_doc}" = "200" ]; then
					echo "✅ ドキュメント '${doc_slug}' を更新しました！"
				elif [ "${http_doc}" = "201" ]; then
					echo "✅ ドキュメント '${doc_slug}' を登録しました！"
				else
					echo "⚠️  ドキュメント '${doc_slug}' の登録/更新に失敗しました (HTTP: ${http_doc})"
					echo "${doc_body}" | jq '.' 2>/dev/null || echo "${doc_body}"
				fi
			done  # doc ループ終端

			# -------------------------------------------------------
			# Step 7: Dev Portal への公開
			# -------------------------------------------------------
			echo "### 🌐 Dev Portal への公開 ..."
			local portal_json_file portal_name portal_resp portal_id
			portal_json_file="${CUR_DIR}/portal/portal.json"
			portal_name=$(jq -r '.name' "${portal_json_file}")
			portal_resp=$(fetch_konnect_portals "${KONNECT_ADDR}" "${KONNECT_TOKEN}")
			portal_id=$(echo "${portal_resp}" | \
				jq -r --arg NAME "${portal_name}" '(.data // [])[] | select(.name == $NAME) | .id // empty')

			if [ -z "${portal_id}" ]; then
				echo "⚠️  Dev Portal '${portal_name}' が見つかりません。step01 を先に実行してください。"
			else
				local pub_payload tmp_pub http_pub pub_body
				pub_payload='{"visibility": "public"}'
				tmp_pub=$(mktemp /tmp/konnect_pub_XXXXXX.json)
				http_pub=$(publish_api_to_portal "${KONNECT_ADDR}" "${KONNECT_TOKEN}" \
					"${api_id}" "${portal_id}" "${pub_payload}" "${tmp_pub}")
				pub_body=$(cat "${tmp_pub}")
				rm -f "${tmp_pub}"

				if [ "${http_pub}" = "200" ] || [ "${http_pub}" = "201" ]; then
					echo "✅ Dev Portal '${portal_name}' に公開しました！"
					echo "   - Portal ID : ${portal_id}"
				else
					echo "⚠️  Dev Portal への公開に失敗しました (HTTP: ${http_pub})"
					echo "${pub_body}" | jq '.' 2>/dev/null || echo "${pub_body}"
				fi
			fi

		done  # *-oas.yaml ループ終端
	done  # API_LIST ループ終端

	echo ""
	echo "🎉 全ての Gateway 紐付けプロセスが完了しました！"
}
# }}}

start_banner
main
finish_banner $S_TIME