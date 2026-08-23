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
# main()
# =============================================================================
main() {
	call_show_start_banner

    check_required_commands curl jq docker git rsync

	_try_dir=$(call_path_of_try_my_hand $CUR_DIR)
	log_info "the dir for try my hand  = [${_try_dir}]"

    log_info "=== GitLab へのコード push ==="
    log_info "対象 GitLab : ${GITLAB_URL}"
    log_info "ブランチ    : ${BRANCH}"

    gitlab_wait_for_api      "$GITLAB_URL"
    gitlab_get_root_password  "$GITLAB_CONTAINER"
    gitlab_get_access_token   "$GITLAB_URL" "$GITLAB_USER" "$GL_ROOT_PASS"

    for _project in $GITLAB_PROJECTS; do
        push_to_gitlab "$GITLAB_URL" "$GITLAB_GROUP_PATH" "$GL_ACCESS_TOKEN" \
                       "${_project}" "${_try_dir}/${_project}" \
                       "$BRANCH" "Add ${_project} demo application"
    done

    log_info ""
    log_success "完了！"
    log_info "GitLab グループ: ${GITLAB_URL}/${GITLAB_GROUP_PATH}"

	call_show_finish_banner
}

main "$@"
