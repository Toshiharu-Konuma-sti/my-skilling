#!/bin/sh

# ==============================================================================
# GitLab リポジトリ作成スクリプト
# Description: GitLab REST API を利用して空のプロジェクト（リポジトリ）を作成します。
#              初期パスワードをコンテナから読み取り、OAuth2 パスワードグラントで
#              アクセストークンを取得してからプロジェクトを作成します。
#              作成後、各プロジェクトの main ブランチに保護設定（直接 push 禁止・MR 経由のみ）を付与します。
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

# --- プロジェクトの作成 ---
# $1: GitLab ベース URL  $2: アクセストークン  $3: プロジェクト名
create_project() {
    _base_url="$1"
    _token="$2"
    _project_name="$3"

    log_info "プロジェクト '${_project_name}' を作成しています..."

    # 既存プロジェクトの確認
    EXISTING=$(gitlab_curl_with_retry \
        -H "Authorization: Bearer ${_token}" \
        "${_base_url}/api/v4/projects?search=${_project_name}" \
        | jq -r --arg name "${_project_name}" \
          '.[] | select(.name == $name) | (.id | tostring) + " " + .web_url' \
        2>/dev/null | head -1) || EXISTING=""

    if [ -n "$EXISTING" ]; then
        GL_PROJECT_ID=$(echo "$EXISTING" | cut -d' ' -f1)
        EXISTING_URL=$(echo "$EXISTING" | cut -d' ' -f2-)
        log_warn "プロジェクト '${_project_name}' はすでに存在します。スキップします。"
        log_info "  URL: ${EXISTING_URL}"
        return 0
    fi

    # プロジェクト作成（initialize_with_readme=true でREADME.md付きリポジトリ）
    RESPONSE=$(gitlab_curl_with_retry \
        -X POST \
        -H "Authorization: Bearer ${_token}" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"${_project_name}\", \"initialize_with_readme\": true}" \
        "${_base_url}/api/v4/projects")

    GL_PROJECT_ID=$(echo "$RESPONSE" | jq -r '.id // empty' 2>/dev/null) || GL_PROJECT_ID=""
    WEB_URL=$(echo "$RESPONSE"       | jq -r '.web_url // empty' 2>/dev/null) || WEB_URL=""

    if [ -n "$WEB_URL" ]; then
        log_success "プロジェクト '${_project_name}' を作成しました。"
        log_info "  URL: ${WEB_URL}"
    else
        log_error "プロジェクトの作成に失敗しました。"
        exit 1
    fi
}

# --- ブランチ保護設定 ---
# $1: GitLab ベース URL  $2: アクセストークン  $3: プロジェクト ID  $4: ブランチ名
protect_branch() {
    _base_url="$1"
    _token="$2"
    _project_id="$3"
    _branch="$4"

    log_info "ブランチ '${_branch}' の保護設定をしています..."

    # 既に保護されているか確認（200 なら設定済み）
    _protect_resp=$(gitlab_curl_with_retry \
        -H "Authorization: Bearer ${_token}" \
        "${_base_url}/api/v4/projects/${_project_id}/protected_branches/${_branch}") || _protect_resp=""
    STATUS=$(echo "$_protect_resp" | jq -r '.name // empty' 2>/dev/null) || STATUS=""

    if [ -n "$STATUS" ]; then
        log_warn "ブランチ '${_branch}' はすでに保護されています。スキップします。"
        return 0
    fi

    # push_access_level: 0  = No one（直接 push 禁止）
    # merge_access_level: 40 = Maintainer のみ（MR 経由のみマージ可）
    RESULT=$(gitlab_curl_with_retry \
        -X POST \
        -H "Authorization: Bearer ${_token}" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"${_branch}\", \"push_access_level\": 0, \"merge_access_level\": 40, \"allow_force_push\": false}" \
        "${_base_url}/api/v4/projects/${_project_id}/protected_branches")

    PROTECTED_NAME=$(echo "$RESULT" | jq -r '.name // empty' 2>/dev/null) || PROTECTED_NAME=""

    if [ -n "$PROTECTED_NAME" ]; then
        log_success "ブランチ '${_branch}' の保護設定が完了しました。"
        log_info "  push       : No one（直接 push 禁止）"
        log_info "  merge      : Maintainer のみ（MR 経由でマージ可）"
        log_info "  force push : 禁止"
    else
        log_error "ブランチ '${_branch}' の保護設定に失敗しました。"
        exit 1
    fi
}

# =============================================================================
# メイン
# =============================================================================
main() {
    start_banner
    check_required_commands curl jq docker
    log_info "=== GitLab リポジトリ作成 ==="
    log_info "対象 GitLab   : ${GITLAB_URL}"
    log_info "対象ユーザー  : ${GITLAB_USER}"
    log_info "プロジェクト  : ${GITLAB_PROJECTS}"

    gitlab_check_container  "$GITLAB_CONTAINER"
    gitlab_wait_for_api     "$GITLAB_URL"
    gitlab_get_root_password "$GITLAB_CONTAINER"
    gitlab_get_access_token  "$GITLAB_URL" "$GITLAB_USER" "$GL_ROOT_PASS"

    for PROJECT in $GITLAB_PROJECTS; do
        create_project "$GITLAB_URL" "$GL_ACCESS_TOKEN" "$PROJECT"
        protect_branch "$GITLAB_URL" "$GL_ACCESS_TOKEN" "$GL_PROJECT_ID" "main"
    done

    log_info ""
    log_success "完了！"
    log_info "GitLab: ${GITLAB_URL}/${GITLAB_USER}"

    finish_banner "$S_TIME"
}

main "$@"

