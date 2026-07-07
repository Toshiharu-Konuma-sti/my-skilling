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

# Kong Gateway 設定 (スペース区切りでディレクトリを複数指定可能)
API_LIST="api001"

# {{{ main()
main()
{
	# 実行環境に必須コマンドの存在を確認
	check_required_commands "deck"

	echo "### 🚀 接続確認: deck gateway ping ..."
	deck gateway ping \
		--konnect-token "${KONNECT_TOKEN}" \
		--konnect-addr "${KONNECT_ADDR}" \
		--konnect-control-plane-name "${CP_NM}"

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

			local base_name kng_file
			base_name=$(basename "${oas_file}" "-oas.yaml")
			kng_file="${dir_path}/${base_name}-kng.yaml"

			echo ""
			echo "=========================================="
			echo "📦 処理中: ${api_dir}/${base_name}"
			echo "   - OAS File : ${oas_file}"
			echo "   - KNG File : ${kng_file}"
			echo "=========================================="

			# OAS → Kong 設定ファイルに変換
			echo "### 📦 deck file openapi2kong (${base_name}) ..."
			deck file openapi2kong -s "${oas_file}" -o "${kng_file}"

			# Kong 設定ファイルの書式を確認
			echo "### 🔍 deck gateway validate (${base_name}) ..."
			deck gateway validate "${kng_file}" \
				--konnect-token "${KONNECT_TOKEN}" \
				--konnect-addr "${KONNECT_ADDR}" \
				--konnect-control-plane-name "${CP_NM}"

			# Konnect へ設定を適用
			echo "### 🚢 deck gateway apply (${base_name}) ..."
			deck gateway apply "${kng_file}" \
				--konnect-token "${KONNECT_TOKEN}" \
				--konnect-addr "${KONNECT_ADDR}" \
				--konnect-control-plane-name "${CP_NM}"

			echo "✅ ${base_name} の Gateway 登録が完了しました。"
		done  # *-oas.yaml ループ終端
	done  # API_LIST ループ終端

	echo ""
	echo "🎉 全ての Gateway 登録プロセスが正常に終了しました！"
}
# }}}

start_banner
main
finish_banner $S_TIME
finish_banner $S_TIME