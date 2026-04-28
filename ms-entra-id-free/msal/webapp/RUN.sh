#!/bin/sh

# {{{ show_usage_webui()
show_usage_webui()
{
	cat << EOS
Usage: $(basename $0) [options]

Helper script to manage and run the Spring Boot application.
It automatically handles environment variables by loading or
interactively creating the configuration file at:
$ENV_FILE

Options:
  (none)            Run the application in development mode (clean + bootRun).
  live              Watch for source changes and restart automatically.

EOS
}
# }}}


S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh

ENV_FILE="$CUR_DIR/../container/.env-entraid"

case "$1" in
	"live")
		start_banner
		echo "🚀 Live Development Mode: Watching for changes..."
		./gradlew classes --continuous
		finish_banner $S_TIME
		;;


	"")
		start_banner
		create_env_file "$ENV_FILE"
		load_env_file "$ENV_FILE"
		check_required_vars "$ENV_FILE"

		echo "Test URL:"
		echo "- http://localhost:8080/hands-on"

		export SPRING_PROFILES_ACTIVE=dev
		./gradlew clean
		./gradlew bootRun
		;;
	*)
		show_usage_webui
		;;
esac
