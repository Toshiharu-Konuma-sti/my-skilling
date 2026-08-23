#!/bin/sh

# ==============================================================================
# Nexus 3 リポジトリ セットアップスクリプト
# Description: REST API を利用して以下を一括セットアップします。
#   [Maven]   maven-central / maven-public リポジトリの存在確認
#   [npm]     npm Token Realm の有効化 + プロキシ/ホステッドリポジトリの作成
#   [PyPI]    PyPI プロキシ/ホステッドリポジトリの作成
#   [Go]      Go モジュールプロキシリポジトリの作成
#   [Docker]  Bearer Token Realm の有効化 + Docker Hub プロキシリポジトリの作成
# ※ npm / pypi / go のプロキシ・ホステッドは汎用関数 create_proxy_repo /
#   create_hosted_repo で処理（フォーマット名を引数で渡す）
# ==============================================================================

# 失敗時に即時終了
set -e

S_TIME=$(date +%s)
CUR_DIR=$(cd $(dirname $0); pwd)
. "${CUR_DIR}/common.sh"
. "${CUR_DIR}/custom.sh"
. "${CUR_DIR}/variables.sh"

# {{{ wait_for_nexus()
# --- Nexus API 起動待ち ---
# $1: ベース URL  $2: ユーザー名  $3: パスワード
wait_for_nexus()
{
    _base_url="$1"
    _user="$2"
    _pass="$3"
    log_info "Nexus REST API の起動を待っています... (${_base_url})"
    RETRY=0
    MAX_RETRY=24  # 最大 2 分待機
    until curl -sf -u "${_user}:${_pass}" \
            "${_base_url}/service/rest/v1/status/writable" > /dev/null 2>&1; do
        RETRY=$((RETRY + 1))
        if [ "$RETRY" -ge "$MAX_RETRY" ]; then
            log_error "Nexus REST API に接続できませんでした。"
            exit 1
        fi
        log_info "  待機中... (${RETRY}/${MAX_RETRY})"
        sleep 5
    done
    log_success "Nexus REST API が応答しています。"
}
# }}}

# {{{ repo_exists()
# --- リポジトリの存在確認 ---
# $1: ベース URL  $2: ユーザー名  $3: パスワード  $4: リポジトリ名
# 戻り値: 0=存在する / 1=存在しない
repo_exists()
{
    _base_url="$1"
    _user="$2"
    _pass="$3"
    _repo="$4"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -u "${_user}:${_pass}" \
        "${_base_url}/service/rest/v1/repositories/${_repo}")
    [ "$HTTP_CODE" = "200" ]
}
# }}}

# =============================================================================
# Maven セクション
# =============================================================================

# {{{ check_maven_repositories()
# --- Maven デフォルトリポジトリの確認・一覧表示 ---
# $1: ベース URL  $2: ユーザー名  $3: パスワード
check_maven_repositories()
{
    _base_url="$1"
    _user="$2"
    _pass="$3"

    log_info "Maven デフォルトリポジトリを確認しています..."

    for _repo in maven-central maven-public; do
        if repo_exists "$_base_url" "$_user" "$_pass" "$_repo"; then
            log_success "  '${_repo}' が存在します。"
        else
            log_error "  '${_repo}' が見つかりません。Nexus の初期化が完了しているか確認してください。"
            exit 1
        fi
    done

    log_info "Maven リポジトリ URL:"
    log_info "  ${_base_url}/repository/maven-public/  (グループ: gradle/maven から利用)"

    log_info "=== 利用可能な Maven リポジトリ一覧 ==="
    curl -sf -u "${_user}:${_pass}" \
        "${_base_url}/service/rest/v1/repositories" \
        | jq -r '.[] | select(.format == "maven2") | .name' \
        | while read -r _name; do
            log_info "  - ${_name}  =>  ${_base_url}/repository/${_name}/"
          done
}
# }}}

# =============================================================================
# npm セクション
# =============================================================================

# {{{ enable_npm_realm()
# --- npm Token Realm の有効化 ---
# $1: ベース URL  $2: ユーザー名  $3: パスワード
enable_npm_realm()
{
    _base_url="$1"
    _user="$2"
    _pass="$3"
    log_info "npm Token Realm の状態を確認しています..."

    ACTIVE_REALMS=$(curl -sf -u "${_user}:${_pass}" \
        "${_base_url}/service/rest/v1/security/realms/active")

    if echo "$ACTIVE_REALMS" | grep -q "NpmToken"; then
        log_success "npm Token Realm はすでに有効です。"
        return 0
    fi

    NEW_REALMS=$(echo "$ACTIVE_REALMS" | jq '. + ["NpmToken"]')

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X PUT "${_base_url}/service/rest/v1/security/realms/active" \
        -u "${_user}:${_pass}" \
        -H "Content-Type: application/json" \
        -d "${NEW_REALMS}")

    if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
        log_success "npm Token Realm を有効化しました。"
    else
        log_error "npm Token Realm の有効化に失敗しました。(HTTP ${HTTP_CODE})"
        exit 1
    fi
}
# }}}

# =============================================================================
# Docker セクション
# =============================================================================

# {{{ enable_docker_realm()
# --- Docker Bearer Token Realm の有効化 ---
# $1: ベース URL  $2: ユーザー名  $3: パスワード
enable_docker_realm()
{
    _base_url="$1"
    _user="$2"
    _pass="$3"
    log_info "Docker Bearer Token Realm の状態を確認しています..."

    ACTIVE_REALMS=$(curl -sf -u "${_user}:${_pass}" \
        "${_base_url}/service/rest/v1/security/realms/active")

    if echo "$ACTIVE_REALMS" | grep -q "DockerToken"; then
        log_success "Docker Bearer Token Realm はすでに有効です。"
        return 0
    fi

    NEW_REALMS=$(echo "$ACTIVE_REALMS" | jq '. + ["DockerToken"]')

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X PUT "${_base_url}/service/rest/v1/security/realms/active" \
        -u "${_user}:${_pass}" \
        -H "Content-Type: application/json" \
        -d "${NEW_REALMS}")

    if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
        log_success "Docker Bearer Token Realm を有効化しました。"
    else
        log_error "Realm の有効化に失敗しました。(HTTP ${HTTP_CODE})"
        exit 1
    fi
}
# }}}

# {{{ create_docker_proxy_repo()
# --- Docker Hub プロキシリポジトリの作成 ---
# $1: ベース URL  $2: ユーザー名  $3: パスワード
# $4: リポジトリ名  $5: HTTP ポート  $6: リモート URL
create_docker_proxy_repo()
{
    _base_url="$1"
    _user="$2"
    _pass="$3"
    _repo_name="$4"
    _http_port="$5"
    _remote_url="$6"
    log_info "Docker プロキシリポジトリ '${_repo_name}' を作成しています..."

    if repo_exists "$_base_url" "$_user" "$_pass" "$_repo_name"; then
        log_warn "リポジトリ '${_repo_name}' はすでに存在します。スキップします。"
        return 0
    fi

    PAYLOAD=$(cat <<EOF
{
  "name": "${_repo_name}",
  "online": true,
  "storage": { "blobStoreName": "default", "strictContentTypeValidation": true },
  "docker": { "v1Enabled": false, "forceBasicAuth": true, "httpPort": ${_http_port} },
  "dockerProxy": { "indexType": "HUB" },
  "proxy": { "remoteUrl": "${_remote_url}", "contentMaxAge": 1440, "metadataMaxAge": 1440 },
  "negativeCache": { "enabled": true, "timeToLive": 1440 },
  "httpClient": { "blocked": false, "autoBlock": true }
}
EOF
)

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${_base_url}/service/rest/v1/repositories/docker/proxy" \
        -u "${_user}:${_pass}" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")

    if [ "$HTTP_CODE" = "201" ]; then
        log_success "Docker プロキシリポジトリ '${_repo_name}' (port: ${_http_port}) を作成しました。"
    else
        log_error "Docker リポジトリの作成に失敗しました。(HTTP ${HTTP_CODE})"
        exit 1
    fi
}
# }}}

# =============================================================================
# 汎用リポジトリ作成関数（npm / pypi / go など Docker 以外の形式で共用）
# =============================================================================

# {{{ create_proxy_repo()
# --- プロキシリポジトリの作成（汎用）---
# $1: ベース URL  $2: ユーザー名  $3: パスワード
# $4: フォーマット (npm|pypi|go|...)  $5: リポジトリ名  $6: リモート URL
create_proxy_repo()
{
    _base_url="$1"
    _user="$2"
    _pass="$3"
    _format="$4"
    _repo_name="$5"
    _remote_url="$6"
    log_info "${_format} プロキシリポジトリ '${_repo_name}' を作成しています..."

    if repo_exists "$_base_url" "$_user" "$_pass" "$_repo_name"; then
        log_warn "リポジトリ '${_repo_name}' はすでに存在します。スキップします。"
        return 0
    fi

    PAYLOAD=$(cat <<EOF
{
  "name": "${_repo_name}",
  "online": true,
  "storage": { "blobStoreName": "default", "strictContentTypeValidation": true },
  "proxy": { "remoteUrl": "${_remote_url}", "contentMaxAge": 1440, "metadataMaxAge": 1440 },
  "negativeCache": { "enabled": true, "timeToLive": 1440 },
  "httpClient": { "blocked": false, "autoBlock": true }
}
EOF
)

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${_base_url}/service/rest/v1/repositories/${_format}/proxy" \
        -u "${_user}:${_pass}" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")

    if [ "$HTTP_CODE" = "201" ]; then
        log_success "${_format} プロキシリポジトリ '${_repo_name}' を作成しました。"
    else
        log_error "${_format} プロキシリポジトリの作成に失敗しました。(HTTP ${HTTP_CODE})"
        exit 1
    fi
}
# }}}

# {{{ create_hosted_repo()
# --- ホステッドリポジトリの作成（汎用）---
# $1: ベース URL  $2: ユーザー名  $3: パスワード
# $4: フォーマット (npm|pypi|...)  $5: リポジトリ名  $6: writePolicy (省略時: allow_once)
create_hosted_repo()
{
    _base_url="$1"
    _user="$2"
    _pass="$3"
    _format="$4"
    _repo_name="$5"
    _write_policy="${6:-allow_once}"
    log_info "${_format} ホステッドリポジトリ '${_repo_name}' を作成しています..."

    if repo_exists "$_base_url" "$_user" "$_pass" "$_repo_name"; then
        log_warn "リポジトリ '${_repo_name}' はすでに存在します。スキップします。"
        return 0
    fi

    PAYLOAD=$(cat <<EOF
{
  "name": "${_repo_name}",
  "online": true,
  "storage": { "blobStoreName": "default", "strictContentTypeValidation": true, "writePolicy": "${_write_policy}" }
}
EOF
)

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${_base_url}/service/rest/v1/repositories/${_format}/hosted" \
        -u "${_user}:${_pass}" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")

    if [ "$HTTP_CODE" = "201" ]; then
        log_success "${_format} ホステッドリポジトリ '${_repo_name}' を作成しました。"
    else
        log_error "${_format} ホステッドリポジトリの作成に失敗しました。(HTTP ${HTTP_CODE})"
        exit 1
    fi
}
# }}}

# =============================================================================
# メイン
# =============================================================================
main() {
	call_show_start_banner

    check_required_commands curl jq
    log_info "=== Nexus リポジトリ セットアップ ==="
    log_info "対象 Nexus: ${NEXUS_URL}"

    wait_for_nexus "$NEXUS_URL" "$NEXUS_USER" "$NEXUS_PASS"

    log_info ""
    log_info "--- [Maven] ---"
    check_maven_repositories  "$NEXUS_URL" "$NEXUS_USER" "$NEXUS_PASS"

    log_info ""
    log_info "--- [npm] ---"
    enable_npm_realm      "$NEXUS_URL" "$NEXUS_USER" "$NEXUS_PASS"
    create_proxy_repo     "$NEXUS_URL" "$NEXUS_USER" "$NEXUS_PASS" \
                          npm "$NPM_PROXY_REPO_NAME" "$NPM_REMOTE_URL"
    create_hosted_repo    "$NEXUS_URL" "$NEXUS_USER" "$NEXUS_PASS" \
                          npm "$NPM_HOSTED_REPO_NAME"

    log_info ""
    log_info "--- [PyPI] ---"
    create_proxy_repo     "$NEXUS_URL" "$NEXUS_USER" "$NEXUS_PASS" \
                          pypi "$PYPI_PROXY_REPO_NAME" "$PYPI_REMOTE_URL"
    create_hosted_repo    "$NEXUS_URL" "$NEXUS_USER" "$NEXUS_PASS" \
                          pypi "$PYPI_HOSTED_REPO_NAME"

    log_info ""
    log_info "--- [Go] ---"
    create_proxy_repo     "$NEXUS_URL" "$NEXUS_USER" "$NEXUS_PASS" \
                          go "$GO_PROXY_REPO_NAME" "$GO_REMOTE_URL"
    # go-hosted は再デプロイを許可（同一バージョンのモジュール更新に対応）
    create_hosted_repo    "$NEXUS_URL" "$NEXUS_USER" "$NEXUS_PASS" \
                          go "$GO_HOSTED_REPO_NAME" "allow"

    log_info ""
    log_info "--- [Docker] ---"
    enable_docker_realm       "$NEXUS_URL" "$NEXUS_USER" "$NEXUS_PASS"
    create_docker_proxy_repo  "$NEXUS_URL" "$NEXUS_USER" "$NEXUS_PASS" \
                              "$DOCKER_REPO_NAME" "$DOCKER_HTTP_PORT" "$DOCKER_REMOTE_URL"

    log_info ""
    log_success "セットアップ完了！"

	call_show_finish_banner
}

main "$@"
