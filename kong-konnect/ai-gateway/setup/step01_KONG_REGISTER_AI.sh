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
	"${CUR_DIR}/aigw-service-mcp-kng.yaml"
	# --- Routes ---
	"${CUR_DIR}/proxy001-normal/aigw-route-normal-kng.yaml"
	"${CUR_DIR}/proxy002-ratelimit/aigw-route-ratelimit-kng.yaml"
	"${CUR_DIR}/proxy003-prompt-guard/aigw-route-guard-kng.yaml"
	"${CUR_DIR}/proxy004-semantic-prompt-guard/aigw-route-semguard-kng.yaml"
	"${CUR_DIR}/proxy005-semantic-response-guard/aigw-route-semrespguard-kng.yaml"
	"${CUR_DIR}/proxy006-semantic-cache/aigw-route-semcache-kng.yaml"
	"${CUR_DIR}/proxy007-prompt-decorator/aigw-route-decorator-kng.yaml"
	"${CUR_DIR}/proxy008-request-transformer/aigw-route-reqtransform-kng.yaml"
	"${CUR_DIR}/proxy009-response-transformer/aigw-route-restransform-kng.yaml"
	"${CUR_DIR}/proxy010-advanced/aigw-route-advanced-kng.yaml"
	"${CUR_DIR}/proxy011-llm-as-judge/aigw-route-judge-kng.yaml"
	"${CUR_DIR}/proxy012-mcp-proxy/aigw-route-mcp-kng.yaml"
	# --- Plugins ---
	"${CUR_DIR}/proxy001-normal/aigw-plugin-ai-proxy-normal-kng.yaml"
	"${CUR_DIR}/proxy002-ratelimit/aigw-plugin-ai-proxy-ratelimit-kng.yaml"
	"${CUR_DIR}/proxy002-ratelimit/aigw-plugin-ai-rate-limiting-advanced-kng.yaml"
	"${CUR_DIR}/proxy003-prompt-guard/aigw-plugin-ai-proxy-guard-kng.yaml"
	"${CUR_DIR}/proxy003-prompt-guard/aigw-plugin-ai-prompt-guard-kng.yaml"
	"${CUR_DIR}/proxy004-semantic-prompt-guard/aigw-plugin-ai-proxy-semguard-kng.yaml"
	"${CUR_DIR}/proxy004-semantic-prompt-guard/aigw-plugin-ai-semantic-prompt-guard-kng.yaml"
	"${CUR_DIR}/proxy005-semantic-response-guard/aigw-plugin-ai-proxy-semrespguard-kng.yaml"
	"${CUR_DIR}/proxy005-semantic-response-guard/aigw-plugin-ai-semantic-response-guard-kng.yaml"
	"${CUR_DIR}/proxy006-semantic-cache/aigw-plugin-ai-proxy-semcache-kng.yaml"
	"${CUR_DIR}/proxy006-semantic-cache/aigw-plugin-ai-semantic-cache-kng.yaml"
	"${CUR_DIR}/proxy007-prompt-decorator/aigw-plugin-ai-proxy-decorator-kng.yaml"
	"${CUR_DIR}/proxy007-prompt-decorator/aigw-plugin-ai-prompt-decorator-kng.yaml"
	"${CUR_DIR}/proxy008-request-transformer/aigw-plugin-ai-proxy-reqtransform-kng.yaml"
	"${CUR_DIR}/proxy008-request-transformer/aigw-plugin-ai-request-transformer-kng.yaml"
	"${CUR_DIR}/proxy009-response-transformer/aigw-plugin-ai-proxy-restransform-kng.yaml"
	"${CUR_DIR}/proxy009-response-transformer/aigw-plugin-ai-response-transformer-kng.yaml"
	"${CUR_DIR}/proxy010-advanced/aigw-plugin-ai-proxy-advanced-kng.yaml"
	"${CUR_DIR}/proxy011-llm-as-judge/aigw-plugin-ai-proxy-advanced-judge-kng.yaml"
	"${CUR_DIR}/proxy011-llm-as-judge/aigw-plugin-ai-llm-as-judge-kng.yaml"
	"${CUR_DIR}/proxy012-mcp-proxy/aigw-plugin-ai-mcp-proxy-kng.yaml"
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
	echo "   モデル: qwen2.5:1.5b (固定)"
	echo ""
	echo "🤖 [ai-proxy + ai-rate-limiting-advanced]"
	echo "                                     POST http://localhost:8000/ai/ratelimit/chat"
	echo "   制限: 500トークン / 180秒 / IP  (超過時 HTTP 429)"
	echo ""
	echo "🤖 [ai-proxy + ai-prompt-guard]"
	echo "                                     POST http://localhost:8000/ai/guard/chat"
	echo "   禁止: 電話番号 / パスワード / プロンプトインジェクション (違反時 HTTP 400)"
	echo ""
	echo "🤖 [ai-proxy + ai-semantic-prompt-guard]"
	echo "                                     POST http://localhost:8000/ai/semguard/chat"
	echo "   VectorDB: Redis Stack / Embeddings: nomic-embed-text (768dim)"
	echo "   deny: プロンプトインジェクション / ジェイルブレイク / 危険コンテンツ"
	echo ""
	echo "🤖 [ai-proxy(tinyllama) + ai-semantic-response-guard]"
	echo "                                     POST http://localhost:8000/ai/semrespguard/chat"
	echo "   VectorDB: Redis Stack / Embeddings: nomic-embed-text (768dim)"
	echo "   tinyllama が有害な回答を生成した場合に Kong がブロック"
	echo ""
	echo "🤖 [ai-proxy + ai-semantic-cache]"
	echo "                                     POST http://localhost:8000/ai/semcache/chat"
	echo "   VectorDB: Redis Stack / Embeddings: nomic-embed-text (768dim)"
	echo "   類似質問を即座に返却 (X-Cache-Status: Hit/Miss)"
	echo ""
	echo "🤖 [ai-proxy + ai-prompt-decorator]"
	echo "                                     POST http://localhost:8000/ai/decorator/chat"
	echo "   日本語回答強制 (system prepend) + フッター付与 (user append) — クライアントから不可視"
	echo ""
	echo "🤖 [ai-proxy + ai-request-transformer]"
	echo "                                     POST http://localhost:8000/ai/reqtransform/chat"
	echo "   変換: qwen2.5:1.5b がリクエストを英語に整形してから qwen2.5:3b へ転送"
	echo ""
	echo "🤖 [ai-proxy + ai-response-transformer]"
	echo "                                     POST http://localhost:8000/ai/restransform/chat"
	echo "   変換: qwen2.5:1.5b の回答を qwen2.5:1.5b で3点の箇条書きに整形"
	echo ""
	echo "🤖 [ai-proxy-advanced]               POST http://localhost:8000/ai/advanced/chat"
	echo "   モデル: qwen2.5:1.5b / tinyllama (round-robin)"
	echo ""
	echo "🤖 [ai-proxy-advanced + ai-llm-as-judge]"
	echo "                                     POST http://localhost:8000/ai/judge/chat"
	echo "   評価: qwen2.5:1.5b / tinyllama の回答を qwen2.5:3b が 1〜100 でスコアリング"
	echo ""
	echo "🤖 [ai-mcp-proxy]                    POST http://localhost:8000/ai/mcp/sios-techlab"
	echo "   SIOS Tech Lab WordPress REST API を MCP サーバーとして公開"
	echo "   ツール: get_articles / get_article_by_id"
	echo ""
	echo "--------------------------------------------------"
}
# }}}

start_banner
main
finish_banner $S_TIME
