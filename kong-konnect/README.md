# Kong Konnect を使ったハンズオン

[![GitHub License](https://img.shields.io/github/license/Toshiharu-Konuma-sti/my-skilling?style=flat-square)](https://github.com/Toshiharu-Konuma-sti/my-skilling/blob/main/LICENSE)
[![GitHub last commit](https://img.shields.io/github/last-commit/Toshiharu-Konuma-sti/my-skilling?style=flat-square)](https://github.com/Toshiharu-Konuma-sti/my-skilling/commits/main)
[![Kong](https://img.shields.io/badge/Kong-Konnect-003459?style=flat-square&logo=kong&logoColor=white)](https://konghq.com/products/kong-konnect)

---

## 目次

1. [ハンズオン一覧](#1-ハンズオン一覧)
2. [ツールのインストール手順](#2-ツールのインストール手順)
   - [decK（Kong Konnect CLI）](#deckkong-konnect-cli)
   - [npx](#npx)

---

## 1. ハンズオン一覧

| ハンズオン | 概要 |
|---|---|
| [Kong API Gateway 体験](./api-gateway/) | Keycloak と連携した OAuth 2.1 認可フロー（Authorization Code / Client Credentials）の体験環境です。 |
| [Kong AI Gateway 体験](./ai-gateway/) | Ollama（ローカル LLM）を使った AI Gateway の構築と体験。AI Proxy / AI Proxy Advanced プラグインを試せます。 |
| [Kong Dev Portal 体験](./dev-portal/) | Kong Konnect の Dev Portal 機能を使った API カタログ公開の体験環境です。 |

---

## 2. ツールのインストール手順

本ハンズオンを実施する際に必要なツールのインストール手順を紹介します。

### decK（Kong Konnect CLI）

Kong Konnect の設定を宣言的に管理するための CLI ツールです。全ハンズオンで使用します。

- 参考: [https://developer.konghq.com/deck/](https://developer.konghq.com/deck/)

```bash
$ curl -LO https://github.com/Kong/deck/releases/download/v1.55.0/deck_v1.55.0_amd64.deb
$ sudo dpkg -i ./deck_v1.55.0_amd64.deb

# インストール確認
$ deck version
decK v1.55.0 (19a389c)
```

### npx

Node.js パッケージを直接実行するためのツールです。一部のハンズオンで使用します。

```bash
$ sudo apt install -y npm

# インストール確認
$ npx --version
```
