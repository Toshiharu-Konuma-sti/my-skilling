
# {{{ start_banner()
start_banner()
{
	echo "############################################################"
	echo "# START SCRIPT"
	echo "############################################################"
}
# }}}

# {{{ finish_banner()
# $1: time to start this script
finish_banner()
{
	S_TIME=$1
	E_TIME=$(date +%s)
	DURATION=$((E_TIME - S_TIME))
	echo "############################################################"
	echo "# FINISH SCRIPT ($DURATION seconds)"
	echo "############################################################"
}
# }}}

# {{{ call_own_fname()
call_own_fname()
{
	OFNM=$(basename $0)
	echo "$OFNM"
}
# }}}

# {{{ call_show_start_banner()
# $0: the name of the script being executed 
call_show_start_banner()
{
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n> START: Script = [$(call_own_fname)]\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
}
# }}}

# {{{ call_show_finish_banner()
# $0: the name of the script being executed 
call_show_finish_banner()
{
	echo "\n<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n< FINISH: Script = [$(call_own_fname)]\n<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
}
# }}}


# {{{ call_path_of_setup()
# $1: the current directory
call_path_of_setup()
{
	TARGET=$(realpath $1/../setup)
	echo "$TARGET"
}
# }}}

# {{{ call_path_of_try_my_hand()
# $1: the current directory
call_path_of_try_my_hand()
{
	TARGET=$(realpath $1/../try-my-hand)
	echo "$TARGET"
}
# }}}

# {{{ prepare_download_dir()
# $1: the current directory
prepare_download_dir()
{
	CUR_DIR=$1
	DOWN_DIR=$CUR_DIR/../download
	mkdir -p $DOWN_DIR
	echo $DOWN_DIR
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

# {{{ load_env_file(file_path)
# 指定されたパスの環境変数ファイルを読み込み、exportする
load_env_file() {
	_path="$1"

	if [ -f "$_path" ]; then
		echo "📂 Loading environment variables from $_path"
		# コメント行を除外して export
		export $(grep -v '^#' "$_path" | xargs)
	else
		echo "⚠️  Environment file not found, skipping load: $_path"
	fi
}
# }}}


# {{{ check_required_commands()
check_required_commands()
{
	echo "\n### START: Check required commands ##########"
	# WSL: Windows drive mounts live under /mnt/<drive-letter>/; reject them as non-Linux
	local _is_wsl=0
	case "$(uname -r 2>/dev/null)" in
		*[Mm]icrosoft*|*[Ww][Ss][Ll]*) _is_wsl=1 ;;
	esac
	local missing_cmds=""
	for cmd in $*; do
		local _cmd_path
		_cmd_path=$(command -v "${cmd}" 2>/dev/null) || true
		local _found=0
		if [ -n "$_cmd_path" ]; then
			if [ "$_is_wsl" -eq 1 ]; then
				case "$_cmd_path" in
					/mnt/[a-zA-Z]/*) _found=0 ;;
					*) _found=1 ;;
				esac
			else
				_found=1
			fi
		fi
		if [ "$_found" -eq 0 ]; then
			if [ -z "$missing_cmds" ]; then
				missing_cmds="${cmd}"
			else
				missing_cmds="${missing_cmds} ${cmd}"
			fi
		fi
	done
	if [ -n "$missing_cmds" ]; then
		echo "========================================================" >&2
		echo " [ERROR] The following required commands are missing." >&2
		echo " Please install them or check your PATH to continue." >&2
		echo "========================================================" >&2
		for missing in $missing_cmds; do
			echo " - ${missing}" >&2
		done
		echo "" >&2
		exit 1
	fi
}
# }}}

# {{{ remove_container_and_image()
# $1: the current directory
# $2: the name of container to rebuild
remove_container_and_image()
{
	CUR_DIR=$1
	CONTAINER_NM=$2
	echo "\n### START: Remove a container and an image ##########"
	docker stop $CONTAINER_NM
	IMAGE_NM=$(docker inspect --format='{{.Config.Image}}' $CONTAINER_NM)
	docker rm $CONTAINER_NM
	docker rmi $IMAGE_NM
}
# }}}

# {{{ loop_curl_until_success()
# $1: the command to call with cURL
loop_curl_until_success()
{
	CMD_CURL=$1
	echo "$CMD_CURL" >&2
	BODY_CURL=""
	WAIT_SEC=5
	while true; do
		BODY_CURL=$(eval $CMD_CURL)
		if [ $? -eq 0 ]; then
			echo "-> result: connection successful." >&2
			break
		else
			echo "-> result: connection failed. will try again in $WAIT_SEC seconds." >&2
			sleep $WAIT_SEC
		fi
	done
	echo "$BODY_CURL" >&2
	echo "$BODY_CURL"
}
# }}}

# {{{ show_list_container()
show_list_container()
{
	echo "\n### START: Show a list of container ##########"
	docker ps -a
}
# }}}

