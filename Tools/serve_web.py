#!/usr/bin/env python3
"""Serve a Godot Web export locally with browser-compatible headers."""

from __future__ import annotations

import argparse
import functools
import mimetypes
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class GodotWebHandler(SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8060)
    parser.add_argument("--directory", default="export/web")
    parser.add_argument("--open-browser", action="store_true")
    return parser.parse_args()


def validate_export(directory: Path) -> None:
    required_patterns = ("index.html", "*.js", "*.wasm", "*.pck")
    missing_patterns = [
        pattern for pattern in required_patterns if not any(directory.glob(pattern))
    ]
    if missing_patterns:
        raise SystemExit(
            "Incomplete Godot Web export. Missing: "
            + ", ".join(missing_patterns)
        )


def create_server(directory: Path, port: int) -> ThreadingHTTPServer:
    mimetypes.add_type("application/wasm", ".wasm")
    mimetypes.add_type("application/octet-stream", ".pck")
    handler = functools.partial(GodotWebHandler, directory=str(directory))
    return ThreadingHTTPServer(("127.0.0.1", port), handler)


def serve(directory: Path, port: int, open_browser: bool = False) -> None:
    directory = directory.resolve()
    validate_export(directory)
    server = create_server(directory, port)
    url = f"http://localhost:{port}"
    print(f"Serving School Wars at {url}")
    if open_browser:
        webbrowser.open(url)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


def main() -> None:
    args = parse_args()
    serve(Path(args.directory), args.port, args.open_browser)


if __name__ == "__main__":
    main()
