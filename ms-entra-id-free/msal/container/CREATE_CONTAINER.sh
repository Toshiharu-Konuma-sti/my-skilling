#!/bin/sh
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh

ENV_FILE="$CUR_DIR/.env-entraid"

case "$1" in
	"down")
		start_banner
		destory_container $CUR_DIR
		show_list_container
		finish_banner $S_TIME
		;;
	"rebuild")
		clear
		start_banner
		remove_container_and_image $CUR_DIR $2
		create_env_file "$ENV_FILE"
		create_container $CUR_DIR
		show_list_container
		finish_banner $S_TIME
		;;
	"list")
		clear
		show_list_container
		;;

	"info")
		show_url
		;;
	"")
		start_banner
		destory_container $CUR_DIR
		create_env_file "$ENV_FILE"
		create_container $CUR_DIR
		show_list_container
		show_url
		finish_banner $S_TIME
		;;
esac
