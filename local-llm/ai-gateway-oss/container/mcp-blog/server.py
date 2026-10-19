"""SIOS Tech Lab ブログ (WordPress REST API) を MCP ツールとして公開するリモート MCP サーバー。"""
import html
import os
import re

import httpx
from mcp.server.fastmcp import FastMCP
from mcp.server.transport_security import TransportSecuritySettings

BLOG_API = os.environ.get("BLOG_API", "https://tech-lab.sios.jp/wp-json/wp/v2")
MAX_CHARS = 4000

# コンテナ間通信では Host が mcp-blog:3005 になるため、DNS rebinding 保護 (localhost 限定) は無効にする
mcp = FastMCP(
    "blog",
    host="0.0.0.0",
    port=int(os.environ.get("PORT", "3005")),
    transport_security=TransportSecuritySettings(enable_dns_rebinding_protection=False),
)


def to_text(raw: str) -> str:
    return html.unescape(re.sub(r"<[^>]+>", "", raw)).strip()


def fetch(path: str, params: dict) -> dict | list:
    # 既定の python-httpx の User-Agent だとブログ側の WAF に 403 で拒否されるため明示する
    res = httpx.get(
        f"{BLOG_API}{path}",
        params=params,
        headers={"User-Agent": "mcp-blog-demo/1.0"},
        timeout=15,
        follow_redirects=True,
    )
    res.raise_for_status()
    return res.json()


@mcp.tool()
def list_posts(count: int = 5) -> list[dict]:
    """最新のブログ記事の一覧 (id、公開日、タイトル、URL、抜粋) を新しい順に返す。count は 1〜20。"""
    posts = fetch(
        "/posts",
        {"per_page": max(1, min(count, 20)), "_fields": "id,date,title,link,excerpt"},
    )
    return [
        {
            "id": p["id"],
            "date": p["date"],
            "title": to_text(p["title"]["rendered"]),
            "link": p["link"],
            "excerpt": to_text(p["excerpt"]["rendered"]),
        }
        for p in posts
    ]


@mcp.tool()
def get_post(id: int) -> dict:
    """記事 id を指定して、1 件のブログ記事 (タイトル、公開日、URL、本文) を返す。本文は 4000 文字まで。"""
    p = fetch(f"/posts/{id}", {"_fields": "id,date,title,link,content"})
    body = to_text(p["content"]["rendered"])
    return {
        "id": p["id"],
        "date": p["date"],
        "title": to_text(p["title"]["rendered"]),
        "link": p["link"],
        "content": body[:MAX_CHARS] + ("…(省略)" if len(body) > MAX_CHARS else ""),
    }


if __name__ == "__main__":
    mcp.run(transport="streamable-http")
