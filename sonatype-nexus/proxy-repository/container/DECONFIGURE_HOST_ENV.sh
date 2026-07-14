#!/bin/sh

# ==============================================================================
# HTTP レジストリ検証環境 クリーンアップスクリプト
# Description: /etc/hosts からのドメイン定義削除および /etc/docker/daemon.json の削除を行い
#              Docker デーモンを再起動します。
# ==============================================================================

# 失敗時に即時終了
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. $CUR_DIR/common.sh
. $CUR_DIR/custom.sh
. $CUR_DIR/variables.sh

# --- パラメータ設定 ---
TARGET_DOMAIN="$NEXUS_DOMAIN"

# --- メイン処理関数の定義 ---
main() {

    log_info "=== HTTP レジストリ接続環境のクリーンアップを開始します ==="

    # 2. /etc/hosts から対象ドメインのエントリーを削除
    log_info "/etc/hosts から '${TARGET_DOMAIN}' のエントリーを削除しています..."

    if grep -q "[[:space:]]${TARGET_DOMAIN}$" /etc/hosts; then
		sudo cp /etc/hosts /etc/hosts.bak."$(date +%Y%m%d%H%M%S)"
		sudo sed -i "/[[:space:]]${TARGET_DOMAIN}$/d" /etc/hosts
        log_success "/etc/hosts から '${TARGET_DOMAIN}' を削除しました。"
    else
        log_warn "/etc/hosts に '${TARGET_DOMAIN}' のエントリーが見つかりませんでした。スキップします。"
    fi

    # 3. /etc/docker/daemon.json の削除
    DAEMON_JSON="/etc/docker/daemon.json"
    log_info "${DAEMON_JSON} の削除を確認しています..."

    if [ -f "${DAEMON_JSON}" ]; then
		sudo cp "${DAEMON_JSON}" "${DAEMON_JSON}.bak.$(date +%Y%m%d%H%M%S)"
		sudo rm -f "${DAEMON_JSON}"
        log_success "${DAEMON_JSON} を削除しました（バックアップを作成しました）。"
    else
        log_warn "${DAEMON_JSON} が存在しません。スキップします。"
    fi

    # 4. Docker デーモンの再起動
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

    # 5. 完了確認メッセージ
    printf "\n"
    log_success "=== クリーンアップが正常に完了しました ==="
    printf "\n"
}

start_banner
main "$@"
finish_banner $S_TIME
