#!/bin/sh

# ==============================================================================
# GitLab Runner 登録スクリプト
# Description: GitLab REST API を利用して以下を行います。
#              1. グループ ID を取得します。
#              2. グループ用 Runner 認証トークンを発行します。
#              3. gitlab-runner コンテナに Runner を登録します。
#                 - executor  : docker
#                 - network   : hands-net（CI ジョブから Nexus ・インターネットの両方に到達可）
#              4. gitlab-runner コンテナを再起動して設定を反映します。
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

# --- グループ ID 取得 ---
# $1: GitLab ベース URL  $2: アクセストークン  $3: グループパス
# 戻り値: GL_GROUP_ID にグループ ID を設定する
get_group_id() {
    _base_url="$1"
    _token="$2"
    _group_path="$3"

    log_info "グループ '${_group_path}' の ID を取得しています..."

    GL_GROUP_ID=$(gitlab_curl_with_retry \
        -H "Authorization: Bearer ${_token}" \
        "${_base_url}/api/v4/groups/${_group_path}" \
        | jq -r '.id // empty' 2>/dev/null) || GL_GROUP_ID=""

    if [ -z "$GL_GROUP_ID" ]; then
        log_error "グループ '${_group_path}' が見つかりません。step02 を先に実行してください。"
        exit 1
    fi
    log_success "グループ ID: ${GL_GROUP_ID}"
}

# --- 既存グループ Runner の削除（同 description のものを対象） ---
# $1: GitLab ベース URL  $2: アクセストークン  $3: グループ ID  $4: Runner の description
cleanup_existing_runners() {
    _base_url="$1"
    _token="$2"
    _group_id="$3"
    _description="$4"

    log_info "既存の Runner（description='${_description}'）を確認しています..."

    RUNNER_IDS=$(gitlab_curl_with_retry \
        -H "Authorization: Bearer ${_token}" \
        "${_base_url}/api/v4/groups/${_group_id}/runners?per_page=100" \
        | jq -r --arg desc "${_description}" \
          '[.[] | select(.description == $desc) | .id | tostring] | join(" ")' \
        2>/dev/null) || RUNNER_IDS=""

    if [ -z "$RUNNER_IDS" ]; then
        log_info "  削除対象の既存 Runner はありません。"
        return 0
    fi

    for _id in $RUNNER_IDS; do
        log_info "  Runner ID ${_id} を削除しています..."
        gitlab_curl_with_retry -X DELETE \
            -H "Authorization: Bearer ${_token}" \
            "${_base_url}/api/v4/runners/${_id}" > /dev/null
        log_success "  Runner ID ${_id} を削除しました。"
    done
}

# --- グループ Runner 認証トークン発行 ---
# $1: GitLab ベース URL  $2: アクセストークン  $3: グループ ID
# 戻り値: RUNNER_TOKEN に Runner 認証トークンを設定する
create_runner_token() {
    _base_url="$1"
    _token="$2"
    _group_id="$3"

    log_info "グループ Runner トークンを発行しています..."

    RESPONSE=$(gitlab_curl_with_retry \
        -X POST \
        -H "Authorization: Bearer ${_token}" \
        -H "Content-Type: application/json" \
        -d "{
              \"runner_type\"  : \"group_type\",
              \"group_id\"     : ${_group_id},
              \"description\"  : \"docker-runner\",
              \"run_untagged\" : true,
              \"locked\"       : false,
              \"access_level\" : \"not_protected\"
            }" \
        "${_base_url}/api/v4/user/runners")

    RUNNER_TOKEN=$(echo "$RESPONSE" | jq -r '.token // empty' 2>/dev/null) || RUNNER_TOKEN=""

    if [ -z "$RUNNER_TOKEN" ]; then
        log_error "Runner トークンの発行に失敗しました。"
        exit 1
    fi
    log_success "Runner トークンを発行しました。"
}

# --- Runner 登録 ---
# $1: Runner コンテナ名  $2: GitLab 内部 URL（コンテナ間通信用）  $3: Runner 認証トークン
register_runner() {
    _runner_container="$1"
    _gitlab_internal_url="$2"
    _runner_token="$3"

    log_info "既存の config.toml をクリアしています..."
    docker exec "$_runner_container" sh -c '> /etc/gitlab-runner/config.toml'

    log_info "Runner を登録しています..."
    # --docker-network-mode hands-net:
    #   CI ジョブコンテナを hands-net に接続する。
    #   hands-net は外部ネットワークなのでインターネットに直接アクセス可能。
    #   Nexus ・ GitLab は両方 hands-net に所属しているためコンテナ名で到達できる。
    docker exec "$_runner_container" gitlab-runner register \
        --non-interactive \
        --url             "$_gitlab_internal_url" \
        --clone-url       "$_gitlab_internal_url" \
        --token           "$_runner_token" \
        --executor        "docker" \
        --docker-image    "alpine:latest" \
        --description     "docker-runner" \
        --docker-network-mode "hands-net"

    log_success "Runner の登録が完了しました。"
    log_info "--- 登録後の config.toml ---"
    docker exec "$_runner_container" cat /etc/gitlab-runner/config.toml
    log_info "----------------------------"
}

# --- gitlab-runner 再起動 ---
# $1: Runner コンテナ名
restart_runner() {
    _runner_container="$1"
    log_info "gitlab-runner を再起動して設定を反映しています..."
    docker restart "$_runner_container" > /dev/null
    log_success "gitlab-runner を再起動しました。"
}

# =============================================================================
# メイン
# =============================================================================
main() {
    start_banner
    check_required_commands curl jq docker
    log_info "=== GitLab Runner 登録 ==="
    log_info "対象 GitLab        : ${GITLAB_URL}"
    log_info "GitLab 内部 URL    : ${GITLAB_INTERNAL_URL}"
    log_info "Runner コンテナ    : ${GITLAB_RUNNER_CONTAINER}"
    log_info "グループ           : ${GITLAB_GROUP_PATH}"

    gitlab_check_container   "$GITLAB_CONTAINER"
    gitlab_check_container   "$GITLAB_RUNNER_CONTAINER"
    gitlab_wait_for_api      "$GITLAB_URL"
    gitlab_get_root_password "$GITLAB_CONTAINER"
    gitlab_get_access_token  "$GITLAB_URL" "$GITLAB_USER" "$GL_ROOT_PASS"

    get_group_id        "$GITLAB_URL" "$GL_ACCESS_TOKEN" "$GITLAB_GROUP_PATH"
    cleanup_existing_runners "$GITLAB_URL" "$GL_ACCESS_TOKEN" "$GL_GROUP_ID" "docker-runner"
    create_runner_token "$GITLAB_URL" "$GL_ACCESS_TOKEN" "$GL_GROUP_ID"
    register_runner   "$GITLAB_RUNNER_CONTAINER" "$GITLAB_INTERNAL_URL" "$RUNNER_TOKEN"
    restart_runner    "$GITLAB_RUNNER_CONTAINER"

    log_info ""
    log_success "完了！"
    log_info "GitLab: ${GITLAB_URL}/admin/runners"

    finish_banner "$S_TIME"
}

main "$@"
