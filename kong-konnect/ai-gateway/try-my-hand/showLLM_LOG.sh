#!/bin/bash
# =============================================================================
# Kong AI Gateway - LLM プロンプト確認スクリプト
# kong-dp コンテナログから file-log プラグインの JSON を抽出・整形して表示する
#
# Usage:
#   ./showLLM_LOG.sh         # 直近1件を表示
#   ./showLLM_LOG.sh 3       # 直近3件を表示
#   ./showLLM_LOG.sh --all   # 全件を表示
# =============================================================================

CONTAINER="kong-dp"
ARG="${1:-1}"

# =============================================================================
# JSON ログ行の抽出
#   file-log plugin の出力は行頭が { の行
#   docker logs の stderr も拾うため 2>&1 でマージ
# =============================================================================
if [[ "${ARG}" == "--all" ]]; then
  LOGS=$(docker logs "${CONTAINER}" 2>&1 | grep -E '^\{')
else
  LOGS=$(docker logs "${CONTAINER}" 2>&1 | grep -E '^\{' | tail -n "${ARG}")
fi

if [[ -z "${LOGS}" ]]; then
  echo "❌ ログが見つかりません。"
  echo "   ・コンテナ '${CONTAINER}' が起動しているか確認してください。"
  echo "   ・file-log plugin が有効になっているか確認してください。"
  exit 1
fi

COUNT=$(echo "${LOGS}" | wc -l)
echo ""
echo "=================================================="
echo "  LLM プロンプトログ (${COUNT} 件)"
echo "  コンテナ: ${CONTAINER}"
echo "=================================================="

i=1
echo "${LOGS}" | while IFS= read -r line; do
  echo ""
  echo "──────────────────────────────────────────────────"
  echo "  [${i}/${COUNT}]"
  echo "──────────────────────────────────────────────────"

  # ペイロードが文字列 (fromjson) かどうかを確認してから変換
  REQUEST_RAW=$(echo "${line}" | jq -r '.ai.proxy.payload.request // empty')
  RESPONSE_RAW=$(echo "${line}" | jq -r '.ai.proxy.payload.response // empty')

  echo "${line}" | jq --argjson req "$(echo "${REQUEST_RAW}" | jq '.' 2>/dev/null || echo 'null')" \
                      --argjson res "$(echo "${RESPONSE_RAW}" | jq '.' 2>/dev/null || echo 'null')" \
  '{
    "■ エンドポイント":    .request.uri,
    "■ リクエストID":      .request.id,
    "■ 日時":              (.started_at / 1000 | todate),
    "■ モデル": {
      "provider":          .ai.proxy.meta.provider_name,
      "model":             .ai.proxy.meta.request_model
    },
    "■ レイテンシ (ms)": {
      "llm_latency":       .ai.proxy.meta.llm_latency,
      "kong_latency":      .latencies.kong,
      "total_request":     .latencies.request
    },
    "■ トークン使用量": {
      "prompt_tokens":     .ai.proxy.usage.prompt_tokens,
      "completion_tokens": .ai.proxy.usage.completion_tokens,
      "total_tokens":      .ai.proxy.usage.total_tokens
    },
    "■ 送信プロンプト":    $req,
    "■ LLM レスポンス":    $res
  }'

  i=$((i + 1))
done

echo ""
echo "=================================================="
echo "  完了"
echo "=================================================="
echo ""
