#!/bin/sh

# ==============================================================================
# GitLab リポジトリへのコード push スクリプト
# Description: try-my-hand/java-gradle/ の内容を GitLab の java-gradle リポジトリへ
#              「feature/sample」ブランチで push します。
#              ※ このプロジェクトは上位の git リポジトリで管理されているため、
#                 一時ディレクトリにコピーしてから push します。
# ==============================================================================

# 失敗時に即時終了
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh
. $CUR_DIR/variables.sh

# --- このスクリプト固有のパラメータ ---
# push 対象プロジェクトのリストは variables.sh の GITLAB_PROJECTS で管理
BRANCH="feature/sample"

# =============================================================================
# サブルーチン
# =============================================================================

# --- feature/sample ブランチで push ---
# $1: GitLab ベース URL  $2: ユーザー名  $3: アクセストークン
# $4: プロジェクト名  $5: ソースディレクトリ  $6: ブランチ名  $7: コミットメッセージ
push_to_gitlab() {
    _base_url="$1"
    _user="$2"
    _token="$3"
    _project="$4"
    _src="$5"
    _branch="$6"
    _msg="$7"

    # GitLab の push URL（OAuth2 token を oauth2 ユーザーとして渡す形式）
    _remote_url="http://oauth2:${_token}@$(echo "${_base_url}" | sed 's|http://||')/${_user}/${_project}.git"

    log_info "ソースディレクトリ: ${_src}"
    log_info "push 先           : ${_base_url}/${_user}/${_project}"
    log_info "ブランチ          : ${_branch}"

    # TMPDIR は POSIX 予約変数のため WORK_DIR を使用（mktemp の挙動への干渉を防ぐ）
    WORK_DIR=$(mktemp -d)

    # 空の GitLab リポジトリを clone する
    log_info "GitLab リポジトリを clone しています..."
    if ! git clone "${_remote_url}" "${WORK_DIR}/repo" > /dev/null 2>&1; then
        log_error "clone に失敗しました: ${_base_url}/${_user}/${_project}"
        rm -rf "${WORK_DIR}"
        exit 1
    fi
    cd "${WORK_DIR}/repo"
    git config user.email "setup@localhost"
    git config user.name "Setup Script"

    # main から派生した通常ブランチを作成
    # （orphan ではなく main との共通歴史を持たせることで MR マージを可能にする）
    git checkout -b "${_branch}" > /dev/null 2>&1

    # ソースファイルをコピー（.gitignore のパターンを除外）
    log_info "ファイルをコピーしています..."
    rsync -a --filter=':- .gitignore' \
          --exclude='.git/' \
          "${_src}/" "${WORK_DIR}/repo/"

    git add .
    git commit -m "${_msg}" > /dev/null 2>&1 || true

    # force push（再実行時にリモートに既存ブランチがあっても上書き可能）
    log_info "push しています..."
    _push_retry=0
    _push_max_retry=10
    while true; do
        _push_rc=0
        _push_err=$(git push --force "${_remote_url}" "${_branch}" 2>&1) || _push_rc=$?
        if [ "$_push_rc" -eq 0 ]; then
            break  # 成功
        fi
        # 500 エラーの場合はリトライ
        if echo "$_push_err" | grep -q "500" && [ "$_push_retry" -lt "$_push_max_retry" ]; then
            _push_retry=$((_push_retry + 1))
            log_warn "GitLab 500 エラー。5秒後にリトライします... (${_push_retry}/${_push_max_retry})" >&2
            sleep 5
        else
            _push_err_masked=$(echo "$_push_err" | sed "s|oauth2:[^@]*@|oauth2:****@|g")
            log_error "push に失敗しました: ${_base_url}/${_user}/${_project} (branch: ${_branch})"
            log_error "  git 出力: ${_push_err_masked}"
            cd /
            rm -rf "${WORK_DIR}"
            exit 1
        fi
    done

    cd /
    rm -rf "${WORK_DIR}"
    log_success "push 完了: ${_base_url}/${_user}/${_project} (branch: ${_branch})"
}

# =============================================================================
# メイン
# =============================================================================
main() {
    start_banner
    check_required_commands curl jq docker git rsync
    log_info "=== GitLab へのコード push ==="
    log_info "対象 GitLab : ${GITLAB_URL}"
    log_info "ブランチ    : ${BRANCH}"

    gitlab_wait_for_api      "$GITLAB_URL"
    gitlab_get_root_password  "$GITLAB_CONTAINER"
    gitlab_get_access_token   "$GITLAB_URL" "$GITLAB_USER" "$GL_ROOT_PASS"

    for PROJECT in $GITLAB_PROJECTS; do
        push_to_gitlab "$GITLAB_URL" "$GITLAB_GROUP_PATH" "$GL_ACCESS_TOKEN" \
                       "$PROJECT" "${CUR_DIR}/${PROJECT}" \
                       "$BRANCH" "Add ${PROJECT} demo application"
    done

    log_info ""
    log_success "完了！"
    log_info "GitLab グループ: ${GITLAB_URL}/${GITLAB_GROUP_PATH}"

    finish_banner "$S_TIME"
}

main "$@"
