#!/bin/bash
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh

source $CUR_DIR/.env

KONNECT_ADDR="https://${REGION:-$(util_ask_input "🏢 Enter REGION (Control Plane Region): ")}.api.konghq.com"
CP_NM=${CP_NAME:-$(util_ask_input "🏢 Enter CP_NAME (Control Plane Name): ")}
KONNECT_TOKEN=${KONNECT_PAT:-$(util_ask_secret "🔑 Enter KONNECT_PAT (Secret): ")}

# {{{ main()
main()
{
	# 必須コマンドの存在確認
	check_required_commands "deck"

	echo "### 🚀 接続確認: deck gateway ping ..."
	deck gateway ping \
		--konnect-token "${KONNECT_TOKEN}" \
		--konnect-addr "${KONNECT_ADDR}" \
		--konnect-control-plane-name "${CP_NM}"

	echo "---[ Cleaning up Control Plane: ${CP_NM} ]---"

	echo "### 🧹 deck gateway reset (Delete ALL entities) ..."
	deck gateway reset -f \
		--konnect-token "${KONNECT_TOKEN}" \
		--konnect-addr "${KONNECT_ADDR}" \
		--konnect-control-plane-name "${CP_NM}"

	echo "✅ コントロールプレーン '${CP_NM}' の清掃が完了しました。"
	echo ""

	echo "🎉 全てのクリーンアッププロセスが正常に終了しました！"
}
# }}}

start_banner
main
finish_banner $S_TIME
