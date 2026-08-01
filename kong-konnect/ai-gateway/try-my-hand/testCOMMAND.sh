#!/bin/bash
# =============================================================================
# Kong AI Gateway - Interactive Test Script
# 対話形式でプロキシパターンとプロンプトを選択してリクエストを送信する
# =============================================================================

KONG_PROXY="http://localhost:8000"

# =============================================================================
# 1. プロキシパターンの選択
# =============================================================================
echo ""
echo "=================================================="
echo "  Kong AI Gateway テスト実行"
echo "=================================================="
echo ""
echo "■ プロキシパターンを選択してください:"
echo ""
echo "  [1] ai-proxy-normal     → POST ${KONG_PROXY}/ai/normal/chat"
echo "      Ollama llama3.1 へ直接プロキシ"
echo "  [2] ai-proxy-ratelimit  → POST ${KONG_PROXY}/ai/ratelimit/chat"
echo "      トークン数で流量制限 (500 tokens / 60sec / IP)"
echo "  [3] ai-prompt-guard     → POST ${KONG_PROXY}/ai/guard/chat"
echo "      PII・プロンプトインジェクション攻撃をブロック"
echo "  [4] ai-prompt-decorator → POST ${KONG_PROXY}/ai/decorator/chat"
echo "      システムプロンプトを強制付与 (関西弁)"
echo "  [5] ai-proxy-semcache   → POST ${KONG_PROXY}/ai/semcache/chat"
echo "      類似質問をセマンティックキャッシュで即返却"
echo "  [6] ai-proxy-advanced   → POST ${KONG_PROXY}/ai/advanced/chat"
echo "      llama3.1 / phi3:mini ラウンドロビン"
echo ""
read -rp "番号を入力してください [1-6]: " proxy_num

case "${proxy_num}" in
  1) ENDPOINT="${KONG_PROXY}/ai/normal/chat";    LABEL="ai-proxy-normal"     ;;
  2) ENDPOINT="${KONG_PROXY}/ai/ratelimit/chat"; LABEL="ai-proxy-ratelimit"  ;;
  3) ENDPOINT="${KONG_PROXY}/ai/guard/chat";     LABEL="ai-prompt-guard"     ;;
  4) ENDPOINT="${KONG_PROXY}/ai/decorator/chat"; LABEL="ai-prompt-decorator" ;;
  5) ENDPOINT="${KONG_PROXY}/ai/semcache/chat";  LABEL="ai-proxy-semcache"   ;;
  6) ENDPOINT="${KONG_PROXY}/ai/advanced/chat";  LABEL="ai-proxy-advanced"   ;;
  *)
    echo "❌ 無効な番号です: '${proxy_num}' (1〜6 を入力してください)"
    exit 1
    ;;
esac

echo "✅ 選択: [${proxy_num}] ${LABEL}"

# =============================================================================
# 2. プロンプト文字列の入力
# =============================================================================
DEFAULT_PROMPT="Kong AI Gatewayのメリットを3つ教えて"

echo ""
read -rp "送信するプロンプトを入力してください [Enter でデフォルト]: " user_prompt

if [ -z "${user_prompt}" ]; then
  user_prompt="${DEFAULT_PROMPT}"
  echo "   → デフォルト: \"${user_prompt}\""
fi

# JSON ペイロード生成 (jq でエスケープ処理)
PAYLOAD=$(jq -nc --arg msg "${user_prompt}" \
  '{"messages": [{"role": "user", "content": $msg}]}')

# curl コマンドを文字列変数として構築（表示・実行で共用）
CURL_CMD="curl -sv -X POST \"${ENDPOINT}\" -H \"Content-Type: application/json\" -d '${PAYLOAD}'"

# =============================================================================
# 3. curl コマンドの表示
# =============================================================================
echo ""
echo "=================================================="
echo "  実行コマンド"
echo "=================================================="
echo "${CURL_CMD}" | sed \
  -e 's/ -X / \\\n  -X /g' \
  -e 's/ -H / \\\n  -H /g' \
  -e 's/ -d / \\\n  -d /g'
echo "=================================================="

# =============================================================================
# 4. curl コマンドの実行
# =============================================================================
echo ""
echo "⏳ リクエスト送信中..."
echo ""

tmp_verbose=$(mktemp)
tmp_body=$(mktemp)
trap 'rm -f "${tmp_verbose}" "${tmp_body}"' EXIT

time eval "${CURL_CMD}" \
  -o "${tmp_body}" \
  2>"${tmp_verbose}"

echo "--- Verbose Output (Request / Response Headers) ---"
cat "${tmp_verbose}"
echo ""
echo "--- Response Body ---"
jq '.' "${tmp_body}" 2>/dev/null || cat "${tmp_body}"
echo ""

