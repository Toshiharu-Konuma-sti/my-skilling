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
   - [3-1. AI プロキシのテスト](#3-1-ai-プロキシのテスト)
   - [3-2. MCP プロキシのテスト](#3-2-mcp-プロキシのテスト)
4. [プラグイン動作確認チェックポイント](#4-プラグイン動作確認チェックポイント)
   - [4-1. ai-rate-limiting-advanced: トークン流量制限](#4-1-ai-rate-limiting-advanced-トークン流量制限)
5. [清掃手順](#5-清掃手順)

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

Kong Konnectにアクセスして事前準備をします。

1. AI Gateway として使用する「Control Plane（CP）」を作り、リージョンと CP 名を手元に控えておきます。

1. 「Personal Access Token（PAT）」を発行して手元に控えておきます。

ローカル環境で事前準備をします。

1. Docker をインストールします。
   - 参考: [初期環境構築: Docker Engine on Ubuntu](https://github.com/Toshiharu-Konuma-sti/setup-docs-for-hands-on/tree/main/setup-docker-engine-on-ubuntu)

1. decK をインストールします。
   - 参考: [decK（Kong Konnect CLI）](../README.md#deckkong-konnect-cli)

1. 体験用のリポジトリを取得します。

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
| [BEFORE_CREATE_CONTAINER.sh](../common/script/BEFORE_CREATE_CONTAINER.sh) | Kong Data Plane 認証用クライアント証明書の作成と Konnect への登録 |
| [CREATE_CONTAINER.sh](./container/CREATE_CONTAINER.sh) | コンテナの構築（Kong DP + Ollama） |

1. `container/` ディレクトリに移ります。

   ```bash
   $ cd ~/handson/my-skilling/kong-konnect/ai-gateway/container/
   ```

1. 事前準備スクリプトを実行します。初回は Konnect の接続情報の入力を求められます。

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

1. コンテナ構築スクリプトを実行します。

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
   ```
    - 実行内容は [step01_KONG_REGISTER_AI.sh](./setup/step01_KONG_REGISTER_AI.sh) の main() 関数に書かれているコメントを確認してください。

---

## 3. 体験

### 3-1. AI プロキシのテスト

[try-my-hand/testCOMMAND.sh](./try-my-hand/testCOMMAND.sh) は、各 AI プロキシパターンを対話形式で手軽に試せるスクリプトです。

```bash
$ cd ~/handson/my-skilling/kong-konnect/ai-gateway/try-my-hand/
$ ./testCOMMAND.sh
```

起動するとプロキシパターンの選択メニューが表示されます。

```
==================================================
  Kong AI Gateway テスト実行
==================================================

■ プロキシパターンを選択してください:

  [1] ai-proxy-normal          → POST http://localhost:8000/ai/normal/chat
      Ollama llama3.1 へ直接プロキシ
  [2] ai-proxy-ratelimit       → POST http://localhost:8000/ai/ratelimit/chat
      トークン数で流量制限 (500 tokens / 60sec / IP)
  [3] ai-prompt-guard          → POST http://localhost:8000/ai/guard/chat
      PII・プロンプトインジェクション攻撃をブロック
  [4] ai-semantic-prompt-guard → POST http://localhost:8000/ai/semguard/chat
      意味的類似でプロンプトをブロック (inject/jailbreak/危険コンテンツ)
  [5] ai-proxy-semcache        → POST http://localhost:8000/ai/semcache/chat
      類似質問をセマンティックキャッシュで即返却
  [6] ai-prompt-decorator      → POST http://localhost:8000/ai/decorator/chat
      システムプロンプトを強制付与 (関西弁)
  [7] ai-proxy-advanced        → POST http://localhost:8000/ai/advanced/chat
      llama3.1 / phi3:mini ラウンドロビン

番号を入力してください [1-7]:
```

番号を選択するとプロンプトの入力を求められます。`[4]` を選択した場合はブロック検証用のデモプリセットも選択できます。  
入力後は、実行される `curl` コマンドが表示されてからリクエストが送信されます。レスポンスは verbose ヘッダーとボディに分けて出力されます。

```
==================================================
  実行コマンド
==================================================
curl -sv \
  -X POST "http://localhost:8000/ai/normal/chat" \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Kong AI Gatewayのメリットを3つ教えて"}]}'
==================================================

⏳ リクエスト送信中...

--- Verbose Output (Request / Response Headers) ---
...
--- Response Body ---
{
  "choices": [ ... ]
}
```

---

### 3-2. MCP プロキシのテスト

[try-my-hand/testMCP_INSPECTOR.sh](./try-my-hand/testMCP_INSPECTOR.sh) は、Kong AI Gateway 経由で MCP サーバーをブラウザから操作できる **MCP Inspector** を起動するスクリプトです。  
対象エンドポイントは `/ai/mcp/sios-techlab`（SIOS Tech Lab MCP サーバー）です。

```bash
$ cd ~/handson/my-skilling/kong-konnect/ai-gateway/try-my-hand/
$ ./testMCP_INSPECTOR.sh
```

Kong DP への疎通確認後、MCP Inspector が起動し以下のような出力が表示されます。

```
  ブラウザで以下の URL を開いてください:
  http://localhost:6274

  接続後、[Connect] ボタンをクリックしてツールを操作できます。
  (終了するには Ctrl+C を押してください)
```

ブラウザで URL を開いたら、以下の手順で操作します。

1. 画面上の **[Connect]** ボタンをクリックして MCP サーバーに接続する
2. **[Tools]** タブを開き、使用するツールを選択して実行する

利用可能なツールは以下のとおりです。

| ツール名 | 説明 |
|---|---|
| `get-articles` | 最新記事一覧の取得（キーワード検索・件数指定・カテゴリ指定可） |
| `get-article-by-id` | 記事 ID を指定して詳細を取得 |

Inspector のポートを変更したい場合は `--port` オプションを指定します。

```bash
$ ./testMCP_INSPECTOR.sh --port 6300
```

---

## 4. プラグイン動作確認チェックポイント

各プラグインの動作を確認するときに注目すべきポイントをまとめます。  
テストには [try-my-hand/testCOMMAND.sh](./try-my-hand/testCOMMAND.sh) を使用します。

---

### 4-1. ai-rate-limiting-advanced: トークン流量制限

`/ai/ratelimit/chat` エンドポイントに対して連続でリクエストを送り、**3回目で HTTP 429 が返ること**を確認します。

#### 注目レスポンスヘッダー

| ヘッダー名 | 意味 |
|---|---|
| `X-AI-RateLimit-Limit-300-llama2` | ウィンドウ（300秒）内の上限トークン数 |
| `X-AI-RateLimit-Remaining-300-llama2` | 残り使用可能トークン数（リクエスト受付**時点**の値） |
| `X-AI-RateLimit-Reset-300-llama2` | ウィンドウがリセットされるまでの秒数（429時のみ） |
| `X-AI-RateLimit-Retry-After-300-llama2` | 何秒後に再試行できるか（429時のみ） |

> **ヘッダー名の読み方**
> ```
> X-AI-RateLimit-Remaining-300-llama2
>                          ^^^  ^^^^^  
>                          │    └── LLMプロバイダー名
>                          └─────── ウィンドウサイズ（秒）
> ```

> **`Remaining` の表示タイミングに注意**  
> `Remaining` はリクエスト受付**時点**（カウンター更新前）の残量が返ります。  
> そのため 1回目のレスポンスでは `Remaining = Limit` と表示されますが、  
> カウンターへの加算は内部で正しく行われており、2回目以降のレスポンスに反映されます。

#### 期待される動作パターン

| 回 | HTTP ステータス | `Remaining` | 説明 |
|:---:|---|---|---|
| 1回目 | `200 OK` | 350（上限と同じ） | 受付時点ではカウンターが空のため、上限値がそのまま返る |
| 2回目 | `200 OK` | 59（例） | 1回目の消費トークン（例: 291）が差し引かれた残量が返る |
| 3回目 | **`429 Too Many Requests`** | 0 | 累計消費トークンが上限（350）を超えたためブロック |

#### 確認コマンド例

```bash
# testCOMMAND.sh で [2] を選択して3回連続送信
cd try-my-hand/
./testCOMMAND.sh   # 1回目 → 200 OK
./testCOMMAND.sh   # 2回目 → 200 OK  (Remaining に残量が表示される)
./testCOMMAND.sh   # 3回目 → 429 Too Many Requests
```

#### 429 レスポンス例

```
< HTTP/1.1 429 Too Many Requests
< X-AI-RateLimit-Limit-300-llama2:       350
< X-AI-RateLimit-Remaining-300-llama2:   0
< X-AI-RateLimit-Reset-300-llama2:       274   ← 274秒後にリセット
< X-AI-RateLimit-Retry-After-300-llama2: 274

{ "message": "AI token rate limit exceeded for provider(s): llama2" }
```

---

## 5. 清掃手順

### Kong Konnect の設定を削除する

Kong Konnect から CP 上の全エンティティ（ルート・サービス・プラグイン）を削除します。

```bash
$ cd ~/handson/my-skilling/kong-konnect/ai-gateway/setup/
$ ./teardn_KONG_CLEANUP_ALL_ENTITIES_IN_CP.sh
```

### コンテナを停止・削除する

```bash
$ cd ~/handson/my-skilling/kong-konnect/ai-gateway/container/
$ ./CREATE_CONTAINER.sh down
```
