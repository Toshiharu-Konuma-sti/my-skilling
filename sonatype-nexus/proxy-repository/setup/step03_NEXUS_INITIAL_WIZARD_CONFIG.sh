#!/bin/sh

# ==============================================================================
# Nexus 3 初期ウィザード設定スクリプト
# Description: REST API を利用して以下を設定します。
#   [同意]  テレメトリ（利用統計送信）を無効化
#           初回ログイン時のウィザードで「同意」を求められる
#           アナリティクス/テレメトリ送信を API で拒否（無効化）します。
#           ※ Nexus のバージョンによって本エンドポイントが存在しない場合は
#             警告のみ出力してスキップします。
#   [匿名]  匿名ユーザーによるアクセスを無効化
#           初回ログイン時のウィザードで問われる「匿名ユーザーを許可するか」を
#           API で「許可しない」に設定します。
# ==============================================================================

# 失敗時に即時終了
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. "${CUR_DIR}/common.sh"
. "${CUR_DIR}/custom.sh"
. "${CUR_DIR}/variables.sh"

# --- Nexus API 起動待ち ---
# $1: ベース URL  $2: ユーザー名  $3: パスワード
wait_for_nexus() {
    _base_url="$1"
    _user="$2"
    _pass="$3"
    log_info "Nexus REST API の起動を待っています... (${_base_url})"
    RETRY=0
    MAX_RETRY=24  # 最大 2 分待機
    until curl -sf -u "${_user}:${_pass}" \
            "${_base_url}/service/rest/v1/status/writable" > /dev/null 2>&1; do
        RETRY=$((RETRY + 1))
        if [ "$RETRY" -ge "$MAX_RETRY" ]; then
            log_error "Nexus REST API に接続できませんでした。"
            exit 1
        fi
        log_info "  待機中... (${RETRY}/${MAX_RETRY})"
        sleep 5
    done
    log_success "Nexus REST API が応答しています。"
}

# =============================================================================
# [同意] テレメトリ（利用統計送信）の無効化
# =============================================================================

# --- テレメトリ設定の取得 ---
# $1: ベース URL  $2: ユーザー名  $3: パスワード
# 戻り値: TELEMETRY_BODY にレスポンス JSON を設定。
#         エンドポイントが存在しない場合は空文字列を設定する。
get_telemetry_config() {
    _base_url="$1"
    _user="$2"
    _pass="$3"
    TELEMETRY_BODY=$(curl -s \
        -o /tmp/nexus_telemetry_body.txt \
        -w "%{http_code}" \
        -u "${_user}:${_pass}" \
        "${_base_url}/service/rest/v1/telemetry/configuration")
    _http_code="$TELEMETRY_BODY"
    TELEMETRY_BODY=$(cat /tmp/nexus_telemetry_body.txt)
    rm -f /tmp/nexus_telemetry_body.txt
    echo "$_http_code"
}

# --- テレメトリ（利用統計送信）の無効化 ---
# $1: ベース URL  $2: ユーザー名  $3: パスワード
# 初回ログイン時のウィザードで「同意」を求められるテレメトリ送信を無効化します。
# エンドポイントが存在しない Nexus バージョンでは警告を出してスキップします。
disable_telemetry() {
    _base_url="$1"
    _user="$2"
    _pass="$3"
    log_info "テレメトリ（利用統計送信）の設定を確認しています..."
    log_info "  エンドポイント: ${_base_url}/service/rest/v1/telemetry/configuration"

    _code=$(get_telemetry_config "$_base_url" "$_user" "$_pass")

    if [ "$_code" = "404" ] || [ "$_code" = "000" ]; then
        log_warn "テレメトリ設定エンドポイントが見つかりません。(HTTP ${_code}) スキップします。"
        log_warn "  このバージョンの Nexus では本設定項目が存在しない可能性があります。"
        return 0
    fi

    if [ "$_code" != "200" ]; then
        log_warn "テレメトリ設定の取得に失敗しました。(HTTP ${_code}) スキップします。"
        return 0
    fi

    if echo "$TELEMETRY_BODY" | grep -q '"enabled"[[:space:]]*:[[:space:]]*false'; then
        log_success "テレメトリはすでに無効です。"
        return 0
    fi

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X PUT "${_base_url}/service/rest/v1/telemetry/configuration" \
        -u "${_user}:${_pass}" \
        -H "Content-Type: application/json" \
        -d '{"enabled": false}')

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
        log_success "テレメトリを無効化しました。(HTTP ${HTTP_CODE})"
    else
        log_warn "テレメトリの無効化に失敗しました。(HTTP ${HTTP_CODE}) スキップします。"
    fi
}

# =============================================================================
# [匿名] 匿名アクセスの無効化
# =============================================================================

# --- 匿名アクセスの無効化 ---
# $1: ベース URL  $2: ユーザー名  $3: パスワード
# 初回ログイン時のウィザードで問われる「匿名ユーザーを許可するか」を
# API で「許可しない (enabled: false)」に設定します。
# エンドポイント: PUT /service/rest/v1/security/anonymous
disable_anonymous_access() {
    _base_url="$1"
    _user="$2"
    _pass="$3"
    log_info "匿名アクセスの設定を確認しています..."
    log_info "  エンドポイント: ${_base_url}/service/rest/v1/security/anonymous"

    CURRENT=$(curl -sf -u "${_user}:${_pass}" \
        "${_base_url}/service/rest/v1/security/anonymous")

    if echo "$CURRENT" | grep -q '"enabled"[[:space:]]*:[[:space:]]*false'; then
        log_success "匿名アクセスはすでに無効です。"
        return 0
    fi

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X PUT "${_base_url}/service/rest/v1/security/anonymous" \
        -u "${_user}:${_pass}" \
        -H "Content-Type: application/json" \
        -d '{"enabled": false, "userId": "anonymous", "realmName": "NexusAuthorizingRealm"}')

    if [ "$HTTP_CODE" = "200" ]; then
        log_success "匿名アクセスを無効化しました。(HTTP ${HTTP_CODE})"
    else
        log_error "匿名アクセスの無効化に失敗しました。(HTTP ${HTTP_CODE})"
        exit 1
    fi
}

# =============================================================================
# メイン
# =============================================================================
main() {
    start_banner
    check_required_commands curl
    log_info "=== Nexus 初期ウィザード設定 ==="
    log_info "対象 Nexus: ${NEXUS_URL}"

    wait_for_nexus "$NEXUS_URL" "$NEXUS_USER" "$NEXUS_PASS"

    log_info ""
    log_info "--- [同意] テレメトリ（利用統計送信）---"
    disable_telemetry "$NEXUS_URL" "$NEXUS_USER" "$NEXUS_PASS"

    log_info ""
    log_info "--- [匿名] 匿名アクセス ---"
    disable_anonymous_access "$NEXUS_URL" "$NEXUS_USER" "$NEXUS_PASS"

    log_info ""
    log_success "初期ウィザード設定が完了しました！"
    log_info "Nexus 管理画面: ${NEXUS_URL}  (admin / ${NEXUS_PASS})"

    finish_banner "$S_TIME"
}

main "$@"
