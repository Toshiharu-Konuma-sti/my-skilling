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

	local api_dir
	for api_dir in ${API_LIST}; do
		local dir_path="${CUR_DIR}/${api_dir}"

		if [ ! -d "${dir_path}" ]; then
			echo "⚠️  ディレクトリが見つかりません: ${dir_path} - スキップします"
			continue
		fi

		local api_json
		for api_json in "${dir_path}"/*-api.json; do
			if [ ! -f "${api_json}" ]; then
				echo "⚠️  ${api_dir} に *-api.json が見つかりません - スキップします"
				continue
			fi

			local base_name api_name
			base_name=$(basename "${api_json}" "-api.json")
			api_name=$(jq -r '.name' "${api_json}")

			echo ""
			echo "=========================================="
			echo "🗑️  削除対象: ${api_dir}/${base_name}"
			echo "   - API Name : ${api_name}"
			echo "=========================================="

			# -------------------------------------------------------
			# Step 1: Catalog API を name で検索
			# -------------------------------------------------------
			echo "### 🔍 Catalog API の検索 ..."
			local existing_apis api_id
			existing_apis=$(fetch_konnect_api_by_name "${KONNECT_ADDR}" "${KONNECT_TOKEN}" "${api_name}")
			api_id=$(echo "${existing_apis}" | \
				jq -r --arg NAME "${api_name}" '(.data // [])[] | select(.name == $NAME) | .id // empty')

			if [ -z "${api_id}" ]; then
				echo "⚠️  Catalog API '${api_name}' が見つかりません - スキップします"
				continue
			fi
			echo "   - API ID   : ${api_id}"

			# -------------------------------------------------------
			# Step 2: Catalog API を削除
			# -------------------------------------------------------
			echo "### 🗑️  Catalog API 削除 (DELETE): ${api_name} ..."
			local http_code
			http_code=$(delete_konnect_api "${KONNECT_ADDR}" "${KONNECT_TOKEN}" "${api_id}")

			if [ "${http_code}" = "204" ]; then
				echo "✅ Catalog API を削除しました！ (${api_name})"
			else
				echo "❌ Catalog API の削除に失敗しました (HTTP: ${http_code})"
			fi

		done  # *-api.json ループ終端
	done  # API_LIST ループ終端

	echo ""
	echo "🎉 Catalog API の削除処理が完了しました！"

	# -------------------------------------------------------
	# Phase 2: Gateway Service + Routes の削除
	# -------------------------------------------------------
	echo ""
	echo "### 🔍 Control Plane ID の取得: ${CP_NM} ..."
	local cp_resp cp_id
	cp_resp=$(curl -s -X GET \
		"${KONNECT_ADDR}/v2/control-planes" \
		-H "Authorization: Bearer ${KONNECT_TOKEN}")
	cp_id=$(echo "${cp_resp}" | \
		jq -r --arg CP "${CP_NM}" '(.data // [])[] | select(.name == $CP) | .id // empty')

	if [ -z "${cp_id}" ] || [ "${cp_id}" = "null" ]; then
		echo "❌ Control Plane '${CP_NM}' が見つかりませんでした。Gateway 削除をスキップします。"
	else
		echo "   - CP Name : ${CP_NM}"
		echo "   - CP ID   : ${cp_id}"

		local api_dir2
		for api_dir2 in ${API_LIST}; do
			local dir_path2="${CUR_DIR}/${api_dir2}"
			if [ ! -d "${dir_path2}" ]; then continue; fi

			local oas_file
			for oas_file in "${dir_path2}"/*-oas.yaml; do
				if [ ! -f "${oas_file}" ]; then continue; fi

				local base_name2 svc_name
				base_name2=$(basename "${oas_file}" "-oas.yaml")
				svc_name=$(awk '/^[[:space:]]*x-kong-name:/ {gsub(/["\047\r]/, "", $2); print $2; exit}' "${oas_file}")

				echo ""
				echo "=========================================="
				echo "🗑️  削除対象: ${api_dir2}/${base_name2}"
				echo "   - Service Name : ${svc_name}"
				echo "=========================================="

				# Service ID の取得
				echo "### 🔍 Gateway Service の検索: ${svc_name} ..."
				local svc_resp svc_id
				svc_resp=$(curl -s -X GET \
					"${KONNECT_ADDR}/v2/control-planes/${cp_id}/core-entities/services/${svc_name}" \
					-H "Authorization: Bearer ${KONNECT_TOKEN}")
				svc_id=$(echo "${svc_resp}" | jq -r '.id // empty')

				if [ -z "${svc_id}" ] || [ "${svc_id}" = "null" ]; then
					echo "⚠️  Gateway Service '${svc_name}' が見つかりません - スキップします"
					continue
				fi
				echo "   - Service ID   : ${svc_id}"

				# Routes の削除
				echo "### 🗑️  Routes 削除 ..."
				local routes_resp
				routes_resp=$(curl -s -X GET \
					"${KONNECT_ADDR}/v2/control-planes/${cp_id}/core-entities/services/${svc_id}/routes" \
					-H "Authorization: Bearer ${KONNECT_TOKEN}")

				local route_id
				for route_id in $(echo "${routes_resp}" | jq -r '(.data // [])[] | .id'); do
					local route_name route_del_http
					route_name=$(echo "${routes_resp}" | jq -r --arg ID "${route_id}" '(.data // [])[] | select(.id == $ID) | .name')
					route_del_http=$(curl -s -o /dev/null -w "%{http_code}" \
						-X DELETE \
						"${KONNECT_ADDR}/v2/control-planes/${cp_id}/core-entities/routes/${route_id}" \
						-H "Authorization: Bearer ${KONNECT_TOKEN}")
					if [ "${route_del_http}" = "204" ]; then
						echo "✅ Route を削除しました (${route_name})"
					else
						echo "❌ Route の削除に失敗しました (HTTP: ${route_del_http}, ${route_name})"
					fi
				done  # routes ループ終端

				# Gateway Service の削除
				echo "### 🗑️  Gateway Service 削除: ${svc_name} ..."
				local svc_del_http
				svc_del_http=$(curl -s -o /dev/null -w "%{http_code}" \
					-X DELETE \
					"${KONNECT_ADDR}/v2/control-planes/${cp_id}/core-entities/services/${svc_id}" \
					-H "Authorization: Bearer ${KONNECT_TOKEN}")
				if [ "${svc_del_http}" = "204" ]; then
					echo "✅ Gateway Service を削除しました (${svc_name})"
				else
					echo "❌ Gateway Service の削除に失敗しました (HTTP: ${svc_del_http})"
				fi

			done  # *-oas.yaml ループ終端
		done  # API_LIST ループ終端
	fi
	# -------------------------------------------------------
	# Phase 3: Dev Portal の削除
	# -------------------------------------------------------
	echo ""
	echo "### 🔍 Dev Portal の検索 ..."
	local portal_json_file portal_name portal_resp portal_id
	portal_json_file="${CUR_DIR}/portal/portal.json"
	portal_name=$(jq -r '.name' "${portal_json_file}")
	portal_resp=$(fetch_konnect_portals "${KONNECT_ADDR}" "${KONNECT_TOKEN}")
	portal_id=$(echo "${portal_resp}" | \
		jq -r --arg NAME "${portal_name}" '(.data // [])[] | select(.name == $NAME) | .id // empty')

	if [ -z "${portal_id}" ]; then
		echo "⚠️  Dev Portal '${portal_name}' が見つかりません - スキップします"
	else
		echo "   - Portal Name : ${portal_name}"
		echo "   - Portal ID   : ${portal_id}"
		echo "### 🗑️  Dev Portal 削除 (DELETE): ${portal_name} ..."
		local portal_del_http
		portal_del_http=$(curl -s -o /dev/null -w "%{http_code}" \
			-X DELETE \
			"${KONNECT_ADDR}/v3/portals/${portal_id}?force=true" \
			-H "Authorization: Bearer ${KONNECT_TOKEN}")
		if [ "${portal_del_http}" = "204" ]; then
			echo "✅ Dev Portal を削除しました (${portal_name})"
		else
			echo "❌ Dev Portal の削除に失敗しました (HTTP: ${portal_del_http})"
		fi
	fi
	echo ""
	echo "🎉 全ての削除処理が完了しました！"
}
# }}}

start_banner
main
finish_banner $S_TIME
finish_banner $S_TIME