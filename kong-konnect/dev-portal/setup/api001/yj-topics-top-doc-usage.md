## 🚀 使い方 (Usage Guide)

このAPIは、Kong Gatewayを経由してYahoo!ニュースの主要トピックスをRSS（XML形式）で提供します。
Kongによるルーティングとプロキシ動作の検証、およびRSSパースのテストに最適です。

---

### 1. エンドポイント情報

| 項目 | 内容 |
| :--- | :--- |
| **Method** | `GET` |
| **URL** | `http://localhost:8000/yjnews/v1/topics/top` |
| **Format** | `application/xml` |

---

### 2. 基本的なリクエスト方法

ターミナルから以下の `curl` コマンドを実行して、最新のトピックスを取得します。

```bash
# 基本のリクエスト（詳細ログ付き）
curl -v http://localhost:8000/yjnews/v1/topics/top
```
