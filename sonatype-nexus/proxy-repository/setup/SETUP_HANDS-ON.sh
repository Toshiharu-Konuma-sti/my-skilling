#!/bin/sh

clear
S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh

start_banner

check_required_commands "jq pip uv go"
$CUR_DIR/step01_NEXUS_CHANGE_ADMIN_PASSWORD.sh
$CUR_DIR/step02_NEXUS_CREATE_REPOSITORY.sh
$CUR_DIR/step11_GITLAB_CREATE_REPOSITORY.sh
$CUR_DIR/step12_GITLAB_CREATE_GROUP.sh
$CUR_DIR/step13_GITLAB_REGISTER_RUNNER.sh
$CUR_DIR/step14_GITLAB_PUSH_TO_REPOSITORY.sh

finish_banner $S_TIME
