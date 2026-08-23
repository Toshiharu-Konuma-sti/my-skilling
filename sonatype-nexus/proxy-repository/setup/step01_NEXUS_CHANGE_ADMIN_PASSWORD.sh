#!/bin/sh

# ==============================================================================
# Nexus 3 admin パスワード変更スクリプト
# Description: Nexus 初回起動時に生成されるランダムな初期パスワードを読み取り、
#              REST API 経由で指定のパスワードに変更します。
#              初期パスワードファイル: /nexus-data/admin.password (コンテナ内)
#              ※ パスワード変更後は上記ファイルが自動削除されます
# ==============================================================================

# 失敗時に即時終了
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. "${CUR_DIR}/common.sh"
. "${CUR_DIR}/custom.sh"
. "${CUR_DIR}/variables.sh"

# --- コンテナ起動確認 ---
# $1: コンテナ名
check_container() {
    _container="$1"
    log_info "コンテナ '${_container}' の起動を確認しています..."
    if ! docker ps --filter "name=^${_container}$" --filter "status=running" \
            --format "{{.Names}}" | grep -q "^${_container}$"; then
        log_error "コンテナ '${_container}' が起動していません。"
        log_info "実行例: docker compose -f ../container/docker-compose.yml up -d"
        exit 1
    fi
    log_success "コンテナが起動しています。"
}

# --- Nexus API 起動待ち ---
# $1: Nexus ベース URL
wait_for_nexus() {
    _base_url="$1"
    log_info "Nexus REST API の起動を待っています... (${_base_url})"
    RETRY=0
    MAX_RETRY=24  # 最大 2 分待機
    until curl -sf "${_base_url}/service/rest/v1/status" > /dev/null 2>&1; do
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

# --- 初期パスワードの取得 ---
# $1: コンテナ名  $2: パスワードファイルパス  $3: ユーザー名  $4: 変更後パスワード  $5: ベース URL
# 戻り値: INIT_PASS に初期パスワードを設定する
get_initial_password() {
    _container="$1"
    _pass_file="$2"
    _nexus_user="$3"
    _nexus_pass="$4"
    _base_url="$5"
    log_info "初期パスワードファイルを確認しています (${_pass_file})..."

    # ファイルが存在するか確認
    if ! docker exec "${_container}" test -f "${_pass_file}" 2>/dev/null; then
        log_warn "初期パスワードファイルが見つかりません。"
        log_warn "すでにパスワード変更済みの可能性があります。"
        log_info "現在のパスワードで '${_nexus_pass}' にアクセスできるか確認します..."

        if curl -sf -u "${_nexus_user}:${_nexus_pass}" \
                "${_base_url}/service/rest/v1/status/writable" > /dev/null 2>&1; then
            log_success "パスワードはすでに '${_nexus_pass}' に設定されています。スキップします。"
            exit 0
        else
            log_error "初期パスワードファイルがなく、指定パスワードでも認証できませんでした。"
            log_info "パスワードを手動で確認してください。"
            exit 1
        fi
    fi

    INIT_PASS=$(docker exec "${_container}" cat "${_pass_file}")
    log_success "初期パスワードを取得しました。"
}

# --- パスワード変更 ---
# $1: ユーザー名  $2: 初期パスワード  $3: 変更後パスワード  $4: ベース URL
change_password() {
    _nexus_user="$1"
    _init_pass="$2"
    _nexus_pass="$3"
    _base_url="$4"
    log_info "パスワードを変更しています (${_nexus_user} → ${_nexus_pass})..."

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X PUT \
        -u "${_nexus_user}:${_init_pass}" \
        -H "Content-Type: text/plain" \
        -d "${_nexus_pass}" \
        "${_base_url}/service/rest/v1/security/users/${_nexus_user}/change-password")

    if [ "$HTTP_CODE" = "204" ]; then
        log_success "パスワードを '${_nexus_pass}' に変更しました。(HTTP ${HTTP_CODE})"
    else
        log_error "パスワード変更に失敗しました。(HTTP ${HTTP_CODE})"
        log_info "初期パスワードが正しいか、Nexus の初期化が完了しているか確認してください。"
        exit 1
    fi
}

# --- 変更後の認証確認 ---
# $1: ユーザー名  $2: 新パスワード  $3: ベース URL
verify_new_password() {
    _nexus_user="$1"
    _nexus_pass="$2"
    _base_url="$3"
    log_info "新しいパスワードで認証確認しています..."
    if curl -sf -u "${_nexus_user}:${_nexus_pass}" \
            "${_base_url}/service/rest/v1/status/writable" > /dev/null 2>&1; then
        log_success "新しいパスワードで認証できました。"
    else
        log_error "新しいパスワードでの認証に失敗しました。"
        exit 1
    fi
}

# --- メイン ---
main() {

	call_show_start_banner

    check_required_commands docker curl
    log_info "=== Nexus admin パスワード変更 ==="
    log_info "対象コンテナ : ${NEXUS_CONTAINER}"
    log_info "対象 Nexus   : ${NEXUS_URL}"
    log_info "変更後パスワード: ${NEXUS_PASS}"

    check_container    "$NEXUS_CONTAINER"
    wait_for_nexus     "$NEXUS_URL"
    get_initial_password "$NEXUS_CONTAINER" "$NEXUS_INIT_PASS_FILE" "$NEXUS_USER" "$NEXUS_PASS" "$NEXUS_URL"
    change_password    "$NEXUS_USER" "$INIT_PASS" "$NEXUS_PASS" "$NEXUS_URL"
    verify_new_password "$NEXUS_USER" "$NEXUS_PASS" "$NEXUS_URL"

    log_info ""
    log_success "セットアップ完了！"
    log_info "Nexus 管理画面: ${NEXUS_URL}  (admin / ${NEXUS_PASS})"

	call_show_finish_banner
}

main "$@"
