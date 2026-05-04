# Entra ID & MSAL 認証プロセス体験 with Java

[![GitHub License](https://img.shields.io/github/license/Toshiharu-Konuma-sti/my-skilling?style=flat-square)](https://github.com/Toshiharu-Konuma-sti/my-skilling/blob/main/LICENSE)
[![GitHub last commit](https://img.shields.io/github/last-commit/Toshiharu-Konuma-sti/my-skilling?style=flat-square)](https://github.com/Toshiharu-Konuma-sti/my-skilling/commits/main)
[![Docker](https://img.shields.io/badge/Docker-Container-blue?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com/)
[![Microsoft Entra ID](https://img.shields.io/badge/Microsoft-Entra%20ID-0078D4?style=flat-square&logo=microsoft&logoColor=white)](https://www.microsoft.com/en-us/security/business/identity-access/microsoft-entra-id)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-6DB33F?style=flat-square&logo=spring-boot&logoColor=white)](https://spring.io/projects/spring-boot)

---

## 目次

1. [はじめに](#1-はじめに)
2. [環境説明](#2-環境説明)
	- 2-1. [コンテナ環境](#2-1-コンテナ環境)
	- 2-2. [Spring Initializr Settings](#2-2-spring-initializr-settings)
3. [体験環境の構築手順](#3-体験環境の構築手順)
	- 3-1. [事前準備](#3-1-事前準備)
	- 3-2. [コンテナ構築](#3-2-コンテナ構築)
4. [体験](#4-体験)
	- 4-1. [Authorization Code Grant](#4-1-authorization-code-grant)
      - 4-1-1. [トークン取得](#4-1-1-トークン取得)
      - 4-1-2. [Redis 管理のセッション削除](#4-1-2-redis-管理のセッション削除)
	- 4-2. [Client Credentials Grant](#4-2-client-credentials-grant)
      - 4-2-1. [トークン取得](#4-2-1-トークン取得)
5. [実装の解説](#5-実装の解説)
	- 5-1. [事前準備](#5-1-事前準備)
	- 5-2. [トークン取得処理の実装](#5-2-トークン取得処理の実装)
      - 5-2-1. [Authorization Code Grant 向け](#5-2-1-authorization-code-grant-向け)
      - 5-2-2. [Client Credentials Grant 向け](#5-2-2-client-credentials-grant-向け)

---

## 1. はじめに

Microsoft Entra ID と MSAL (Microsoft Authentication Library) を使い、Spring Boot 環境でトークン取得の実装を体験します。本来複雑な Authorization Code Grant のシーケンスが、MSAL を利用することでいかに簡潔な実装で完結するかを、実際のアプリケーション動作を通じて体系的に確認することができます。

体験を進めるアーキテクチャは、以下図の薄赤エリア「API利用者による Access Token 取得までのフロー」です。

| Authorization Code Grant with PEP | Client Credentials Grant |
| :--- | :--- |
| <img src="./image/api-gw-auth-arch-5-auth-code-api-gw-pep.png" width="400"> | <img src="./image/api-gw-auth-arch-7-client-cred.png" width="400"> |

## 2. 環境説明

### 2-1. コンテナ環境

体験を進める環境は以下の通りです。

<img src="./image/ms-entra-id-free-msal_overview.png" width="600">

体験時にアクセスする URL は以下の通りです。

| Container | URL |
| :--- | :--- |
| webapp for Authorization Code Grant with PEP | http://localhost:8080/hands-on/authorization-code |
| webapp for Client Credentials Grant | http://localhost:8080/hands-on/client-credentials |
| Redis Insight | http://localhost:8001 |

### 2-2. Spring Initializr Settings

https://start.spring.io/

| Item | webapp |
| :--- | :--- |
| **Project** | Gradle - Groovy |
| **Language** | Java |
| **Spring Boot** | 4.0.5 |
| **Group** | jp.sios |
| **Artifact** | apisl.handson.entraid.msal |
| **Packaging** | Jar |
| **Configuration** | YAML |
| **Java** | 21 |
| **Dependencies** | Spring Web<br>Spring Boot DevTools<br>OAuth2 Client<br>Thymeleaf |

## 3. 体験環境の構築手順

### 3-1. 事前準備

Entra ID Free 版で事前準備をします。

1. Entra ID Free 版にアカウントを作り、テナントID、およびクライアントIDとシークレットを準備します。
   - [初期環境構築: Entra ID Free](https://github.com/Toshiharu-Konuma-sti/setup-docs-for-hands-on/tree/main/setup-entra-id-free)

ローカル環境で事前準備をします。

1. dockerをインストールします。
   - [初期環境構築: Docker Engine on Ubuntu](https://github.com/Toshiharu-Konuma-sti/setup-docs-for-hands-on/tree/main/setup-docker-engine-on-ubuntu)

1. 体験用のリポジトリを取得します。

    ```
	$ mkdir -p ~/handson/
    $ cd ~/handson/
    ```
    ```
    $ git clone https://github.com/Toshiharu-Konuma-sti/my-skilling.git
	$ cd ~/handson/my-skilling/ms-entra-id-free/msal/
    ```

### 3-2. コンテナ構築

1. コンテナ構築用のディレクトリに移ります。スクリプトは2つあるため実行前に処理概要を理解します。

    ```
	$ cd ~/handson/my-skilling/ms-entra-id-free/msal/container/
    ```
	- [CREATE_CONTAINER.sh](./container/CREATE_CONTAINER.sh)：コンテナを構築します。

1. コンテナ構築スクリプトを実行します。体験で利用するEntra IDのテナントID、クライアントID、クライアントシークレットを求められたら入力します。

    ```
	$ ./CREATE_CONTAINER.sh

	############################################################
	# START SCRIPT
	############################################################
	⚠️ Configuration file not found: ~/handson/my-skilling/ms-entra-id-free/msal/container/.env-entraid
	➡️ Create it now? (y/N): y
	🏢 Enter ENTRA_TENANT_ID: 12345678-89ab-cdef-ghijk-lmnopqrstuv
	🤖 Enter ENTRA_CLIENT_ID: wxay1234-5678-90ab-cdefg-hijklmnopqr
	🔑 Enter ENTRA_CLIENT_SECRET: ************************************
	  :
    ```

## 4. 体験

### 4-1. Authorization Code Grant

#### 4-1-1. トークン取得

1. 体験用の Web アプリケーションにアクセスします。
   - http://localhost:8080/hands-on/authorization-code

1. ブラウザが IdP (Entra ID) からトークンを発行されていないセッションの場合は、Spring Boot がデフォルトで持っているログインを促す画面が表示されるので、ログインへ遷移するリンクをクリックします。

   <img src="./image/demo_001.png" width="600">

1. Microsoft のサインイン画面で Entra ID で管理している ID を入力します。

   <img src="./image/demo_002.png" width="600">

1. パスキーの選択を求められたら選択します。（パスワード認証などの場合には、流れに従ってください）

   <img src="./image/demo_003.png" width="600">

1. iPhone や Android などのデバイスを選択した場合には、デバイスにインストールされている「Microsoft Authenticator」アプリで表示された QR コードを読み込んでサインインします。

   <img src="./image/demo_004.png" width="600">

1. デバイスで QR コードを読み込むと、デバイスと接続できた表示に切り替わりますので、デバイス側で認証処理を進めます。

   <img src="./image/demo_005.png" width="600">

1. デバイスで認証処理が完了し、セッション維持の確認が表示されたらサインインは成功です。

   <img src="./image/demo_006.png" width="600">

1. アクセス許可を確認された場合には、内容を確認して「承諾」をクリックします。

   <img src="./image/demo_007.png" width="600">

1. 体験用の Web アプリが表示されると同時に、Access Token や ID Token が取得されています。

   <img src="./image/demo_008.png" width="600">

1. 各種トークンを「JWT Decoder（検証用）」へコピペで貼り付けて中身を確認します。

   <img src="./image/demo_009.png" width="600">

1. ブラウザの開発者ツールを開きネットワークを確認できるようにします。

   <img src="./image/demo_010.png" width="600">

1. 画面右上の「Relaod」ボタンをクリックしても、既に Redis でトークンを管理している Cookie と紐づいているセッションであるため、継続して Web アプリが表示されることが確認できます。

   <img src="./image/demo_011.png" width="600">

1. 画面右上の「Logout」ボタンをクリックすると、Spring Boot がデフォルトで持っているログアウトを促す画面が表示されるので、「Log Out」ボタンをクリックしてログアウトします。トークンを管理している Cookie が無効化されます。

   <img src="./image/demo_012.png" width="600">

1. 再度ログインを促す画面が表示されましたが、開発者ツールのネットワークで遷移してきた URL を見ると、ログアウトした後に Web アプリへ遷移するが、セッションがログアウトしているのでログイン画面に誘導されていることが確認できます。ここで再度ログインへ遷移するリンクをクリックします。

   <img src="./image/demo_013.png" width="600">

1. 再度、Web アプリへ遷移してきましたが、ブラウザのセッションが既に IdP とのログイン状態が保てているためサインインフローが省略されています。ただし、開発者ツールのネットワークでは、認可 EP（エンドポイント）で認可コードを得て、トークン EP で認可コードと引き換えに Access Token を始めとするトークンを取得しています。

   <img src="./image/demo_014.png" width="600">

#### 4-1-2. Redis 管理のセッション削除

1. ブラウザで新たなタブを立ち上げて Redis へアクセスします。
   - http://localhost:8001

1. 画面中央の「+ Add Redis database」ボタンをクリックします。

   <img src="./image/demo_101.png" width="600">

1. 接続 URL の「127.0.0.1」を「redis」に差し替えた「redis://default@127.0.0.1:6379」にて「Add database」をクリックして接続します。

   <img src="./image/demo_102.png" width="600">

1. 「redis:6379」のDatabase Aliasをクリックして遷移します。

   <img src="./image/demo_103.png" width="600">

1. 現在表示されている Web アプリのセッションが管理されていることを確認できます。

   <img src="./image/demo_104.png" width="600">

1. レコードの右端にあるごみ箱アイコンをクリックしてレコードを削除します。

   <img src="./image/demo_105.png" width="600">

1. Web アプリに戻り「Reload」をクリックすると、トークンを管理している Redis レコードが削除されているため、ログインを促す画面にリダイレクトされます。

   <img src="./image/demo_106.png" width="600">

### 4-2. Client Credentials Grant

#### 4-2-1. トークン取得

1. 体験用の Web アプリケーションにアクセスします。
   - http://localhost:8080/hands-on/client-credentials

1. 体験用の Web アプリが表示されると同時に、Access Token が取得されています。

   <img src="./image/demo_201.png" width="600">

1. 開発者ツールのネットワークを表示しながら「Reload」をクリックして確認できるように、Client Credentials Grant の場合にはユーザ認証は介在しないので、ブラウザで IdP との連携が無くてもトークンが取得できていることが確認できます。

   <img src="./image/demo_202.png" width="600">


## 5. 実装の解説

### 5-1. 事前準備

1. 「build.gradle」に Entra ID と OAuth 連携するライブラリの依存を追記します。
   - [build.gradle](https://github.com/Toshiharu-Konuma-sti/my-skilling/blob/0b0fa21aae35cc20e9da625782970edde5cf448b/ms-entra-id-free/msal/webapp/build.gradle#L30)

1. 「build.gradle」に Redis の利用とセッションを管理するライブラリの依存を追記します。
   - [build.gradle](https://github.com/Toshiharu-Konuma-sti/my-skilling/blob/0b0fa21aae35cc20e9da625782970edde5cf448b/ms-entra-id-free/msal/webapp/build.gradle#L31-L32)

### 5-2. トークン取得処理の実装

#### 5-2-1. Authorization Code Grant 向け

1. 「application.yaml」に連携する IdP の設定を追記します。
   - [application.yaml](https://github.com/Toshiharu-Konuma-sti/my-skilling/blob/0b0fa21aae35cc20e9da625782970edde5cf448b/ms-entra-id-free/msal/webapp/src/main/resources/application.yaml#L5-L21)

1. 「application.yaml」にセッションが連携する Redis の設定を追記します。
   - [application.yaml](https://github.com/Toshiharu-Konuma-sti/my-skilling/blob/0b0fa21aae35cc20e9da625782970edde5cf448b/ms-entra-id-free/msal/webapp/src/main/resources/application.yaml#L27-L36)

1. 「SecurityConfig.java」を新規に実装します。
   - [SecurityConfig.java](./webapp/src/main/java/jp/sios/apisl/handson/entraid/msal/config/SecurityConfig.java)

1. Controllerにトークンを取得する処理を追加実装します。
   - [HandsonController.java](https://github.com/Toshiharu-Konuma-sti/my-skilling/blob/0b0fa21aae35cc20e9da625782970edde5cf448b/ms-entra-id-free/msal/webapp/src/main/java/jp/sios/apisl/handson/entraid/msal/controller/HandsonController.java#L35)：IdP からトークンを発行してもらう複雑なシーケンスから管理までを担います。
   - [HandsonController.java](https://github.com/Toshiharu-Konuma-sti/my-skilling/blob/0b0fa21aae35cc20e9da625782970edde5cf448b/ms-entra-id-free/msal/webapp/src/main/java/jp/sios/apisl/handson/entraid/msal/controller/HandsonController.java#L39-L42)：処理に使うためにトークンを取得します。

#### 5-2-2. Client Credentials Grant 向け

1. 「application.yaml」に IdP の設定を追記します。
   - [application.yaml](https://github.com/Toshiharu-Konuma-sti/my-skilling/blob/0b0fa21aae35cc20e9da625782970edde5cf448b/ms-entra-id-free/msal/webapp/src/main/resources/application.yaml#L5-L14)：IdP で利用しているテナントを設定します。
   - [application.yaml](https://github.com/Toshiharu-Konuma-sti/my-skilling/blob/0b0fa21aae35cc20e9da625782970edde5cf448b/ms-entra-id-free/msal/webapp/src/main/resources/application.yaml#L22-L25)：Client Credentials Grantに特化した値を設定します。

1. Controllerにトークンを取得する処理を追加実装します。
   - [HandsonController.java](https://github.com/Toshiharu-Konuma-sti/my-skilling/blob/0b0fa21aae35cc20e9da625782970edde5cf448b/ms-entra-id-free/msal/webapp/src/main/java/jp/sios/apisl/handson/entraid/msal/controller/HandsonController.java#L57-L69)
