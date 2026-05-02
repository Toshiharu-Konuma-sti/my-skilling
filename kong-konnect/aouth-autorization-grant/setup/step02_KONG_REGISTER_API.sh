#!/bin/bash
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh

ENV_AUTH="${CUR_DIR}/../container/.env-konnect-auth"
ENV_KC_CLIENT="${CUR_DIR}/.env_keycloak_client"

create_konnect_auth_file "$ENV_AUTH"
load_env_file "$ENV_AUTH"
load_env_file "$ENV_KC_CLIENT"

# 基本設定
KONNECT_ADDR="https://${REGION}.api.konghq.com"
CP_NM=${CP_NAME}
KONNECT_TOKEN=${KONNECT_PAT}

# Kongへルートとサービスを登録するOASファイルリスト(ファイル名から "-oas.yaml" を抜いたベース名を定義)
TARGETS=("oauth-auth-code-api-gw-pep" "oauth-auth-code-oidc-bff" "oauth-client-credentials" "oauth-bff-login")

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

	# Kongへ登録する各OASファイルをループで処理
	local base_name
	for base_name in "${TARGETS[@]}"; do
		local my_oas="${CUR_DIR}/${base_name}-oas.yaml"
		local my_kng="${CUR_DIR}/${base_name}-kng.yaml"

		echo "---[ Processing: ${base_name} ]---"

		if [ ! -f "${my_oas}" ]; then
			echo "⚠️ Warning: ${my_oas} が見つかりません。スキップします。"
			continue
		fi

		# OASファイルからKong設定ファイルに変換
		echo "### 📦 deck file openapi2kong (${base_name}) ..."
		deck file openapi2kong -s "${my_oas}" -o "${my_kng}"

		# Kong設定ファイルの書式を確認
		echo "### 🔍 deck gateway validate (${base_name}) ..."
		deck gateway validate "${my_kng}" \
			--konnect-token "${KONNECT_TOKEN}" \
			--konnect-addr "${KONNECT_ADDR}" \
			--konnect-control-plane-name "${CP_NM}"

		# Kongへ設定をKonnectへ適用
		echo "### 🚢 deck gateway apply (${base_name}) ..."
		deck gateway apply "${my_kng}" \
			--konnect-token "${KONNECT_TOKEN}" \
			--konnect-addr "${KONNECT_ADDR}" \
			--konnect-control-plane-name "${CP_NM}"

		echo "✅ ${base_name} の登録が完了しました。"
		echo ""
	done

	echo "🎉 全てのAPI登録プロセスが正常に終了しました！"
}
# }}}

start_banner
main
finish_banner $S_TIME
