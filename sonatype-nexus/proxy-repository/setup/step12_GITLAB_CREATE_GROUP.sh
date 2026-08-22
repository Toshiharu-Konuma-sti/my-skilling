#!/bin/sh

# ==============================================================================
# GitLab グループ作成スクリプト
# Description: GitLab REST API を利用して以下を行います。
#              1. グループ (my-hands-on-group) を作成します。
#              2. 既存プロジェクトをグループへ移管します。
#              3. グループ CI/CD Variables に Nexus 接続情報を登録します。
#              ※ GitLab が重い環境では API が 500 を返すことがあるため
#                 gitlab_curl_with_retry を使用して安定させています。
# ==============================================================================

# 失敗時に即時終了
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh
. $CUR_DIR/variables.sh

# =============================================================================
# サブルーチン
# =============================================================================

# --- グループの作成 ---
# $1: GitLab ベース URL  $2: アクセストークン  $3: グループパス  $4: グループ表示名
# 戻り値: GL_GROUP_ID にグループ ID を設定する
create_group() {
    _base_url="$1"
    _token="$2"
    _group_path="$3"
    _group_name="$4"

    log_info "グループ '${_group_path}' を作成・確認しています..."

    # GET: 既存グループ確認（高負荷で 404 が返ることがあるため後続でフォールバックあり）
    _resp=$(gitlab_curl_with_retry \
        -H "Authorization: Bearer ${_token}" \
        "${_base_url}/api/v4/groups/${_group_path}") || _resp=""
    GL_GROUP_ID=$(echo "$_resp" | jq -r '.id // empty' 2>/dev/null) || GL_GROUP_ID=""

    if [ -n "$GL_GROUP_ID" ]; then
        log_warn "グループ '${_group_path}' はすでに存在します。スキップします。"
        log_info "  URL: ${_base_url}/${_group_path}  (ID: ${GL_GROUP_ID})"
        return 0
    fi

    # GET でIDが取れなかった場合 → POST で新規作成を試みる
    log_info "  グループが見つからないため新規作成を試みます..."
    _resp=$(gitlab_curl_with_retry \
        -X POST \
        -H "Authorization: Bearer ${_token}" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"${_group_name}\",\"path\":\"${_group_path}\",\"visibility\":\"private\"}" \
        "${_base_url}/api/v4/groups") || _resp=""
    GL_GROUP_ID=$(echo "$_resp" | jq -r '.id // empty' 2>/dev/null) || GL_GROUP_ID=""

    if [ -n "$GL_GROUP_ID" ]; then
        log_success "グループ '${_group_path}' を作成しました。"
        log_info "  URL: ${_base_url}/${_group_path}  (ID: ${GL_GROUP_ID})"
        return 0
    fi

    # POST が "already been taken" エラー
    # → GETが高負荷で 404 を返していた可能性あり → 少し待って GET を再試行
    _err=$(echo "$_resp" | jq -r '.message // empty' 2>/dev/null) || _err=""
    if echo "$_err" | grep -q "already been taken"; then
        log_warn "  GET が不安定でグループを見落としていました。3秒後に ID を再取得します..."
        sleep 3
        _resp=$(gitlab_curl_with_retry \
            -H "Authorization: Bearer ${_token}" \
            "${_base_url}/api/v4/groups/${_group_path}") || _resp=""
        GL_GROUP_ID=$(echo "$_resp" | jq -r '.id // empty' 2>/dev/null) || GL_GROUP_ID=""
        if [ -n "$GL_GROUP_ID" ]; then
            log_warn "グループ '${_group_path}' はすでに存在します。スキップします。"
            log_info "  URL: ${_base_url}/${_group_path}  (ID: ${GL_GROUP_ID})"
            return 0
        fi
    fi

    log_error "グループの作成に失敗しました。"
    log_error "  レスポンス: ${_resp}"
    exit 1
}

# --- プロジェクトをグループへ移管 ---
# $1: GitLab ベース URL  $2: アクセストークン
# $3: 現在のオーナー名  $4: プロジェクト名  $5: 移管先グループ ID
transfer_project() {
    _base_url="$1"
    _token="$2"
    _owner="$3"
    _project="$4"
    _group_id="$5"

    log_info "プロジェクト '${_project}' をグループへ移管しています..."

    # ① オーナー名前空間でプロジェクトを検索
    _enc_owner=$(echo "${_owner}/${_project}" | sed 's|/|%2F|g')
    PROJECT_INFO=$(gitlab_curl_with_retry \
        -H "Authorization: Bearer ${_token}" \
        "${_base_url}/api/v4/projects/${_enc_owner}") || PROJECT_INFO=""

    PROJECT_ID=$(echo "$PROJECT_INFO" | jq -r '.id // empty' 2>/dev/null) || PROJECT_ID=""

    # ② オーナー名前空間で見つからない場合はグループ名前空間でも検索
    if [ -z "$PROJECT_ID" ]; then
        _enc_group=$(echo "${GITLAB_GROUP_PATH}/${_project}" | sed 's|/|%2F|g')
        PROJECT_INFO=$(gitlab_curl_with_retry \
            -H "Authorization: Bearer ${_token}" \
            "${_base_url}/api/v4/projects/${_enc_group}") || PROJECT_INFO=""
        PROJECT_ID=$(echo "$PROJECT_INFO" | jq -r '.id // empty' 2>/dev/null) || PROJECT_ID=""
    fi

    if [ -z "$PROJECT_ID" ]; then
        log_warn "プロジェクト '${_project}' がどの名前空間でも見つかりません。スキップします。"
        return 0
    fi

    # すでにグループ配下にあるか確認
    CURRENT_NS=$(echo "$PROJECT_INFO" | jq -r '.namespace.path // empty' 2>/dev/null) || CURRENT_NS=""
    if [ "$CURRENT_NS" = "${GITLAB_GROUP_PATH}" ]; then
        log_warn "プロジェクト '${_project}' はすでにグループ '${GITLAB_GROUP_PATH}' 配下にあります。スキップします。"
        return 0
    fi

    RESULT=$(gitlab_curl_with_retry \
        -X PUT \
        -H "Authorization: Bearer ${_token}" \
        "${_base_url}/api/v4/projects/${PROJECT_ID}/transfer?namespace=${_group_id}") || RESULT=""

    NEW_PATH=$(echo "$RESULT" | jq -r '.path_with_namespace // empty' 2>/dev/null) || NEW_PATH=""

    if [ -n "$NEW_PATH" ]; then
        log_success "プロジェクト '${_project}' を移管しました。"
        log_info "  新パス: ${_base_url}/${NEW_PATH}"
    else
        log_error "プロジェクト '${_project}' の移管に失敗しました。レスポンス: ${RESULT}"
        exit 1
    fi
}

# --- グループ CI/CD Variable を設定 ---
# $1: GitLab ベース URL  $2: アクセストークン  $3: グループ ID
# $4: 変数キー  $5: 変数値  $6: マスク (true|false)
set_group_cicd_variable() {
    _base_url="$1"
    _token="$2"
    _group_id="$3"
    _key="$4"
    _value="$5"
    _masked="$6"

    log_info "グループ CI/CD Variable '${_key}' を設定しています..."

    # 既存変数を削除（存在しない場合の 404 は無視）
    gitlab_curl_with_retry \
        -X DELETE \
        -H "Authorization: Bearer ${_token}" \
        "${_base_url}/api/v4/groups/${_group_id}/variables/${_key}" > /dev/null 2>&1 || true

    # POST で再作成（500 の場合はリトライ）
    RESULT=$(gitlab_curl_with_retry \
        -X POST \
        -H "Authorization: Bearer ${_token}" \
        -H "Content-Type: application/json" \
        -d "{\"key\":\"${_key}\",\"value\":\"${_value}\",\"masked\":${_masked},\"protected\":false}" \
        "${_base_url}/api/v4/groups/${_group_id}/variables") || RESULT=""

    RESULT_KEY=$(echo "$RESULT" | jq -r '.key // empty' 2>/dev/null) || RESULT_KEY=""

    if [ -n "$RESULT_KEY" ]; then
        log_success "  '${_key}' を設定しました。(masked: ${_masked})"
    else
        log_error "  '${_key}' の設定に失敗しました。レスポンス: ${RESULT}"
        exit 1
    fi
}

# --- CI publish 用 Personal Access Token を作成 ---
# $1: GitLab ベース URL  $2: アクセストークン
# 成功時: GL_PUBLISH_TOKEN に PAT 値を設定する
create_publish_token() {
    _base_url="$1"
    _token="$2"

    log_info "CI publish 用 Personal Access Token を作成しています..."

    _user_id=$(gitlab_curl_with_retry \
        -H "Authorization: Bearer ${_token}" \
        "${_base_url}/api/v4/user" \
        | jq -r '.id // empty' 2>/dev/null) || _user_id=""

    if [ -z "$_user_id" ]; then
        log_error "ユーザー ID の取得に失敗しました。"
        exit 1
    fi

	EXPIRES=$(date -d '+1 year - 1 day' +%Y-%m-%d)
	log_info "expires = ${EXPIRES}"
    RESPONSE=$(gitlab_curl_with_retry \
        -X POST \
        -H "Authorization: Bearer ${_token}" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"ci-publish\",\"scopes\":[\"write_repository\"],\"expires_at\":\"${EXPIRES}\"}" \
        "${_base_url}/api/v4/users/${_user_id}/personal_access_tokens") || RESPONSE=""

    GL_PUBLISH_TOKEN=$(echo "$RESPONSE" | jq -r '.token // empty' 2>/dev/null) || GL_PUBLISH_TOKEN=""

    if [ -n "$GL_PUBLISH_TOKEN" ]; then
        log_success "PAT 'ci-publish' を作成しました。"
    else
        log_error "PAT の作成に失敗しました。レスポンス: ${RESPONSE}"
        exit 1
    fi
}

# =============================================================================
# メイン
# =============================================================================
main() {
    start_banner
    check_required_commands curl jq docker
    log_info "=== GitLab グループ作成 ==="
    log_info "対象 GitLab      : ${GITLAB_URL}"
    log_info "グループ         : ${GITLAB_GROUP_PATH} (${GITLAB_GROUP_NAME})"
    log_info "移管プロジェクト : ${GITLAB_PROJECTS}"

    gitlab_check_container   "$GITLAB_CONTAINER"
    gitlab_wait_for_api      "$GITLAB_URL"
    gitlab_get_root_password "$GITLAB_CONTAINER"
    gitlab_get_access_token  "$GITLAB_URL" "$GITLAB_USER" "$GL_ROOT_PASS"

    # グループ作成
    create_group "$GITLAB_URL" "$GL_ACCESS_TOKEN" "$GITLAB_GROUP_PATH" "$GITLAB_GROUP_NAME"

    # プロジェクト移管
    log_info ""
    log_info "--- プロジェクト移管 ---"
    for PROJECT in $GITLAB_PROJECTS; do
        transfer_project "$GITLAB_URL" "$GL_ACCESS_TOKEN" \
                         "$GITLAB_USER" "$PROJECT" "$GL_GROUP_ID"
    done

    # グループ CI/CD Variables（Nexus 接続情報を全プロジェクトに共有）
    log_info ""
    log_info "--- グループ CI/CD Variables 設定 ---"
    set_group_cicd_variable "$GITLAB_URL" "$GL_ACCESS_TOKEN" "$GL_GROUP_ID" \
        "NEXUS_URL"  "$NEXUS_CONTAINER_URL" "false"
    set_group_cicd_variable "$GITLAB_URL" "$GL_ACCESS_TOKEN" "$GL_GROUP_ID" \
        "NEXUS_USER" "$NEXUS_USER"          "false"
    set_group_cicd_variable "$GITLAB_URL" "$GL_ACCESS_TOKEN" "$GL_GROUP_ID" \
        "NEXUS_PASS" "$NEXUS_PASS"          "true"

    # PAT を作成して GITLAB_TOKEN として登録（go-modules publish ステージで git tag push に使用）
    log_info ""
    log_info "--- CI publish 用 PAT 作成 ---"
    create_publish_token "$GITLAB_URL" "$GL_ACCESS_TOKEN"
    set_group_cicd_variable "$GITLAB_URL" "$GL_ACCESS_TOKEN" "$GL_GROUP_ID" \
        "GITLAB_TOKEN" "$GL_PUBLISH_TOKEN" "true"

    log_info ""
    log_success "完了！"
    log_info "GitLab グループ: ${GITLAB_URL}/${GITLAB_GROUP_PATH}"

    finish_banner "$S_TIME"
}

main "$@"
