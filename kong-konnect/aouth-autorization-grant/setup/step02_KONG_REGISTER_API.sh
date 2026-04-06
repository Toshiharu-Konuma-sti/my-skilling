#!/bin/bash
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh

# 環境変数の読み込み
source .env
source .env_keycloak_client

# Konnectへ渡す変数のエクスポート（BFF用とPEP用両方）
export DECK_KC_CLIENT_ID_OIDC_BFF
export DECK_KC_CLIENT_SECRET_OIDC_BFF
export DECK_KC_CLIENT_ID_API_GW_PEP
export DECK_KC_CLIENT_SECRET_API_GW_PEP
export DECK_KC_CLIENT_ID_CLIENT_CRED
export DECK_KC_CLIENT_SECRET_CLIENT_CRED

# 基本設定
KONNECT_ADDR="https://${REGION:-$(util_ask_input "🏢 Enter REGION (Control Plane Region): ")}.api.konghq.com"
CP_NM=${CP_NAME:-$(util_ask_input "🏢 Enter CP_NAME (Control Plane Name): ")}
KONNECT_TOKEN=${KONNECT_PAT:-$(util_ask_secret "🔑 Enter KONNECT_PAT (Secret): ")}

# 登録対象のOASファイルリスト(ファイル名から "-oas.yaml" を抜いたベース名を定義)
TARGETS=("oauth-auth-code-api-gw-pep" "oauth-auth-code-oidc-bff" "oauth-client-credentials" "oauth-bff-login")

# {{{ main()
main()
{
	echo "### 🚀 接続確認: deck gateway ping ..."
	deck gateway ping \
		--konnect-token "${KONNECT_TOKEN}" \
		--konnect-addr "${KONNECT_ADDR}" \
		--konnect-control-plane-name "${CP_NM}"

	# 各ファイルをループで処理
	local base_name
	for base_name in "${TARGETS[@]}"; do
		local my_oas="${CUR_DIR}/${base_name}-oas.yaml"
		local my_kng="${CUR_DIR}/${base_name}-kng.yaml"

		echo "---[ Processing: ${base_name} ]---"

		if [ ! -f "${my_oas}" ]; then
			echo "⚠️ Warning: ${my_oas} が見つかりません。スキップします。"
			continue
		fi

		echo "### 📦 deck file openapi2kong (${base_name}) ..."
		deck file openapi2kong -s "${my_oas}" -o "${my_kng}"

		echo "### 🔍 deck gateway validate (${base_name}) ..."
		deck gateway validate "${my_kng}" \
			--konnect-token "${KONNECT_TOKEN}" \
			--konnect-addr "${KONNECT_ADDR}" \
			--konnect-control-plane-name "${CP_NM}"

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
