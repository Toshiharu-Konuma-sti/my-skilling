#!/bin/bash
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh

# .env を読み込む
if [ ! -f .env ]; then
    echo "❌ .env ファイルが見つかりません"
    exit 1
fi
source .env

API_BASE_URL="https://${REGION:-$(util_ask_input "🏢 Enter REGION (Control Plane Region): ")}.api.konghq.com/v2"
CP_NM=${CP_NAME:-$(util_ask_input "🏢 Enter CP_NAME (Control Plane Name): ")}
KONNECT_TOKEN=${KONNECT_PAT:-$(util_ask_secret "🔑 Enter KONNECT_PAT (Secret): ")}

case "$1" in
	*)
		start_banner

		CP_DATA=$(fetch_kong_cp_data "$API_BASE_URL" "$KONNECT_TOKEN" "$CP_NM")
		CP_ID=$(extract_kong_cp_id "$CP_DATA")
		check_kong_cp_id "$CP_ID" "$CP_NM"
		prepare_kong_cluster_info "$CP_DATA"
		prepare_kong_dp_certs "$CUR_DIR" "$API_BASE_URL" "$CP_ID" "$KONNECT_TOKEN"

		finish_banner $S_TIME
		;;
esac
