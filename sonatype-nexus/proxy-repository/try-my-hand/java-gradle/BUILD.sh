#!/bin/sh
set -e
CUR_DIR=$(cd $(dirname $0); pwd)
cd "$CUR_DIR"

export GRADLE_USER_HOME="${CUR_DIR}/.gradle-home"

rm -rf "${GRADLE_USER_HOME}/caches"
./gradlew clean
./gradlew run
