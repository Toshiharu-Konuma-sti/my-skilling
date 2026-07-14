#!/usr/bin/env python3
"""
Local HTTPS-to-HTTP transparent reverse proxy for repository manager (go-proxy).

Background:
  Go 1.21+ refuses to send credentials to plain HTTP GOPROXY endpoints.
  This proxy bridges the gap:
    - Accepts HTTPS on localhost (Go sends credentials here via Basic Auth)
    - Forwards the Authorization header as-is to the repository manager HTTP endpoint

Usage:
  python3 nexus_go_proxy.py <local_port> <repo_manager_base_url> <cert_file> <key_file>

Credential flow:
  go-proxy.conf → RUN.sh → GOPROXY URL → Go (HTTPS) → this proxy → Nexus HTTP
"""
import sys, ssl, http.server, urllib.request, urllib.error, signal

if len(sys.argv) != 5:
    print(f"Usage: {sys.argv[0]} <local_port> <repo_manager_base_url> <cert_file> <key_file>",
          file=sys.stderr)
    sys.exit(1)

LOCAL_PORT          = int(sys.argv[1])
REPO_MANAGER_URL    = sys.argv[2]   # e.g. http://nexus.local:8081
CERT_FILE           = sys.argv[3]
KEY_FILE            = sys.argv[4]


class TransparentProxyHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        target = REPO_MANAGER_URL + self.path

        # Go が HTTPS ブリッジへ送信した Authorization ヘッダーをそのまま転送する
        headers = {}
        auth = self.headers.get("Authorization")
        if auth:
            headers["Authorization"] = auth

        req = urllib.request.Request(target, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                self.send_response(resp.status)
                for key, val in resp.headers.items():
                    if key.lower() not in ("transfer-encoding", "connection"):
                        self.send_header(key, val)
                self.end_headers()
                self.wfile.write(resp.read())
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self.end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write(f"[PROXY] {self.path}\n")
        sys.stderr.flush()


server = http.server.HTTPServer(("127.0.0.1", LOCAL_PORT), TransparentProxyHandler)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(CERT_FILE, KEY_FILE)
server.socket = ctx.wrap_socket(server.socket, server_side=True)

signal.signal(signal.SIGTERM, lambda *a: (server.shutdown(), sys.exit(0)))
print(f"[PROXY] https://localhost:{LOCAL_PORT} -> {REPO_MANAGER_URL}", file=sys.stderr, flush=True)
server.serve_forever()
