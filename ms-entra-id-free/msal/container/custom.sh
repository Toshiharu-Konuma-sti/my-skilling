
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


# {{{ create_env_file(file_path)
# ファイルが存在しない場合、対話形式で環境変数ファイルを作成する
create_env_file() {
    _path="$1"

    if [ ! -f "$_path" ]; then
        echo "⚠️ Configuration file not found: $_path"
        
        # ユーティリティを使用して入力を促す
        _ans=$(util_ask_input "➡️ Create it now? (y/N): ")
        
        if [ "$_ans" = "y" ] || [ "$_ans" = "Y" ]; then
            _tid=$(util_ask_input "🏢 Enter ENTRA_TENANT_ID: ")
            _cid=$(util_ask_input "🤖 Enter ENTRA_CLIENT_ID: ")
            # シークレットは入力を非表示にする
            _csec=$(util_ask_secret "🔑 Enter ENTRA_CLIENT_SECRET: ")

            # ディレクトリ作成と書き出し
            mkdir -p "$(dirname "$_path")"
            cat << EOF > "$_path"
ENTRA_TENANT_ID=$_tid
ENTRA_CLIENT_ID=$_cid
ENTRA_CLIENT_SECRET=$_csec
EOF
            echo "✅ Created: $_path"
        else
            echo "⏩ Skipping creation."
        fi
    fi
}
# }}}

# {{{ load_env_file(file_path)
# 指定されたパスの環境変数ファイルを読み込み、exportする
load_env_file() {
    _path="$1"

    if [ -f "$_path" ]; then
        echo "📂 Loading environment variables from $_path..."
        # コメント行を除外して export
        export $(grep -v '^#' "$_path" | xargs)
    else
        echo "⚠️  Environment file not found, skipping load: $_path"
    fi
}
# }}}

# {{{ check_required_vars(file_path_for_msg)
# 必要な変数がエクスポートされているか確認（エラーメッセージ用にパスを受け取る）
check_required_vars() {
    _msg_path="$1"
    if [ -z "${ENTRA_TENANT_ID}" ] || [ -z "${ENTRA_CLIENT_ID}" ] || [ -z "${ENTRA_CLIENT_SECRET}" ]; then
        echo "❌ Error: Entra ID credentials are not set."
        echo "   Please check $_msg_path or set environment variables manually."
        exit 1
    fi
}
# }}}


# {{{ show_url()
show_url()
{
	cat << EOS

/************************************************************
 * Information:
 * - Web App:   http://localhost:8080/hands-on
 * - Redis:     http://localhost:8001
 ***********************************************************/

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
