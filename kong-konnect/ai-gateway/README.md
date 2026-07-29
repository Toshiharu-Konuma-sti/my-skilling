# Kong AI Gateway 体験

[![GitHub License](https://img.shields.io/github/license/Toshiharu-Konuma-sti/my-skilling?style=flat-square)](https://github.com/Toshiharu-Konuma-sti/my-skilling/blob/main/LICENSE)
[![GitHub last commit](https://img.shields.io/github/last-commit/Toshiharu-Konuma-sti/my-skilling?style=flat-square)](https://github.com/Toshiharu-Konuma-sti/my-skilling/commits/main)
[![Docker](https://img.shields.io/badge/Docker-Container-blue?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com/)
[![Kong](https://img.shields.io/badge/Kong-Konnect-003459?style=flat-square&logo=kong&logoColor=white)](https://konghq.com/products/kong-konnect)
[![Ollama](https://img.shields.io/badge/Ollama-Local%20LLM-black?style=flat-square)](https://ollama.com/)

---

## 目次

1. [はじめに](#1-はじめに)
2. [体験環境の構築手順](#2-体験環境の構築手順)
   - [2-1. 事前準備](#2-1-事前準備)
   - [2-2. コンテナ構築](#2-2-コンテナ構築)
   - [2-3. Kong Konnect 環境設定](#2-3-kong-konnect-環境設定)
3. [体験](#3-体験)
   - [3-1. ai-proxy: 単一モデルへのプロキシ](#3-1-ai-proxy-単一モデルへのプロキシ)
   - [3-2. ai-proxy-advanced: 複数モデルへの負荷分散](#3-2-ai-proxy-advanced-複数モデルへの負荷分散)
4. [清掃手順](#4-清掃手順)

---

## 1. はじめに

Kong Konnect と Ollama（ローカル LLM）を使い、**Kong AI Gateway** の主要機能を体験するための環境です。

SaaS の LLM を一切使わずにローカル環境だけで完結するため、ネットワーク制限がある環境やコスト不要のデモ・学習用途に最適です。

構築する環境の概要は以下のとおりです。

| 項目 | 内容 |
|---|---|
| Kong Data Plane | Konnect に接続する Kong Gateway（コンテナ） |
| Ollama | ローカル LLM サーバー。llama3.1・phi3:mini を提供（コンテナ） |
| AI Proxy プラグイン | 単一モデルへの OpenAI 互換プロキシ |
| AI Proxy Advanced プラグイン | 複数モデルへのラウンドロビン負荷分散プロキシ |

体験できるエンドポイントは以下の2種類です。

| エンドポイント | プラグイン | 動作 |
|---|---|---|
| `POST http://localhost:8000/ai/normal/chat` | ai-proxy | llama3.1 固定 |
| `POST http://localhost:8000/ai/advanced/chat` | ai-proxy-advanced | llama3.1 / phi3:mini をラウンドロビン |

---

## 2. 体験環境の構築手順

### 2-1. 事前準備

#### Kong Konnect での準備

1. AI Gateway に使用する **Control Plane（CP）** を作成し、リージョンと CP 名を手元に控えておきます。
2. **Personal Access Token（PAT）** を発行して手元に控えておきます。

#### ローカル環境での準備

1. **Docker** をインストールします。
   - 参考: [初期環境構築: Docker Engine on Ubuntu](https://github.com/Toshiharu-Konuma-sti/setup-docs-for-hands-on/tree/main/setup-docker-engine-on-ubuntu)

2. **decK**（Kong Konnect CLI）をインストールします。
   - 参考: [https://developer.konghq.com/deck/](https://developer.konghq.com/deck/)

   ```bash
   $ curl -LO https://github.com/Kong/deck/releases/download/v1.55.0/deck_v1.55.0_amd64.deb
   $ sudo dpkg -i ./deck_v1.55.0_amd64.deb
   $ deck version
     decK v1.55.0 (19a389c)
   ```

3. 体験用のリポジトリを取得します。

   ```bash
   $ mkdir -p ~/handson/
   $ cd ~/handson/
   $ git clone https://github.com/Toshiharu-Konuma-sti/my-skilling.git
   $ cd ~/handson/my-skilling/kong-konnect/ai-gateway/
   ```

---

### 2-2. コンテナ構築

`container/` ディレクトリには2つのスクリプトがあります。

| スクリプト | 概要 |
|---|---|
| [BEFORE_CREATE_CONTAINER.sh](./container/BEFORE_CREATE_CONTAINER.sh) | Kong Data Plane 認証用クライアント証明書の作成と Konnect への登録 |
| [CREATE_CONTAINER.sh](./container/CREATE_CONTAINER.sh) | コンテナの構築（Kong DP + Ollama） |

1. `container/` ディレクトリに移ります。

   ```bash
   $ cd ~/handson/my-skilling/kong-konnect/ai-gateway/container/
   ```

2. 事前準備スクリプトを実行します。初回は Konnect の接続情報の入力を求められます。

   ```bash
   $ ./BEFORE_CREATE_CONTAINER.sh

   ⚠️ Konnect Auth file not found: .env-konnect-auth
   ➡️ Create it now? (y/N): y
   🌐 Enter Konnect REGION (us/eu/au/jp): us
   🏢 Enter Target Control Plane Name: my-test-cp001
   🔑 Enter Konnect Personal Access Token:
   ############################################################
   # START SCRIPT
   ############################################################
     :
   ############################################################
   # FINISH SCRIPT (XX seconds)
   ############################################################
   ```

   > 2 回目以降は `.env-konnect-auth` が自動で読み込まれ、入力は不要です。  
   > 接続情報をやり直す場合は `reset` オプションを指定します。
   > ```bash
   > $ ./BEFORE_CREATE_CONTAINER.sh reset
   > ```

3. コンテナ構築スクリプトを実行します。

   ```bash
   $ ./CREATE_CONTAINER.sh
   ```

   起動後、`ollama-init` コンテナが自動的に以下のモデルを Ollama へ pull します。  
   **初回は数分〜数十分かかります**（モデルサイズ: llama3.1 ≒ 4GB、phi3:mini ≒ 2GB）。

   ```bash
   # pull 完了の確認
   $ docker logs ollama-init -f
   ```

---

### 2-3. Kong Konnect 環境設定

Kong Konnect の CP に AI Gateway のルート・サービス・プラグインを登録します。  
設定はエンティティ種別ごとに分離されたマスターファイルで管理されています。

| マスターファイル | 内容 |
|---|---|
| [aigw-service-kng.yaml](./setup/aigw-service-kng.yaml) | Ollama サービス定義 |
| [aigw-route-normal-kng.yaml](./setup/aigw-route-normal-kng.yaml) | `/ai/normal/chat` ルート |
| [aigw-route-advanced-kng.yaml](./setup/aigw-route-advanced-kng.yaml) | `/ai/advanced/chat` ルート |
| [aigw-plugin-ai-proxy-normal-kng.yaml](./setup/aigw-plugin-ai-proxy-normal-kng.yaml) | ai-proxy プラグイン（llama3.1 固定） |
| [aigw-plugin-ai-proxy-advanced-kng.yaml](./setup/aigw-plugin-ai-proxy-advanced-kng.yaml) | ai-proxy-advanced プラグイン（ラウンドロビン） |

1. `setup/` ディレクトリに移ります。

   ```bash
   $ cd ~/handson/my-skilling/kong-konnect/ai-gateway/setup/
   ```

2. Kong Konnect 環境設定スクリプトを実行します。

   ```bash
   $ ./step01_KONG_REGISTER_AI.sh

   ############################################################
   # START SCRIPT
   ############################################################
     :
   🎉 Kong AI Gateway の設定が正常に完了しました！
   --------------------------------------------------
   🤖 [ai-proxy / llama3.1]  POST http://localhost:8000/ai/normal/chat
      model: llama3.1 (fixed)

   🤖 [ai-proxy-advanced]    POST http://localhost:8000/ai/advanced/chat
      model: llama3.1 / phi3:mini (round-robin)
   --------------------------------------------------
   ############################################################
   # FINISH SCRIPT (XX seconds)
   ############################################################
   ```

   > 接続情報をやり直す場合は `reset` オプションを指定します。
   > ```bash
   > $ ./step01_KONG_REGISTER_AI.sh reset
   > ```

---

## 3. 体験

### 3-1. ai-proxy: 単一モデルへのプロキシ

`/ai/normal/chat` エンドポイントは **ai-proxy** プラグインにより、常に **llama3.1** へリクエストを転送します。

```bash
curl -X POST http://localhost:8000/ai/normal/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.1",
    "messages": [
      { "role": "user", "content": "Kong API Gateway の主なメリットを3つ教えてください。" }
    ]
  }'
```

レスポンスの `X-Kong-LLM-Model` ヘッダーで実際に使用されたモデルが確認できます。

```
X-Kong-LLM-Model: ollama/llama3.1
```

---

### 3-2. ai-proxy-advanced: 複数モデルへの負荷分散

`/ai/advanced/chat` エンドポイントは **ai-proxy-advanced** プラグインにより、**llama3.1** と **phi3:mini** へリクエストをラウンドロビンで振り分けます。

Kong がモデルを自動選択するため、`"model"` フィールドの値は何でも構いません。

```bash
curl -X POST http://localhost:8000/ai/advanced/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "any",
    "messages": [
      { "role": "user", "content": "Kong API Gateway の主なメリットを3つ教えてください。" }
    ]
  }'
```

リクエストごとに `X-Kong-LLM-Model` ヘッダーの値が交互に変わることで、負荷分散を確認できます。

```
# 1回目
X-Kong-LLM-Model: ollama/llama3.1

# 2回目
X-Kong-LLM-Model: llama2/phi3:mini
```

---

## 4. 清掃手順

### Kong Konnect の設定を削除する

CP 上の全エンティティ（ルート・サービス・プラグイン）を削除します。

```bash
$ cd ~/handson/my-skilling/kong-konnect/ai-gateway/setup/
$ ./teardn_KONG_CLEANUP_ALL_ENTITIES_IN_CP.sh
```

### コンテナを停止・削除する

```bash
$ cd ~/handson/my-skilling/kong-konnect/ai-gateway/container/
$ ./CREATE_CONTAINER.sh down
```
