#!/bin/bash
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh

ENV_AUTH="${CUR_DIR}/../container/.env-konnect-auth"

create_konnect_auth_file "$ENV_AUTH" "$1"
load_env_file "$ENV_AUTH"

# 基本設定
KONNECT_ADDR="https://${REGION}.api.konghq.com"
CP_NM=${CP_NAME}
KONNECT_TOKEN=${KONNECT_PAT}

# Kong AI GW を構成するマスター設定ファイルのリスト
# ※ 適用順序を意識して定義すること (サービス → ルート → プラグイン)
AIGW_FILES=(
	"${CUR_DIR}/aigw-service-kng.yaml"
	# --- Routes ---
	"${CUR_DIR}/proxy001/aigw-route-normal-kng.yaml"
	"${CUR_DIR}/proxy002/aigw-route-ratelimit-kng.yaml"
	"${CUR_DIR}/proxy003/aigw-route-guard-kng.yaml"
	"${CUR_DIR}/proxy004/aigw-route-decorator-kng.yaml"
	"${CUR_DIR}/proxy005/aigw-route-advanced-kng.yaml"
	# --- Plugins ---
	"${CUR_DIR}/proxy001/aigw-plugin-ai-proxy-normal-kng.yaml"
	"${CUR_DIR}/proxy002/aigw-plugin-ai-proxy-ratelimit-kng.yaml"
	"${CUR_DIR}/proxy002/aigw-plugin-ai-rate-limiting-advanced-kng.yaml"
	"${CUR_DIR}/proxy003/aigw-plugin-ai-proxy-guard-kng.yaml"
	"${CUR_DIR}/proxy003/aigw-plugin-ai-prompt-guard-kng.yaml"
	"${CUR_DIR}/proxy004/aigw-plugin-ai-proxy-decorator-kng.yaml"
	"${CUR_DIR}/proxy004/aigw-plugin-ai-prompt-decorator-kng.yaml"
	"${CUR_DIR}/proxy005/aigw-plugin-ai-proxy-advanced-kng.yaml"
)

# {{{ main()
main()
{
	# 実行環境に必須コマンドの存在を確認
	check_required_commands "deck"

	# マスター設定ファイルの存在確認
	echo "### 📋 設定ファイルの存在確認 ..."
	local missing_files=0
	for f in "${AIGW_FILES[@]}"; do
		if [ ! -f "$f" ]; then
			echo "❌ エラー: $(basename $f) が見つかりません: $f"
			missing_files=1
		else
			echo "  ✅ $(basename $f)"
		fi
	done
	if [ "$missing_files" -eq 1 ]; then
		exit 1
	fi

	echo "### 🚀 接続確認: deck gateway ping ..."
	deck gateway ping \
		--konnect-token "${KONNECT_TOKEN}" \
		--konnect-addr "${KONNECT_ADDR}" \
		--konnect-control-plane-name "${CP_NM}"

	# 全設定ファイルをまとめてバリデーション (位置引数として渡す)
	local deck_state_args=()
	for f in "${AIGW_FILES[@]}"; do
		deck_state_args+=("$f")
	done

	echo "### 🔍 deck gateway validate (全設定ファイル) ..."
	deck gateway validate \
		"${deck_state_args[@]}" \
		--konnect-token "${KONNECT_TOKEN}" \
		--konnect-addr "${KONNECT_ADDR}" \
		--konnect-control-plane-name "${CP_NM}"

	# 全設定ファイルをまとめてKonnectへ適用
	echo "### 🚢 deck gateway apply (全設定ファイル) ..."
	deck gateway apply \
		"${deck_state_args[@]}" \
		--konnect-token "${KONNECT_TOKEN}" \
		--konnect-addr "${KONNECT_ADDR}" \
		--konnect-control-plane-name "${CP_NM}"

	echo ""
	echo "🎉 Kong AI Gateway の設定が正常に完了しました！"
	echo "--------------------------------------------------"
	echo "🤖 [ai-proxy]                        POST http://localhost:8000/ai/normal/chat"
	echo "   モデル: llama3.1 (固定)"
	echo ""
	echo "🤖 [ai-proxy + ai-rate-limiting-advanced]"
	echo "                                     POST http://localhost:8000/ai/ratelimit/chat"
	echo "   制限: 500トークン / 60秒 / IP  (超過時 HTTP 429)"
	echo ""
	echo "🤖 [ai-proxy + ai-prompt-guard]"
	echo "                                     POST http://localhost:8000/ai/guard/chat"
	echo "   禁止: 電話番号 / パスワード / プロンプトインジェクション (違反時 HTTP 400)"
	echo ""
	echo "🤖 [ai-proxy + ai-prompt-decorator]"
	echo "                                     POST http://localhost:8000/ai/decorator/chat"
	echo "   システムプロンプト: 関西弁で回答 (クライアントから不可視)"
	echo ""
	echo "🤖 [ai-proxy-advanced]               POST http://localhost:8000/ai/advanced/chat"
	echo "   モデル: llama3.1 / phi3:mini (round-robin)"
	echo "--------------------------------------------------"
}
# }}}

start_banner
main
finish_banner $S_TIME
