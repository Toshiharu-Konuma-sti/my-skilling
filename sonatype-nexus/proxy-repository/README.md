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
   - [3-2. コンテナ構築](#3-2-コンテナ構築)
   - [3-3. Nexus 初期設定](#3-3-nexus-初期設定)
4. [体験](#4-体験)
   - [4-1. リモートリポジトリを介したローカルビルド](#4-1-リモートリポジトリを介したローカルビルド)
     - [4-1-1. Java (Gradle)](#4-1-1-java-gradle)
     - [4-1-2. Java (Maven)](#4-1-2-java-maven)
     - [4-1-3. JavaScript (npm)](#4-1-3-javascript-npm)
     - [4-1-4. Python (pip)](#4-1-4-python-pip)
     - [4-1-5. Python (uv)](#4-1-5-python-uv)
     - [4-1-6. Go (modules)](#4-1-6-go-modules)
     - [4-1-7. Docker](#4-1-7-docker)
5. [清掃手順](#5-清掃手順)
6. [ビルドツール別 リポジトリマネージャー接続設定リファレンス](#6-ビルドツール別-リポジトリマネージャー接続設定リファレンス)
   - [HTTP 接続・認証情報送信ポリシーの比較](#http-接続認証情報送信ポリシーの比較)
   - [言語・ツール別 Nexus リポジトリ名一覧](#言語ツール別-nexus-リポジトリ名一覧)
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

> **`nexus.local` を使用する理由**:  
> `localhost`（`127.0.0.1`）を使わず `/etc/hosts` でカスタムホスト名を割り当てている理由は、**各ビルドツールの HTTP セキュリティポリシーを正確に体験・検証するため**です。  
> npm・Gradle など一部のビルドツールは `localhost` / `127.0.0.1` をループバックアドレスとして特別扱いし、HTTP 接続（非 HTTPS 接続）でも認証情報の送信を無条件に許可します。  
> `nexus.local` のようなカスタムドメインを使うことで、すべてのツールが「外部のリモートホスト」として認識し、それぞれの HTTP セキュリティポリシー（`allowInsecureProtocol`・`always-auth`・`insecure-registries` など）が正しく適用される状態を再現します。

---

## 3. 体験環境の構築手順

### 3-1. リポジトリ取得

1. リポジトリを取得します。

   ```bash
   $ mkdir -p ~/handson/
   $ cd ~/handson/
   $ git clone <repository-url>
   ```

### 3-2. コンテナ構築

`container/` ディレクトリに移り、以下のスクリプトを順番に実行します。

```bash
$ cd ~/development/my-skilling/sonatype-nexus/proxy-repository/container/
```

1. コンテナ作成前の事前準備スクリプトを実行します。なお、本コマンドの実行には管理者権限（`sudo`）が必要です。


   ```bash
   $ cd ~/handson/sonatype-nexus/container/
   $ ./BEFORE_CREATE_CONTAINER.sh
     [sudo: authenticate] パスワード: ********
   ```
   - 以下の処理を行います。
     - `/etc/hosts` へカスタムドメインの追記
     - `/etc/docker/daemon.json` の設定（HTTP レジストリの許可）
     - Docker デーモンの再起動（`deamon.json` の反映）

1. 続けてコンテナを起動します。

   ```bash
   $ ./CREATE_CONTAINER.sh
   ```

### 3-3. Nexus 初期設定

`setup/` ディレクトリに移り、以下のスクリプトを順番に実行します。

```bash
$ cd ~/development/my-skilling/sonatype-nexus/proxy-repository/setup/
```

1. admin の初期パスワードを変更します。

   ```bash
   $ sh step01_NEXUS_CHANGE_ADMIN_PASSWORD.sh
   ```
   - 変更後のパスワードは [container/variables.sh#L9-L10](/Toshiharu-Konuma-sti/my-skilling/blob/191594e31dd620b359dbc4317e81d34a98a2994e/sonatype-nexus/proxy-repository/container/variables.sh#L9-L10) を確認してください。

2. 各言語向けのリポジトリを作成します。

   ```bash
   $ sh step02_NEXUS_CREATE_REPOSITORY.sh
   ```

   - 「Settings > Security > Realms」で Realm を有効化します。
     - Docker Bearer Token Realm
     - npm Bearer Token Realm

   - デフォルトで用意されているリポジトリの存在を確認します。

     | Name | Format | Type |
     | :--- | :--- | :--- |
     | maven-central | maven2 | proxy |
     | maven-public | maven2 | group |


   - リポジトリを新規で作成します。

     | Name | Format | Type | Proxy > Remote storage | 備考 |
     | :--- | :--- | :--- | :--- | :--- |
     | docker-hub-proxy | docker | proxy | https://registry-1.docker.io | ─ |
     | npm-proxy | npm | proxy | https://registry.npmjs.org | ─ |
     | npm-hosted | npm | hosted | ─ | ─ |
     | pypi-proxy | pypi | proxy | https://pypi.org | ─ |
     | pypi-hosted | pypi | hosted | ─ | ─ |
     | go-proxy | go | proxy | https://proxy.golang.org | ─ |

---

## 4. 体験

体験用のディレクトリに移ります。

```bash
$ cd ~/development/my-skilling/sonatype-nexus/proxy-repository/try-my-hand/
```

各言語の接続設定ファイルを確認し、Nexus の URL・認証情報が正しいことを確認してから実行してください。

### 4-1. リモートリポジトリを介したローカルビルド

#### 4-1-1. Java (Gradle)

`java-gradle/` は Spring Boot を使わないシンプルな Java アプリで、Nexus のリモートリポジトリ経由で依存関係の取得とビルドを体験できます。

```bash
$ cd java-gradle/
$ sh BUILD.sh
```

- リモートリポジトリの接続設定は、[6-1. Java (Gradle)](#6-1-java-gradle) を確認してください。
- ビルド実行後にキャッシュされたリモートリポジトリは、以下 URL で確認できます。
  - http://localhost:8081/#browse/browse:maven-central

#### 4-1-2. Java (Maven)

`java-maven/` は Spring Boot を使わないシンプルな Java アプリで、Nexus のリモートリポジトリ経由で依存関係の取得とビルドを体験できます。

```bash
$ cd java-maven/
$ sh BUILD.sh
```

- リモートリポジトリの接続設定は、[6-2. Java (Maven)](#6-2-java-maven) を確認してください。
- ビルド実行後にキャッシュされたリモートリポジトリは、以下 URL で確認できます。
  - http://localhost:8081/#browse/browse:maven-central


#### 4-1-3. JavaScript (npm)

`js-npm/` は JavaScript アプリで、Nexus のリモートリポジトリ経由で依存関係の取得とビルドを体験できます。

```bash
$ cd js-npm/
$ npm install
$ node app.js
```

- リモートリポジトリの接続設定は、[.npmrc](try-my-hand/js-npm/.npmrc) を確認してください。

  | 設定項目 | 説明 |
  | :--- | :--- |
  | `registry` | Nexus の npm リモートリポジトリ URL |
  | `_auth` | `$ echo -n "user:pass" \| base64` で生成した Base64 認証情報 |
  - 「`_auth`」を記載する行頭の「`//`」はコメントアウトではなく、プロトコル（`http`, `https`）を問わないを意味ます。

- ビルド実行後にキャッシュされたリモートリポジトリは、以下 URL で確認できます。
  - http://localhost:8081/#browse/browse:npm-proxy

#### 4-1-4. Python (pip)

`python-pip/` は Python アプリで、標準ツールの `pip` を使い、Nexus のリモートリポジトリ経由で依存関係の取得と実行を体験できます。

```bash
$ cd python-pip/
$ sh BUILD.sh
```

- リモートリポジトリの接続設定は、[pip.conf](try-my-hand/python-pip/pip.conf) を確認してください。

  | 設定項目 | 説明 |
  | :--- | :--- |
  | `index-url` | Nexus の npm リモートリポジトリ URL |
  - 簡略化のため `index-url` 内に `http(s)://{username}:{password}@host/`」形式で認証情報を埋めているが、実運用では `~/.netrc` の設定を推奨します。

- `PIP_CONFIG_FILE` 環境変数で、設定ファイル（接続設定を含む）のパスを参照しています。

- ビルド実行後にキャッシュされたリモートリポジトリは、以下 URL で確認できます。
  - http://localhost:8081/#browse/browse:pypi-proxy

#### 4-1-5. Python (uv)

`python-uv/` は Python アプリで、Rust製の高速パッケージ管理ツール `uv` を使い、Nexus のリモートリポジトリ経由で依存関係の取得と実行を体験できます。

```bash
$ cd python-uv/
$ sh BUILD.sh
```

- リモートリポジトリの接続設定は、[uv.toml](try-my-hand/python-uv/uv.toml) を確認してください。
  | 設定項目 | 説明 |
  | :--- | :--- |
  | `[[index]] > url` | Nexus の npm リモートリポジトリ URL |
  - 簡略化のため `url` 内に `http(s)://{username}:{password}@host/`」形式で認証情報を埋めているが、実運用では `~/.netrc` の設定を推奨します。

- ビルド実行後にキャッシュされたリモートリポジトリは、以下 URL で確認できます。
  - http://localhost:8081/#browse/browse:pypi-proxy

#### 4-1-6. Go (modules)

`go-modules/` は Go アプリで、Nexus のリモートリポジトリ経由で依存関係の取得とビルドを体験できます。

```bash
$ cd go-modules/
$ sh BUILD.sh
$ sh BUILD.sh ano
```

- リモートリポジトリの設定情報は、[BUILD.sh](try-my-hand/go-modules/BUILD.sh)
で `GOPROXY` 環境変数への設定を確認してください。
  - 簡略化のため `GOPROXY` 内に `http(s)://{username}:{password}@host/`」形式で認証情報を埋めているが、実運用では `~/.netrc` の設定を推奨します。

- HTTPS ブリッジ: [nexus_go_proxy.py](try-my-hand/go-modules/nexus_go_proxy.py)

  > **Note**: Go 1.21+ はセキュリティ上 HTTP への認証情報送信を禁止しています。認証情報を使って Nexus にアクセスするには HTTPS で送信が必要なため、`BUILD.sh` は **HTTPS ブリッジ** を経由して Nexus に接続します。一方、Nexus リポジトリを匿名アクセス可能な設定にすれば、認証情報なしの HTTP で接続が可能なため、`GOPROXY` に Nexus の HTTP URL を指定して接続します（`BUILD.sh ano` がこの方式で動作します）。

- ビルド実行後にキャッシュされたリモートリポジトリは、以下 URL で確認できます。
  - http://localhost:8081/#browse/browse:go-proxy


### 4-1-7. Docker

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

> **認証情報にユーザー名・パスワードを使う理由**  
> エンタープライズの実践では、実際のパスワードを直接使わず、専用の **ユーザートークン** を発行・使用するのがベストプラクティスです。  
> しかし、Nexus の **ユーザートークン機能（User Tokens）は Pro（有償版）専用の機能** であり、本環境で使用している **OSS（無償版）では利用できません**。  
> そのため、本ハンズオン環境ではユーザー名（`admin`）とパスワード（`password`）による Basic 認証を採用しています。

### HTTP 接続・認証情報送信ポリシーの比較

本環境の Nexus は **HTTP**（HTTPS なし）で動作しています。  
各ビルドツールの HTTP に対する挙動は「**HTTP 接続自体の可否**」と「**HTTP 経由での認証情報送信の可否**」の 2 つの観点で異なります。

| 言語 / ツール | HTTP 接続 | 認証情報の HTTP 送信 | 必要な対応 |
| :--- | :--- | :--- | :--- |
| Java (Gradle) | **ブロック** | ─（HTTP 許可で送信可） | `allowInsecureProtocol = true` で HTTP 接続を許可 |
| Java (Maven) | **ブロック** | **可能** | HTTP 接続を許可するルールを定義<br>（`maven-default-http-blocker` ルールを上書きする） |
| JavaScript (npm) | **可能** | **ブロック** | `always-auth = true` で HTTP 接続でも認証情報を送信許可 |
| Python (pip) | **ブロック** | ─（HTTP 許可で送信可） | `trusted-host` にドメイン指定し HTTP 通信を許可 |
| Python (uv) | **可能** | **可能** | 特別な設定不要 |
| Go (modules) | **可能**| **ブロック** | HTTP 接続で認証情報を送信許可する方法なし<br>（本環境は HTTPS ブリッジ（`nexus_go_proxy.py`）で回避） |
| Docker | **ブロック** | ─（HTTP 許可で送信可） | `insecure-registries` にドメイン指定し HTTP 接続を許可 |

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

---

### 6-1. Java (Gradle)

#### ビルド時（依存関係の取得）

| 区分 | 設定ファイル | 設定内容 |
| :--- | :--- | :--- |
| ローカル | [`java-gradle/gradle.properties`](try-my-hand/java-gradle/gradle.properties) | [`java-gradle/build.gradle`](try-my-hand/java-gradle/build.gradle) のプロパティーを設定<br>- `repoManagerUrl`: Nexus のベース URL<br>- `repoManagerUsername`: 認証ユーザー名<br>- `repoManagerPassword`: 認証パスワード |
| CI/CD | [`java-gradle/.gitlab-ci.yml`](try-my-hand/java-gradle/.gitlab-ci.yml) | `./gradlew clean build` コマンドの以下バラメータでプロパティを上書き<br>- `-PrepoManagerUrl`: Nexus のベース URL<br>- `-PrepoManagerUsername`: 認証ユーザー名<br>- `-PrepoManagerPassword`: 認証パスワード |

- [`java-gradle/build.gradle`](try-my-hand/java-gradle/build.gradle) の `repositories { }` ブロックでプロパティを参照して Nexus のリモートリポジトリ設定します。

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

> **HTTP 許可設定（`allowInsecureProtocol = true`）**:  
> Gradle 7+ はデフォルトで HTTP URL への認証情報送信をブロックします。`repositories {}` と `publishing.repositories {}` の **両方**に指定が必要です。  
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
| ローカル | [`java-maven/settings.xml`](try-my-hand/java-maven/settings.xml) | - `/settings/mirrors/mirror/url`: Nexus のベース URL<br>- `/settings/servers/server/username`: 認証ユーザー名<br>- `/settings/servers/server/password`: 認証パスワード |
| CI/CD | [`java-maven/settings-ci.xml`](try-my-hand/java-maven/settings-ci.xml) | `settings.xml` と同じノードへ以下 GitLab CI/CD 変数から割り当てる<br>- `NEXUS_URL` / `NEXUS_USER` / `NEXUS_PASS` |

- `/settings/mirrors/mirros/id` と `/settings/servers/server/id` の値は一致する必要があります。

```xml
<!-- Maven 3.8.1 以降に標準で組み込まれている隠しルール -->
<mirror>
  <id>maven-default-http-blocker</id>
  <mirrorOf>external:http:*</mirrorOf> <!-- 外部の HTTP リポジトリすべて -->
  <url>http://0.0.0.0/</url>
  <blocked>true</blocked>             <!-- 強制的に遮断（エラー）にする -->
</mirror>

<!-- settings-ci.xml -->
<mirror>
  <id>repo-manager</id>
  <mirrorOf>*</mirrorOf>
  <url>${env.NEXUS_URL}/repository/maven-public/</url>
  <blocked>false</blocked>
</mirror>
```

> **HTTP について**:  
> Maven 3.8.1+ では、標準で組み込まれている `maven-default-http-blocker`（`<mirrorOf>external:http:*</mirrorOf>` + `<blocked>true</blocked>`）により、外部への HTTP リポジトリ接続が強制的に遮断されます。  
> デモ環境では、`repo-manager`（`<mirrorOf>*</mirrorOf>` + `<blocked>false</blocked>`）にて全リポジトリへの接続を許可する定義をして、`maven-default-http-blocker` の隠しルールを打ち消しているため、Nexus へ HTTP 接続ができています。  

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
