#!/bin/bash
# =============================================================================
# Kong AI Gateway - MCP Inspector 起動スクリプト
# SIOS Tech Lab MCP サーバーをブラウザで操作できる MCP Inspector を起動する
#
# 起動後の手順:
#   1. 表示された URL をブラウザで開く
#      例) http://localhost:6274?MCP_PROXY_AUTH_TOKEN=xxxx
#   2. 画面上の [Connect] ボタンをクリックしてサーバーに接続する
#   3. [Tools] タブからツールを選択して実行する
#      - get-articles       : 最新記事一覧の取得（キーワード検索・件数指定可）
#      - get-article-by-id  : 記事 ID を指定して詳細取得
#
# Usage:
#   ./showMCP_INSPECTOR.sh          # デフォルト: SIOS Tech Lab MCP サーバー
#   ./showMCP_INSPECTOR.sh --port 6300  # Inspector のポートを変更する場合
# =============================================================================

KONG_PROXY="http://localhost:8000"
MCP_ENDPOINT="${KONG_PROXY}/ai/mcp/sios-techlab"
INSPECTOR_PORT="${CLIENT_PORT:-6274}"

# --- オプション解析 ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      INSPECTOR_PORT="$2"
      shift 2
      ;;
    *)
      echo "❌ 不明なオプション: $1"
      echo "Usage: $0 [--port <port>]"
      exit 1
      ;;
  esac
done

# --- Kong DP 疎通確認 ---
echo ""
echo "=================================================="
echo "  MCP Inspector 起動"
echo "=================================================="
echo ""
echo "⏳ Kong Data Plane への疎通を確認中 ..."

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
  -X POST "${MCP_ENDPOINT}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"health-check","version":"0"}}}' \
  2>/dev/null)

if [[ "${HTTP_STATUS}" != "200" ]]; then
  echo "❌ MCP サーバーに接続できません (HTTP ${HTTP_STATUS})"
  echo "   以下を確認してください:"
  echo "   - Kong DP コンテナが起動しているか: docker ps | grep kong-dp"
  echo "   - Kong Konnect の設定が適用されているか: cd setup/ && ./step01_KONG_REGISTER_AI.sh"
  exit 1
fi

echo "   ✅ MCP サーバー応答確認 (HTTP ${HTTP_STATUS})"
echo ""
echo "  MCP サーバー : ${MCP_ENDPOINT}"
echo "  Transport    : Streamable HTTP"
echo "  利用ツール:"
echo "    - get-articles      : 記事一覧取得（search / per_page / categories 指定可）"
echo "    - get-article-by-id : 記事詳細取得（id 指定必須）"
echo ""
echo "=================================================="
echo ""

# --- npx コマンド確認 ---
if ! command -v npx &>/dev/null; then
  echo "❌ npx が見つかりません。Node.js をインストールしてください。"
  echo "   参考: https://nodejs.org/"
  exit 1
fi

echo "🚀 MCP Inspector を起動します ..."
echo ""
echo "  ブラウザで以下の URL を開いてください:"
echo "  http://localhost:${INSPECTOR_PORT}"
echo ""
echo "  接続後、[Connect] ボタンをクリックしてツールを操作できます。"
echo "  (終了するには Ctrl+C を押してください)"
echo ""

# --- MCP Inspector 起動 ---
CLIENT_PORT="${INSPECTOR_PORT}" \
  npx -y @modelcontextprotocol/inspector \
    --server-url "${MCP_ENDPOINT}" \
    --transport http
