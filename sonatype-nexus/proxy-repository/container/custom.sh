
# {{{ create_container()
# $1: the current directory
create_container()
{
	CUR_DIR=$1
	echo "\n### START: Create new containers ##########"
	docker compose \
		-f $CUR_DIR/docker-compose.yml \
		up -d -V --remove-orphans
}
# }}}

# {{{ destory_container()
# $1: the current directory
destory_container()
{
	CUR_DIR=$1
	echo "\n### START: Destory existing containers ##########"
	docker compose \
		-f $CUR_DIR/docker-compose.yml \
		down -v --remove-orphans
}
# }}}


# {{{ util_ask_input()
# $1: pronpt message (eg.: "Enter Name: ")
util_ask_input() {
	local prompt="$1"
	local answer
	printf "%s" "$prompt" >&2
	read answer
	echo "$answer"
}
# }}}

# {{{ util_ask_secret()
# $1: prompt message
util_ask_secret() {
	local prompt="$1"
	local answer
	printf "%s" "$prompt" >&2
	stty -echo
	read answer
	stty echo
	printf "\n" >&2
	echo "$answer"
}
# }}}


# {{{ show_url()
show_url()
{
	cat << EOS

/************************************************************
 * Information:
 * - Sonatype Nexus:    http://localhost:8081
 * - GitLab:            http://localhost:13000
 ***********************************************************/

EOS
}
# }}}

# {{{ show_passwords()
show_password()
{
#	PW_SN=$(docker container exec nexus cat /nexus-data/admin.password)
	PW_GL=$(docker container exec gitlab cat /etc/gitlab/initial_root_password | grep "^Password" | sed -e "s/^Password: //g")
	cat << EOS
- Password:
  - GitLab root user: ${PW_GL}

EOS
}
# }}}

# {{{ show_usage()
show_usage()
{
	cat << EOS
Usage: $(basename $0) [options]

Start the containers needed for the hands-on. If there are any containers
already running, stop them and remove resources beforehand.

Options:
  up                    Start the containers.
  down                  Stop the containers and remove resources.
  rebuild {container}   Stop the specified container, removes its image, and
                        restarts it.
  list                  Show the list of containers.
  info                  Show the information such as URLs.

EOS
}
# }}}

# {{{ log_info()
# $1: message
log_info()
{
    printf "[INFO] %s\n" "$1"
}
# }}}

# {{{ log_success()
# $1: message
log_success()
{
    COLOR='\033[1;32m'
    NC='\033[0m'
    printf "${COLOR}[SUCCESS] %s${NC}\n" "$1"
}
# }}}

# {{{ log_warn()
# $1: message
log_warn()
{
    COLOR='\033[1;33m'
    NC='\033[0m'
    printf "${COLOR}[WARN] %s${NC}\n" "$1"
}
# }}}

# {{{ log_error()
# $1: message
log_error()
{
    COLOR='\033[1;31m'
    NC='\033[0m'
    printf "${COLOR}[ERROR] %s${NC}\n" "$1"
}
# }}}

# =============================================================================
# GitLab 共通関数
# =============================================================================

# {{{ gitlab_check_container()
# $1: コンテナ名
gitlab_check_container() {
    _container="$1"
    log_info "コンテナ '${_container}' の起動を確認しています..."
    if ! docker ps --filter "name=^${_container}$" --filter "status=running" \
            --format "{{.Names}}" | grep -q "^${_container}$"; then
        log_error "コンテナ '${_container}' が起動していません。"
        exit 1
    fi
    log_success "コンテナが起動しています。"
}
# }}}

# {{{ gitlab_wait_for_api()
# $1: GitLab ベース URL
gitlab_wait_for_api() {
    _base_url="$1"
    log_info "GitLab API の起動を待っています... (${_base_url})"
    RETRY=0
    MAX_RETRY=24
    # 401 (認証エラー) でも「API が起動している」とみなす
    until [ "$(curl -s -o /dev/null -w '%{http_code}' "${_base_url}/api/v4/version")" != "000" ]; do
        RETRY=$((RETRY + 1))
        if [ "$RETRY" -ge "$MAX_RETRY" ]; then
            log_error "GitLab API に接続できませんでした。"
            exit 1
        fi
        log_info "  待機中... (${RETRY}/${MAX_RETRY})"
        sleep 5
    done
    log_success "GitLab API が応答しています。"
}
# }}}

# {{{ gitlab_get_root_password()
# $1: GitLab コンテナ名
# 戻り値: GL_ROOT_PASS にパスワードを設定する
gitlab_get_root_password() {
    _container="$1"
    log_info "root の初期パスワードを取得しています..."
    GL_ROOT_PASS=$(docker exec "$_container" \
        cat /etc/gitlab/initial_root_password 2>/dev/null \
        | grep "^Password" \
        | sed -e "s/^Password: //g")
    if [ -z "$GL_ROOT_PASS" ]; then
        log_error "初期パスワードファイルが見つかりません。パスワードが変更済みの可能性があります。"
        exit 1
    fi
    log_success "初期パスワードを取得しました。"
}
# }}}

# {{{ gitlab_curl_with_retry()
# GitLab API を呼び出し、500 エラー（HTML 応答）の場合はリトライする
# $@: curl コマンドに渡す引数（-s は関数内で自動付与）
# 戻り値: stdout にレスポンスボディ
# ※ ログは stderr に出力（$() 内でも画面に表示されるようにするため）
gitlab_curl_with_retry()
{
    _retry=0
    _max_retry=10
    _wait_sec=5
    while [ "$_retry" -lt "$_max_retry" ]; do
        printf "[INFO]  GitLab API 呼び出し中...\n" >&2
        _body=$(curl -s "$@" 2>/dev/null) || _body=""
        # HTML が返ってきた場合（500 エラー）はリトライ
        if echo "$_body" | grep -q "<!DOCTYPE"; then
            _retry=$((_retry + 1))
            printf "\033[1;33m[WARN]  500 エラーを受信しました。${_wait_sec}秒待機後にリトライします... (${_retry}/${_max_retry})\033[0m\n" >&2
            sleep "$_wait_sec"
        else
            echo "$_body"
            return 0
        fi
    done
    printf "\033[1;31m[ERROR] ${_max_retry} 回リトライしても 500 エラーが続いています。\033[0m\n" >&2
    return 1
}
# }}}
# $1: GitLab ベース URL  $2: ユーザー名  $3: パスワード
# 戻り値: GL_ACCESS_TOKEN にアクセストークンを設定する
gitlab_get_access_token() {
    _base_url="$1"
    _user="$2"
    _pass="$3"
    log_info "OAuth2 パスワードグラントでアクセストークンを取得しています..."
    GL_ACCESS_TOKEN=$(gitlab_curl_with_retry -X POST \
        -H "Content-Type: application/json" \
        -d "{\"grant_type\": \"password\", \"username\": \"${_user}\", \"password\": \"${_pass}\"}" \
        "${_base_url}/oauth/token" \
        | jq -r '.access_token // empty' 2>/dev/null) || GL_ACCESS_TOKEN=""
    if [ -z "$GL_ACCESS_TOKEN" ]; then
        log_error "アクセストークンの取得に失敗しました。"
        exit 1
    fi
    log_success "アクセストークンを取得しました。"
}
# }}}
