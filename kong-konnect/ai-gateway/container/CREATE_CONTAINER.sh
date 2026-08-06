#!/bin/sh
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh

case "$1" in
	"down")
		start_banner
		check_required_commands "docker"
		destory_ai_gw_container $CUR_DIR
		show_list_container
		finish_banner $S_TIME
		;;

	"list")
		clear
		show_list_container
		;;

	"info")
		show_url_ai_gw
		;;
	"")
		start_banner
		check_required_commands "docker"
		check_prerequisite_create_container $CUR_DIR
		destory_ai_gw_container $CUR_DIR
		create_ai_gw_container $CUR_DIR
		show_list_container
		show_url_ai_gw
		finish_banner $S_TIME
		time docker logs -f ollama-init
		;;
esac
