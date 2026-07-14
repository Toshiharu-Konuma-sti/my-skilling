#!/bin/sh

# ==============================================================================
# HTTP レジストリ検証環境 自動設定スクリプト
# Description: /etc/hosts の更新および /etc/docker/daemon.json の設定を行い
#              Docker デーモンを再起動します。
# ==============================================================================
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. "${CUR_DIR}/common.sh"
. "${CUR_DIR}/custom.sh"
. "${CUR_DIR}/variables.sh"

# --- パラメータ設定 ---
TARGET_DOMAIN="$NEXUS_DOMAIN"
TARGET_PORT="$NEXUS_PORT_DOCKER"

# --- メイン処理関数の定義 ---
main() {
    # 1. Root 権限の確認
#    if [ "$(id -u)" -ne 0 ]; then
#        log_error "このスクリプトは root 権限（または sudo）で実行する必要があります。"
#        log_info "実行例: sudo sh $0"
#        exit 1
#    fi

    log_info "=== HTTP レジストリ接続環境の自動構築を開始します ==="

    # 2. IP アドレスの自動取得（127.0.0.1 以外のプライベート IP の先頭を取得）
    TARGET_IP=$(hostname -I | awk '{print $1}')

    if [ -z "$TARGET_IP" ]; then
        log_error "有効な IP アドレスが取得できませんでした。"
        exit 1
    fi

    log_info "使用する IP アドレス: ${TARGET_IP}"
    log_info "対象ドメイン: ${TARGET_DOMAIN}"
    log_info "対象ポート: ${TARGET_PORT}"

    # 3. /etc/hosts の更新
    log_info "/etc/hosts を設定しています..."

    # 既存エントリーのバックアップと古いドメイン定義の削除
	sudo cp /etc/hosts /etc/hosts.bak."$(date +%Y%m%d%H%M%S)"
	sudo sed -i "/[[:space:]]${TARGET_DOMAIN}$/d" /etc/hosts

    # 新しい IP とドメインのペアを追記
	printf "%s\t%s\n" "${TARGET_IP}" "${TARGET_DOMAIN}" | sudo tee -a /etc/hosts >/dev/null
    log_success "/etc/hosts に '${TARGET_IP} ${TARGET_DOMAIN}' を追加しました。"

    # 4. /etc/docker/daemon.json の生成/更新
    log_info "/etc/docker/daemon.json を設定しています..."

    DOCKER_DIR="/etc/docker"
    DAEMON_JSON="${DOCKER_DIR}/daemon.json"

    if [ ! -d "${DOCKER_DIR}" ]; then
        mkdir -p "${DOCKER_DIR}"
    fi

    if [ -f "${DAEMON_JSON}" ]; then
		sudo cp "${DAEMON_JSON}" "${DAEMON_JSON}.bak.$(date +%Y%m%d%H%M%S)"
    fi

	cat <<EOF | sudo tee "${DAEMON_JSON}" >/dev/null
{
  "insecure-registries": [
    "${TARGET_DOMAIN}:${TARGET_PORT}"
  ]
}
EOF

    log_success "${DAEMON_JSON} に '${TARGET_DOMAIN}:${TARGET_PORT}' を設定しました。"

    # 5. Docker デーモンの再起動
    log_info "Docker サービスを再起動しています..."

    if command -v systemctl >/dev/null 2>&1; then
		sudo systemctl restart docker
    elif command -v service >/dev/null 2>&1; then
		sudo service docker restart
    else
        log_error "Docker サービスを再起動するコマンドが見つかりません。"
        exit 1
    fi

    log_success "Docker デーモンを再起動しました。"

    # 6. 完了確認メッセージ
    printf "\n"
    log_success "=== 設定が正常に完了しました ==="
    log_info "以下のコマンドでログインテストを実施してください:"
    log_info "  docker login ${TARGET_DOMAIN}:${TARGET_PORT} -u admin -p password"
    printf "\n"
}

start_banner
main "$@"
finish_banner $S_TIME