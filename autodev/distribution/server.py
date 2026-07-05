#!/usr/bin/env python3
"""LAN 内 APK 配信用 HTTP サーバー（追加ヘッダ付き）。

- Content-Disposition で APK ダウンロードを促進
- /healthz は 200 を返す
- Cache-Control を控えめに（最新ビルドを毎回取得させたい）
"""
import http.server
import socketserver
import os
import sys
from pathlib import Path

PORT = int(os.environ.get("PORT", "9080"))
BIND = os.environ.get("BIND", "0.0.0.0")
ROOT = Path(__file__).resolve().parent / "www"

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def end_headers(self):
        # 最新を取りに行かせる
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        # APK は Android にダウンロードファイルとして扱わせる
        if self.path.lower().endswith(".apk"):
            self.send_header("Content-Type", "application/vnd.android.package-archive")
            fname = os.path.basename(self.path)
            # 日本語ファイル名は RFC 5987 形式で
            self.send_header(
                "Content-Disposition",
                f"attachment; filename=\"{fname}\"; filename*=UTF-8''" + fname.replace(" ", "%20"),
            )
        super().end_headers()

    def do_GET(self):
        if self.path == "/healthz":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"ok\n")
            return
        return super().do_GET()

    def log_message(self, fmt, *args):
        # シンプルなアクセスログ
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

if __name__ == "__main__":
    if not ROOT.exists():
        sys.exit(f"ERROR: web root not found: {ROOT}")
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer((BIND, PORT), Handler) as httpd:
        print(f"Serving {ROOT} on http://{BIND}:{PORT} (LAN reachable)")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nshutdown.")
