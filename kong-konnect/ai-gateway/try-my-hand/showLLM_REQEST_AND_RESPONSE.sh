#!/bin/bash
# =============================================================================
# Kong AI Gateway - LLM リクエスト/レスポンス表示スクリプト
# kong-dp コンテナログから file-log プラグインの JSON を抽出・整形して表示する
# 表示内容: LLM への送信メッセージ・レスポンス・トークン使用量・評価スコアなど
#
# Usage:
#   ./showLLM_REQEST_AND_RESPONSE.sh         # 直近1件を表示
#   ./showLLM_REQEST_AND_RESPONSE.sh 3       # 直近3件を表示
#   ./showLLM_REQEST_AND_RESPONSE.sh --all   # 全件を表示
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

# JSON として解釈できない値 (プレーンテキスト等) を JSON 文字列として安全に変換する
safe_json() {
  local raw="$1"
  [ -z "${raw}" ] && echo 'null' && return
  if echo "${raw}" | jq '.' >/dev/null 2>&1; then
    echo "${raw}" | jq '.'
  else
    echo "${raw}" | jq -Rs '.'
  fi
}

i=1
echo "${LOGS}" | while IFS= read -r line; do
  echo ""
  echo "──────────────────────────────────────────────────"
  echo "  [${i}/${COUNT}]"
  echo "──────────────────────────────────────────────────"

  # ペイロードが文字列 (fromjson) かどうかを確認してから変換
  REQUEST_RAW=$(echo "${line}" | jq -r '.ai.proxy.payload.request // empty')
  RESPONSE_RAW=$(echo "${line}" | jq -r '.ai.proxy.payload.response // empty')
  # Kong がブロックした場合の判定用: upstream=LLM側, response=クライアント側
  UPSTREAM_STATUS=$(echo "${line}" | jq -r '.upstream_status // empty')
  RESPONSE_STATUS=$(echo "${line}" | jq -r '.response.status // empty')

  echo "${line}" | jq --argjson req "$(safe_json "${REQUEST_RAW}")" \
                      --argjson res "$(safe_json "${RESPONSE_RAW}")" \
                      --argjson ups "${UPSTREAM_STATUS:-null}" \
                      --argjson rsp "${RESPONSE_STATUS:-null}" \
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
    "■ LLM 評価スコア":    (.ai.proxy.usage.llm_accuracy // "(対象外)"),
    "■ HTTP ステータス": {
      "upstream (LLM→Kong)":  $ups,
      "response (Kong→client)": $rsp
    },
    "■ 送信プロンプト":    $req,
    "■ LLM レスポンス":    (
      if $res != null then $res
      elif ($ups == 200 and $rsp != null and $rsp >= 400)
        then ("LLM は HTTP " + ($ups | tostring) + " で回答済み / Kong が " + ($rsp | tostring) + " でブロック（回答本文はログ未記録）")
      else "(ログ未記録 — プレーンテキスト変換後のレスポンスは testAI_GATEWAY.sh の出力を参照)"
      end
    )
  }'

  i=$((i + 1))
done

echo ""
echo "=================================================="
echo "  完了"
echo "=================================================="
echo ""
