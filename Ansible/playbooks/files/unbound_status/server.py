#!/usr/bin/env python3
"""Unbound status page — état du service + test de résolution + stats."""
import http.server
import subprocess
import html
import string
from pathlib import Path

PORT = 9091
TEMPLATE = Path(__file__).parent / "template.html"


def run(cmd, timeout=3):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip()
    except Exception as e:
        return f"(erreur: {e})"


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        active = run(["systemctl", "is-active", "unbound"]) == "active"
        test = run(["dig", "@127.0.0.1", "-p", "5335", "+short", "+time=2", "wiserisk.be"])
        resolving = bool(test and "timed out" not in test and "no servers" not in test)

        if active and resolving:
            badge_color, badge_text = "#22c55e", "UP"
        elif active:
            badge_color, badge_text = "#f59e0b", "UP — résolution KO"
        else:
            badge_color, badge_text = "#ef4444", "DOWN"

        stats = run(["unbound-control", "stats_noreset"])
        if not stats or "error" in stats.lower() or "Connection refused" in stats:
            stats = "(unbound-control non disponible — remote-control non configuré)"

        body = string.Template(TEMPLATE.read_text()).substitute(
            badge_color=badge_color,
            badge_text=badge_text,
            test_class="ok" if resolving else "ko",
            test_output=html.escape(test or "(pas de réponse)"),
            stats_output=html.escape(stats),
        )

        data = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *_):
        pass


if __name__ == "__main__":
    http.server.HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()