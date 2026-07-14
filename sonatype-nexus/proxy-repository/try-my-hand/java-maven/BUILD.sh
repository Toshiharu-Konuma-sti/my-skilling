#!/bin/sh
set -e
CUR_DIR=$(cd $(dirname $0); pwd)
cd "$CUR_DIR"

rm -rf .m2
./mvnw clean compile exec:java