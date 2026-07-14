# Sonatype Nexus リポジトリマネージャー体験

[![GitHub License](https://img.shields.io/github/license/Toshiharu-Konuma-sti/my-skilling?style=flat-square)](https://github.com/Toshiharu-Konuma-sti/my-skilling/blob/main/LICENSE)
[![GitHub last commit](https://img.shields.io/github/last-commit/Toshiharu-Konuma-sti/my-skilling?style=flat-square)](https://github.com/Toshiharu-Konuma-sti/my-skilling/commits/main)
[![Docker](https://img.shields.io/badge/Docker-Container-blue?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com/)
[![Sonatype Nexus](https://img.shields.io/badge/Sonatype-Nexus-1B1C30?style=flat-square&logo=sonatype&logoColor=white)](https://www.sonatype.com/products/sonatype-nexus-repository)
[![Java](https://img.shields.io/badge/Java-21-ED8B00?style=flat-square&logo=openjdk&logoColor=white)](https://openjdk.org/)
[![Gradle](https://img.shields.io/badge/Gradle-02303A?style=flat-square&logo=gradle&logoColor=white)](https://gradle.org/)
[![Maven](https://img.shields.io/badge/Apache%20Maven-C71A36?style=flat-square&logo=apachemaven&logoColor=white)](https://maven.apache.org/)
[![JavaScript](https://img.shields.io/badge/JavaScript-Node.js-339933?style=flat-square&logo=nodedotjs&logoColor=white)](https://nodejs.org/)
[![npm](https://img.shields.io/badge/npm-CB3837?style=flat-square&logo=npm&logoColor=white)](https://www.npmjs.com/)
[![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)](https://www.python.org/)
[![pip](https://img.shields.io/badge/pip-PyPI-3775A9?style=flat-square&logo=pypi&logoColor=white)](https://pypi.org/)
[![uv](https://img.shields.io/badge/uv-Astral-DE5FE9?style=flat-square)](https://docs.astral.sh/uv/)
[![Go](https://img.shields.io/badge/Go-00ADD8?style=flat-square&logo=go&logoColor=white)](https://go.dev/)

---

## 目次

1. [はじめに](#1-はじめに)
2. [環境説明](#2-環境説明)
3. [体験環境の構築手順](#3-体験環境の構築手順)
   - [3-1. コンテナ構築](#3-1-コンテナ構築)
   - [3-2. Nexus 初期設定](#3-2-nexus-初期設定)
4. [体験](#4-体験)
   - [4-1. Java (Gradle)](#4-1-java-gradle)
   - [4-2. Java (Maven)](#4-2-java-maven)
   - [4-3. JavaScript (npm)](#4-3-javascript-npm)
   - [4-4. Python (pip)](#4-4-python-pip)
   - [4-5. Python (uv)](#4-5-python-uv)
   - [4-6. Go (modules)](#4-6-go-modules)
   - [4-7. Docker](#4-7-docker)
5. [清掃手順](#5-清掃手順)
6. [ビルドツール別 リポジトリマネージャー接続設定リファレンス](#6-ビルドツール別-リポジトリマネージャー接続設定リファレンス)
   - [言語・ツール別 Nexus リポジトリ名一覧](#言語ツール別-nexus-リポジトリ名一覧)
   - [HTTP 接続・認証情報送信ポリシーの比較](#http-接続認証情報送信ポリシーの比較)
   - [6-1. Java (Gradle)](#6-1-java-gradle)
   - [6-2. Java (Maven)](#6-2-java-maven)
   - [6-3. JavaScript (npm)](#6-3-javascript-npm)
   - [6-4. Python (pip)](#6-4-python-pip)
   - [6-5. Python (uv)](#6-5-python-uv)
   - [6-6. Go (modules)](#6-6-go-modules)
   - [6-7. Docker](#6-7-docker)

---

## 1. はじめに

[Sonatype Nexus Repository](https://www.sonatype.com/products/sonatype-nexus-repository) を使い、**リポジトリマネージャー（アーティファクトリー）** の役割と使い方を体験するためのハンズオン環境です。

各言語・ビルドツールから Nexus をリモートリポジトリとして参照し、依存関係のパッケージを Nexus 経由で取得する体験ができます。Nexus のプロキシリポジトリにパッケージがキャッシュされる様子を確認することで、リポジトリマネージャーがどのように機能するかを実感できます。

| 体験できること |
| :--- |
| Nexus をリモートリポジトリとして各言語のビルドツールから参照する |
| 各言語における認証情報（ユーザー名・パスワード）の設定方法を理解する |
| Nexus のプロキシリポジトリにパッケージがキャッシュされる仕組みを理解する |
| Docker Hub のイメージを Nexus 経由で取得する |

---

## 2. 環境説明

<img src="./image/hands-on-sonatype-nexus_overview.png" width="600">

体験を進める環境は以下の通りです。

| コンテナ | 用途 | アクセス URL |
| :--- | :--- | :--- |
| Nexus Repository Manager | リポジトリマネージャー本体 | http://nexus.local:8081 |

Nexus には以下のリポジトリが構築されます。

| リポジトリ名 | 種別 | 用途 |
| :--- | :--- | :--- |
| `maven-central` | proxy | Maven Central のプロキシ |
| `maven-public` | group | Maven リポジトリのグループ（Gradle / Maven から利用） |
| `npm-proxy` | proxy | npmjs.org のプロキシ |
| `pypi-proxy` | proxy | PyPI のプロキシ |
| `go-proxy` | proxy | proxy.golang.org のプロキシ |
| `docker-hub-proxy` | proxy | Docker Hub のプロキシ（port: `8085`） |

> **`nexus.local` を使用する理由**: `localhost`（`127.0.0.1`）を使わず `/etc/hosts` でカスタムホスト名を割り当てている理由は、**各ビルドツールの HTTP セキュリティポリシーを正確に体験・検証するため**です。  
> npm・Gradle など一部のビルドツールは `localhost` / `127.0.0.1` をループバックアドレスとして特別扱いし、HTTP 接続でも認証情報の送信を無条件に許可します。  
> `nexus.local` のようなカスタムドメインを使うことで、すべてのツールが「外部のリモートホスト」として認識し、それぞれの HTTP セキュリティポリシー（`allowInsecureProtocol`・`always-auth`・`insecure-registries` など）が正しく適用される状態を再現できます。

---

## 3. 体験環境の構築手順

### 3-1. コンテナ構築

1. リポジトリを取得します。

   ```bash
   $ mkdir -p ~/handson/
   $ cd ~/handson/
   $ git clone <repository-url>
   $ cd ~/handson/sonatype-nexus/
   ```

2. `container/` ディレクトリに移り、コンテナ作成前の事前準備スクリプトを実行します。

   `/etc/hosts` へのドメイン追記と `/etc/docker/daemon.json` の設定（HTTP レジストリの許可）を行います。

   ```bash
   $ cd ~/handson/sonatype-nexus/container/
   $ sudo sh BEFORE_CREATE_CONTAINER.sh
   ```

3. 続けてコンテナを起動します。

   ```bash
   $ docker compose up -d
   ```

### 3-2. Nexus 初期設定

`setup/` ディレクトリに移り、以下のスクリプトを順番に実行します。

```bash
$ cd ~/handson/sonatype-nexus/setup/
```

1. admin の初期パスワードを変更します。

   ```bash
   $ sh step01_NEXUS_CHANGE_ADMIN_PASSWORD.sh
   ```

2. 各言語向けのリポジトリを作成します。

   ```bash
   $ sh step02_NEXUS_CREATE_REPOSITORY.sh
   ```

   - 実行内容は [step02_NEXUS_CREATE_REPOSITORY.sh](setup/step02_NEXUS_CREATE_REPOSITORY.sh) の `main()` 関数に書かれているコメントを確認してください。

   | セクション | 処理内容 |
   | :--- | :--- |
   | [Docker] | Docker Bearer Token Realm の有効化・Docker Hub プロキシリポジトリの作成 |
   | [Maven] | `maven-central` / `maven-public` リポジトリの存在確認 |
   | [npm] | npm Token Realm の有効化・npm プロキシリポジトリの作成 |
   | [PyPI] | PyPI プロキシリポジトリの作成 |
   | [Go] | Go プロキシリポジトリの作成 |

---

## 4. 体験

体験用のディレクトリに移ります。

```bash
$ cd ~/handson/sonatype-nexus/try-my-hand/
```

各言語の接続設定ファイルを確認し、Nexus の URL・認証情報が正しいことを確認してから実行してください。

### 4-1. Java (Gradle)

`java-gradle/` は Spring Boot を使わないシンプルな Java アプリで、Nexus 経由のビルドを体験できます。

```bash
$ cd java-gradle/
$ sh BUILD.sh
```

- 接続設定: [gradle.properties](try-my-hand/java-gradle/gradle.properties)

| 設定項目 | 説明 |
| :--- | :--- |
| `repoManagerUrl` | Nexus のベース URL |
| `repoManagerUsername` | 認証ユーザー名 |
| `repoManagerPassword` | 認証パスワード |

### 4-2. Java (Maven)

`java-maven/` は Spring Boot を使わないシンプルな Java アプリで、Nexus 経由のビルドを体験できます。

```bash
$ cd java-maven/
$ sh BUILD.sh
```

- 接続設定: [settings.xml](try-my-hand/java-maven/settings.xml)
- Maven の `<mirror>` によりすべてのリポジトリリクエストが Nexus 経由にルーティングされます。

### 4-3. JavaScript (npm)

```bash
$ cd js-npm/
$ npm install
$ node app.js
```

- 接続設定: [.npmrc](try-my-hand/js-npm/.npmrc)

| 設定項目 | 説明 |
| :--- | :--- |
| `registry` | Nexus の npm プロキシリポジトリ URL |
| `_auth` | `echo -n "user:pass" \| base64` で生成した Base64 認証情報 |

### 4-4. Python (pip)

```bash
$ cd python-pip/
$ sh BUILD.sh
```

- 接続設定: [pip.conf](try-my-hand/python-pip/pip.conf)
- `PIP_CONFIG_FILE` 環境変数でプロジェクトローカルの設定ファイルを参照しています。

### 4-5. Python (uv)

```bash
$ cd python-uv/
$ sh BUILD.sh
```

- 接続設定: [uv.toml](try-my-hand/python-uv/uv.toml)
- `[[index]]` セクションに Nexus の PyPI プロキシ URL を設定します。

### 4-6. Go (modules)

```bash
$ cd go-modules/
$ sh BUILD.sh
```

- 接続設定: [go-proxy.conf](try-my-hand/go-modules/go-proxy.conf)

> **Note**: Go 1.21+ はセキュリティ上 HTTP プロキシへの認証情報送信を禁止しているため、`BUILD.sh` がローカル HTTPS リバースプロキシ（[nexus_go_proxy.py](try-my-hand/go-modules/nexus_go_proxy.py)）を起動して HTTPS ブリッジ経由で Nexus にアクセスします。

### 4-7. Docker

Docker Hub のイメージを Nexus の `docker-hub-proxy` 経由で取得する体験は [try-my-hand/docker/README.md](try-my-hand/docker/README.md) を参照してください。

---

## 5. 清掃手順

1. `container/` ディレクトリに移ります。

   ```bash
   $ cd ~/handson/sonatype-nexus/container/
   ```

2. コンテナを停止してリソースを削除します。

   ```bash
   $ docker compose down -v
   ```

3. `/etc/hosts` から `nexus.local` のエントリを削除します。

   ```bash
   $ sudo sed -i '/nexus\.local/d' /etc/hosts
   ```

---

## 6. ビルドツール別 リポジトリマネージャー接続設定リファレンス

各ビルドツールで Nexus リポジトリマネージャーを利用する際の **「設定箇所」** を整理したリファレンスです。  
ローカル実行（`BUILD.sh`）と CI/CD（`.gitlab-ci.yml`）の両方を記載します。

### 言語・ツール別 Nexus リポジトリ名一覧

| 言語 / ツール | プロキシリポジトリ（ビルド時） | ホステッドリポジトリ（パブリッシュ時） |
| :--- | :--- | :--- |
| Java (Gradle) | `maven-public` | `maven-releases` |
| Java (Maven) | `maven-public` | `maven-releases` |
| JavaScript (npm) | `npm-proxy` | `npm-hosted` |
| Python (pip) | `pypi-proxy` | `pypi-hosted` |
| Python (uv) | `pypi-proxy` | `pypi-hosted` |
| Go (modules) | `go-proxy` | ※ Git タグ（Nexus に hosted なし） |
| Docker | `docker-hub-proxy` | ※ 本環境では Docker hosted は対象外 |

### HTTP 接続・認証情報送信ポリシーの比較

本環境の Nexus は **HTTP**（HTTPS なし）で動作しています。  
各ビルドツールの HTTP に対する挙動は「**HTTP 接続自体の可否**」と「**HTTP 経由での認証情報送信の可否**」の 2 つの観点で異なります。

| 言語 / ツール | HTTP 接続 | 認証情報の HTTP 送信 | 必要な対応 |
| :--- | :--- | :--- | :--- |
| Java (Gradle) | **ブロック** | ─（HTTP 許可で送信可） | `allowInsecureProtocol = true` で HTTP 接続を許可 |
| Java (Maven) | **可能** | **可能** | 特別な設定不要 |
| JavaScript (npm) | **可能** | **ブロック** | `always-auth = true` で HTTP 接続でも認証情報を送信許可 |
| Python (pip) | **可能** | **可能** | 信頼できないサイトは `trusted-host` で SSL 検証スキップが必要 |
| Python (uv) | **可能** | **可能** | 特別な設定不要 |
| Go (modules) | **可能** | **ブロック** | HTTP 接続を許可する方法なし<br>（HTTPS ブリッジ（`nexus_go_proxy.py`）で回避） |
| Docker | **ブロック** | ─（HTTP 許可で送信可） | `insecure-registries` に登録して HTTP 接続を許可 |

---

### 6-1. Java (Gradle)

#### ビルド時（依存関係の取得）

| 区分 | 設定ファイル | 設定内容 |
| :--- | :--- | :--- |
| ローカル | [`try-my-hand/java-gradle/gradle.properties`](try-my-hand/java-gradle/gradle.properties) | `repoManagerUrl` / `repoManagerUsername` / `repoManagerPassword` で Nexus 接続先を指定 |
| CI/CD | [`try-my-hand/java-gradle/.gitlab-ci.yml`](try-my-hand/java-gradle/.gitlab-ci.yml) | `-PrepoManagerUrl` / `-PrepoManagerUsername` / `-PrepoManagerPassword` フラグで上書き |

[`try-my-hand/java-gradle/build.gradle`](try-my-hand/java-gradle/build.gradle) の `repositories { }` ブロックがプロパティを参照して Nexus `maven-public` プロキシグループを向きます。

```groovy
// build.gradle
repositories {
    maven {
        url "${repoManagerUrl}/repository/maven-public/"
        allowInsecureProtocol = true   // Gradle 7+: HTTP URL を許可するために必須
        credentials {
            username = repoManagerUsername
            password = repoManagerPassword
        }
    }
}
```

> **HTTP 許可設定（`allowInsecureProtocol = true`）**: Gradle 7+ はデフォルトで HTTP URL への認証情報送信をブロックします。  
> `repositories {}` と `publishing.repositories {}` の **両方**に指定が必要です。  
> 指定がない場合、ビルド時に `Using insecure protocols with repositories...` エラーが発生します。

#### パブリッシュ時（成果物のアップロード）

| 区分 | 設定ファイル | 設定内容 |
| :--- | :--- | :--- |
| CI/CD | [`try-my-hand/java-gradle/build.gradle`](try-my-hand/java-gradle/build.gradle) | `publishing.repositories.maven.url` でアップロード先 `maven-releases` を指定 |

```groovy
// build.gradle
publishing {
    repositories {
        maven {
            url = version.endsWith('SNAPSHOT')
                ? "${repoManagerUrl}/repository/maven-snapshots/"
                : "${repoManagerUrl}/repository/maven-releases/"
            allowInsecureProtocol = true   // Gradle 7+: HTTP URL を許可するために必須
        }
    }
}
```

---

### 6-2. Java (Maven)

#### ビルド時（依存関係の取得）

| 区分 | 設定ファイル | 設定内容 |
| :--- | :--- | :--- |
| ローカル | [`try-my-hand/java-maven/settings.xml`](try-my-hand/java-maven/settings.xml) | `<mirror>` で全リポジトリを Nexus `maven-public` 経由にルーティング |
| CI/CD | [`try-my-hand/java-maven/settings-ci.xml`](try-my-hand/java-maven/settings-ci.xml) | 同上。ミラー URL に `${env.NEXUS_URL}` を使用し、GitLab CI 変数から注入 |

```xml
<!-- settings-ci.xml -->
<mirror>
  <id>repo-manager</id>
  <mirrorOf>*</mirrorOf>
  <url>${env.NEXUS_URL}/repository/maven-public/</url>
</mirror>
```

> **HTTP について**: Maven は HTTP エンドポイントへの認証情報送信をデフォルトで許可しています。  
> `<mirror>` に `<blocked>false</blocked>` を明示する形式も使えますが、デフォルト値が `false` のため省略可能です。

#### パブリッシュ時（成果物のアップロード）

| 区分 | 設定ファイル | 設定内容 |
| :--- | :--- | :--- |
| ローカル / CI/CD | [`try-my-hand/java-maven/pom.xml`](try-my-hand/java-maven/pom.xml) | `<distributionManagement>` でアップロード先を定義。CI では `-Dnexus.url` で URL を上書き |

```xml
<!-- pom.xml -->
<distributionManagement>
  <repository>
    <id>nexus-releases</id>
    <url>${nexus.url}/repository/maven-releases/</url>
  </repository>
</distributionManagement>
```

---

### 6-3. JavaScript (npm)

#### ビルド時（依存関係の取得）

| 区分 | 設定ファイル | 設定内容 |
| :--- | :--- | :--- |
| ローカル | [`try-my-hand/js-npm/.npmrc`](try-my-hand/js-npm/.npmrc) | `registry` に Nexus `npm-proxy` URL、`_auth` に Base64 認証情報を設定 |
| CI/CD | [`try-my-hand/js-npm/.gitlab-ci.yml`](try-my-hand/js-npm/.gitlab-ci.yml) | `before_script` で `.npmrc` を動的生成（`echo -n user:pass \| base64` でエンコード） |

```ini
# .npmrc（ローカル）
registry=http://nexus.local:8081/repository/npm-proxy/
//nexus.local:8081/repository/npm-proxy/:_auth=YWRtaW46cGFzc3dvcmQ=
always-auth=true
```

> **`always-auth = true` の役割**: npm はデフォルトでは HTTPS エンドポイントにのみ認証情報を送信します。  
> HTTP の Nexus に対して `Authorization` ヘッダを送るには `always-auth = true` が必須です。  
> この設定がない場合、Nexus が 401 を返し `npm install` が失敗します。

#### パブリッシュ時（成果物のアップロード）

| 区分 | 設定ファイル | 設定内容 |
| :--- | :--- | :--- |
| CI/CD | [`try-my-hand/js-npm/.gitlab-ci.yml`](try-my-hand/js-npm/.gitlab-ci.yml) | `publish` ジョブの `before_script` で `registry` を `npm-hosted` に切り替えた `.npmrc` を生成後、`npm publish` を実行 |

```yaml
# .gitlab-ci.yml（publish ジョブの before_script 概略）
- echo "registry=${NEXUS_URL}/repository/npm-hosted/" > .npmrc
- echo "//host:port/repository/npm-hosted/:_auth=..." >> .npmrc
script:
  - npm publish
```

---

### 6-4. Python (pip)

#### ビルド時（依存関係の取得）

| 区分 | 設定ファイル | 設定内容 |
| :--- | :--- | :--- |
| ローカル | [`try-my-hand/python-pip/pip.conf`](try-my-hand/python-pip/pip.conf) | `index-url` に認証情報込みの Nexus `pypi-proxy` Simple API URL を指定。[[`BUILD.sh`](try-my-hand/python-pip/BUILD.sh) で `PIP_CONFIG_FILE` を介して読み込み |
| CI/CD | [`try-my-hand/python-pip/.gitlab-ci.yml`](try-my-hand/python-pip/.gitlab-ci.yml) | `--index-url "http://user:pass@host/repository/pypi-proxy/simple/"` と `--trusted-host` を pip install に指定 |

```ini
# pip.conf（ローカル）
[global]
index-url = http://admin:password@nexus.local:8081/repository/pypi-proxy/simple/
trusted-host = nexus.local
```

> **CI での認証の考え方**: `--index-url` に認証情報を URL 埋め込みで渡します。  
> pip は HTTP であっても URL 中の user:pass から `Authorization` ヘッダを構築するため、認証が通ります。  
> `--trusted-host` は HTTP サーバーに対する SSL 証明書検証をスキップするための設定です（HTTP なので検証自体は不要ですが、pip の内部チェックを通過させるために必要）。

#### パブリッシュ時（成果物のアップロード）

| 区分 | 設定ファイル | 設定内容 |
| :--- | :--- | :--- |
| CI/CD | [`try-my-hand/python-pip/setup.cfg`](try-my-hand/python-pip/setup.cfg) | パッケージメタデータ（name / version）を定義 |
| CI/CD | [`try-my-hand/python-pip/.gitlab-ci.yml`](try-my-hand/python-pip/.gitlab-ci.yml) | `python -m build` でビルド後、`twine upload --repository-url` で `pypi-hosted` へアップロード |

```yaml
# .gitlab-ci.yml（publish ジョブ概略）
script:
  - python -m build
  - twine upload
      --repository-url "${NEXUS_URL}/repository/pypi-hosted/"
      --username "${NEXUS_USER}"
      --password "${NEXUS_PASS}"
      dist/*
```

---

### 6-5. Python (uv)

#### ビルド時（依存関係の取得）

| 区分 | 設定ファイル | 設定内容 |
| :--- | :--- | :--- |
| ローカル | [`try-my-hand/python-uv/uv.toml`](try-my-hand/python-uv/uv.toml) | `[[index]]` セクションの `url` に認証情報込みの Nexus `pypi-proxy` URL を設定、`default = true` で既定インデックスに指定 |
| CI/CD | [`try-my-hand/python-uv/.gitlab-ci.yml`](try-my-hand/python-uv/.gitlab-ci.yml) | `UV_DEFAULT_INDEX` 環境変数で `uv.toml` の設定を上書き |

```toml
# uv.toml（ローカル）
[[index]]
url = "http://admin:password@nexus.local:8081/repository/pypi-proxy/simple/"
default = true
```

> **HTTP について**: uv は HTTP URL への credentials 送信をデフォルトで許可しています。  
> `[[index]]` の `url` に `http://user:pass@host/...` 形式で記述するだけで認証が有効になります。

> **注意**: CI では `UV_INDEX_URL`（旧形式）ではなく `UV_DEFAULT_INDEX` を使用します。  
> `uv.toml` の `[[index]]` 形式に対応する上書き変数は `UV_DEFAULT_INDEX` です。

#### パブリッシュ時（成果物のアップロード）

| 区分 | 設定ファイル | 設定内容 |
| :--- | :--- | :--- |
| CI/CD | [`try-my-hand/python-uv/pyproject.toml`](try-my-hand/python-uv/pyproject.toml) | `[project]` セクションにパッケージメタデータ、`[build-system]` にビルドバックエンドを定義 |
| CI/CD | [`try-my-hand/python-uv/.gitlab-ci.yml`](try-my-hand/python-uv/.gitlab-ci.yml) | `uv build` でビルド後、`uv publish --publish-url` で `pypi-hosted` へアップロード |

```yaml
# .gitlab-ci.yml（publish ジョブ概略）
script:
  - uv build
  - uv publish
      --publish-url "${NEXUS_URL}/repository/pypi-hosted/"
      --username "${NEXUS_USER}"
      --password "${NEXUS_PASS}"
```

---

### 6-6. Go (modules)

#### ビルド時（依存関係の取得）

> **制約**: Go 1.21+ はセキュリティ上、HTTP エンドポイントへの認証情報送信を拒否します。  
> ローカル・CI/CD ともに [`nexus_go_proxy.py`](try-my-hand/go-modules/nexus_go_proxy.py) による **HTTPS ブリッジ** を経由して Nexus にアクセスします。

```
Go コマンド (HTTPS)
  → nexus_go_proxy.py (localhost:18444 / 自己署名証明書)
    → Nexus go-proxy (HTTP)
```

| 区分 | 設定ファイル | 設定内容 |
| :--- | :--- | :--- |
| ローカル | [`try-my-hand/go-modules/BUILD.sh`](try-my-hand/go-modules/BUILD.sh) | `openssl` で自己署名証明書を生成 → `nexus_go_proxy.py` を起動 → `GOPROXY` に `https://user:pass@localhost:PORT/...` を設定 |
| CI/CD | [`try-my-hand/go-modules/.gitlab-ci.yml`](try-my-hand/go-modules/.gitlab-ci.yml) | `before_script` で同様のブリッジを起動。`SSL_CERT_FILE` に CA バンドルを指定して Go が自己署名証明書を信頼できるようにする |

```yaml
# .gitlab-ci.yml（build ジョブの before_script 概略）
- apt-get install -y python3
- openssl req -x509 ...         # 自己署名証明書を生成
- python3 nexus_go_proxy.py 18444 "${NEXUS_URL}" cert key &
- export GOPROXY="https://user:pass@localhost:18444/repository/go-proxy/,direct"
- export GONOSUMDB="*"
- export SSL_CERT_FILE="/tmp/ca-bundle.crt"
```

#### パブリッシュ時（Git タグの作成）

> **補足**: Nexus は **Go ホステッドリポジトリを提供していません**。  
> Go モジュールの配布は Maven/npm/PyPI のようなバイナリアップロードではなく、  
> **VCS のバージョンタグ** が配布単位です（`go get module@v0.0.1` の `v0.0.1` が git タグに対応）。

| 区分 | 設定ファイル | 設定内容 |
| :--- | :--- | :--- |
| CI/CD | [`try-my-hand/go-modules/VERSION`](try-my-hand/go-modules/VERSION) | パブリッシュするバージョン番号（`v0.0.1` 形式）を管理。再実行時はこのファイルのバージョンを更新する |
| CI/CD | [`try-my-hand/go-modules/.gitlab-ci.yml`](try-my-hand/go-modules/.gitlab-ci.yml) | `publish` ジョブが `VERSION` を読み取り git タグを作成。`GITLAB_TOKEN`（PAT）でタグを GitLab へ push |

```yaml
# .gitlab-ci.yml（publish ジョブ概略）
script:
  - VERSION=$(cat VERSION)
  - git tag "${VERSION}"
  - git push "http://oauth2:${GITLAB_TOKEN}@${GITLAB_HOST}/..." "${VERSION}"
```

`GITLAB_TOKEN` は [`try-my-hand/step02_GITLAB_CREATE_GROUP.sh`](try-my-hand/step02_GITLAB_CREATE_GROUP.sh) が `write_repository` スコープの Personal Access Token を作成し、GitLab グループ CI/CD 変数として登録します。

---

### 6-7. Docker

#### イメージ取得時（`docker pull`）

Docker クライアントは、HTTP レジストリへのアクセスをデフォルトで拒否します。  
Nexus の `docker-hub-proxy` は HTTP（port: `8085`）で動作しているため、Docker デーモンへの明示的な許可設定が必要です。

| 区分 | 設定ファイル / 手順 | 設定内容 |
| :--- | :--- | :--- |
| ローカル | `/etc/docker/daemon.json` | `insecure-registries` に Nexus Docker レジストリアドレスを登録し Docker デーモンを再起動 |
| ローカル | `docker login` コマンド | Nexus レジストリへのログイン（認証情報をクライアントに保存） |
| CI/CD | [`try-my-hand/docker/.gitlab-ci.yml`](try-my-hand/docker/.gitlab-ci.yml) | `before_script` で `daemon.json` を生成・Docker デーモン再起動後、`docker login` を実行 |

```json
// /etc/docker/daemon.json
{
  "insecure-registries": [
    "nexus.local:8085"
  ]
}
```

> **`insecure-registries` の役割**: Docker デーモンはデフォルトで HTTPS 接続のみを許可します。  
> HTTP レジストリ（ここでは `nexus.local:8085`）へのアクセスを許可するには `insecure-registries` に登録し、Docker デーモンを再起動する必要があります。  
> 本環境ではこの設定を [`container/BEFORE_CREATE_CONTAINER.sh`](container/BEFORE_CREATE_CONTAINER.sh) が自動で行います。

```sh
# Nexus レジストリへのログイン
docker login nexus.local:8085 -u admin -p password

# イメージ取得（Nexus の docker-hub-proxy 経由）
docker pull nexus.local:8085/alpine:latest
```

> **レジストリの指定方法**: `docker pull` のイメージ名先頭に `<registry-host>:<port>/` を付けることで取得先レジストリを指定します。  
> 通常の `docker pull alpine:latest` は Docker Hub に直接アクセスしますが、  
> `docker pull nexus.local:8085/alpine:latest` とすることで Nexus の `docker-hub-proxy` 経由で取得されます。

#### パブリッシュ時（`docker push`）

> **補足**: 本環境では Docker ホステッドリポジトリは構築対象外です。  
> `docker push` を Nexus 経由で行う場合は、Nexus に `docker-hosted` タイプのリポジトリを別途作成し、専用ポートを割り当てる必要があります。
