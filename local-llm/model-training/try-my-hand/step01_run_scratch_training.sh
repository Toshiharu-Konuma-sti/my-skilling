#!/bin/sh
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh

start_banner
docker exec -it llm-trainer /app/run_scratch.sh
finish_banner $S_TIME
