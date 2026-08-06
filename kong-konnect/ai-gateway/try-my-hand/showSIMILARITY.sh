#!/bin/bash
# =============================================================================
# Kong AI Gateway - セマンティックキャッシュ 類似度確認スクリプト
# Redis FT.SEARCH (KNN) + Ollama embeddings を使い、
# 入力プロンプトとキャッシュ済みエントリのコサイン類似度を表示する
#
# 実行方式: redis-stack コンテナ内の Python 3 で動作
#   - Redis  : localhost:6379 (コンテナ内からアクセス)
#   - Ollama : ollama:11434  (intra-net 経由でアクセス)
# → ホスト側に redis-py 等の追加パッケージ不要
#
# Usage:
#   ./showSIMILARITY.sh "Kong AI Gatewayのメリットを3つ教えて"
#   ./showSIMILARITY.sh   # プロンプト未指定時は対話入力
# =============================================================================

EMBEDDING_MODEL="nomic-embed-text"
REDIS_CONTAINER="redis-stack"
THRESHOLD="0.15"
KNN_K="5"

# --- プロンプト取得 ---
if [[ -n "$1" ]]; then
  PROMPT="$1"
else
  echo ""
  read -rp "類似度を調べるプロンプトを入力してください: " PROMPT
  if [[ -z "${PROMPT}" ]]; then
    echo "❌ プロンプトが入力されていません"
    exit 1
  fi
fi

# --- redis-stack コンテナ内の Python 3 で実行 ---
docker exec -i "${REDIS_CONTAINER}" python3 - \
  "${PROMPT}" "${EMBEDDING_MODEL}" "${THRESHOLD}" "${KNN_K}" << 'PYEOF'
import sys, json, struct, socket, urllib.request, urllib.error

def get_embedding(prompt, model):
    url  = "http://ollama:11434/v1/embeddings"
    data = json.dumps({"model": model, "input": prompt}).encode()
    req  = urllib.request.Request(url, data=data,
                                  headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())["data"][0]["embedding"]

# ─── 最小限の RESP2 クライアント ──────────────────────────────────────────
class Redis:
    def __init__(self, host="localhost", port=6379):
        self.s   = socket.create_connection((host, port), timeout=10)
        self.buf = b""

    def close(self): self.s.close()

    def _readline(self):
        while b"\r\n" not in self.buf:
            self.buf += self.s.recv(4096)
        i = self.buf.index(b"\r\n")
        line, self.buf = self.buf[:i], self.buf[i+2:]
        return line

    def _readn(self, n):
        while len(self.buf) < n + 2:
            self.buf += self.s.recv(65536)
        data, self.buf = self.buf[:n], self.buf[n+2:]
        return data

    def _parse(self):
        line = self._readline()
        t, rest = chr(line[0]), line[1:]
        if t == '+': return rest.decode()
        if t == '-': raise RuntimeError(rest.decode())
        if t == ':': return int(rest)
        if t == '$':
            n = int(rest)
            return None if n == -1 else self._readn(n).decode(errors="replace")
        if t == '*':
            n = int(rest)
            return None if n == -1 else [self._parse() for _ in range(n)]
        raise RuntimeError(f"Unknown RESP type: {t}")

    def cmd(self, *args):
        parts = f"*{len(args)}\r\n".encode()
        for a in args:
            if isinstance(a, bytes):
                parts += f"${len(a)}\r\n".encode() + a + b"\r\n"
            else:
                s = str(a).encode()
                parts += f"${len(s)}\r\n".encode() + s + b"\r\n"
        self.s.sendall(parts)
        return self._parse()
# ──────────────────────────────────────────────────────────────────────────

def main():
    prompt    = sys.argv[1]
    emb_model = sys.argv[2]
    threshold = float(sys.argv[3])
    knn_k     = int(sys.argv[4])

    # 1. embedding 取得
    print(f"\n🔍 プロンプト: {prompt}")
    print(f"⏳ Ollama ({emb_model}) でベクトル生成中 ...")
    try:
        embedding = get_embedding(prompt, emb_model)
    except urllib.error.URLError as e:
        print(f"❌ Ollama 接続エラー: {e}"); sys.exit(1)
    vec_bytes = struct.pack(f"{len(embedding)}f", *embedding)
    print(f"   ✅ {len(embedding)} 次元ベクトル取得完了")

    # 2. Redis 接続
    try:
        r = Redis("localhost", 6379)
    except Exception as e:
        print(f"❌ Redis 接続エラー: {e}"); sys.exit(1)

    # 3. エントリのあるインデックスを取得
    indices    = r.cmd("FT._LIST") or []
    active_idx = None
    for idx in indices:
        info = r.cmd("FT.INFO", idx)
        if isinstance(info, list):
            try:
                nd_pos = info.index("num_docs")
                if int(info[nd_pos + 1]) > 0:
                    active_idx = idx; break
            except (ValueError, IndexError):
                pass

    if not active_idx:
        print("\n📭 キャッシュにエントリがありません。")
        print("   先にリクエストを1件送信してキャッシュを作成してください。")
        r.close(); return

    print(f"   📦 インデックス: {active_idx}")

    # 4. KNN 検索
    result = r.cmd(
        "FT.SEARCH", active_idx,
        f"*=>[KNN {knn_k} @vector $vec AS score]",
        "PARAMS", "2", "vec", vec_bytes,
        "SORTBY", "score", "ASC",
        "RETURN", "1", "score",
        "DIALECT", "2"
    )

    total = result[0] if result else 0
    if total == 0:
        print("\n📭 類似エントリが見つかりませんでした。"); r.close(); return

    # 5. 結果表示
    print(f"\n{'─'*65}")
    print(f"  Redis キャッシュとの類似度 (上位 {min(total, knn_k)} 件)")
    print(f"  threshold: {threshold}  (cosine distance ≤ {threshold} → Hit)")
    print(f"{'─'*65}")

    i = 1; rank = 1
    while i < len(result) and rank <= knn_k:
        key    = result[i] if isinstance(result[i], str) else str(result[i])
        fields = result[i+1] if i+1 < len(result) else []
        i += 2

        score = None
        if isinstance(fields, list):
            for j in range(0, len(fields)-1, 2):
                if fields[j] == "score":
                    score = float(fields[j+1]); break
        if score is None:
            rank += 1; continue

        similarity = (1.0 - score) * 100
        verdict    = "✅ Hit " if score <= threshold else "❌ Miss"

        # payload からレスポンス冒頭を取得
        preview = ""
        try:
            raw = r.cmd("JSON.GET", key, "$.payload")
            if raw and raw != "null":
                payload_list = json.loads(raw)
                payload = json.loads(payload_list[0]) if payload_list else {}
                content = payload.get("choices",[{}])[0]\
                                 .get("message",{}).get("content","")
                preview = content[:70].replace("\n", " ")
                if len(content) > 70: preview += "..."
        except Exception:
            pass

        print(f"\n  #{rank}")
        print(f"    cosine distance  : {score:.4f}")
        print(f"    cosine similarity: {similarity:.1f}%")
        print(f"    判定 (threshold={threshold}): {verdict}")
        if preview:
            print(f"    cached response  : {preview}")
        print(f"    cache key hash   : {key.split(':')[-1][:32]}...")
        rank += 1

    print(f"\n{'─'*65}\n")
    r.close()

main()
PYEOF
