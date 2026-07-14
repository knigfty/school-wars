#!/usr/bin/env python3
"""Export School Wars for Web, serve it on localhost, and open a browser."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
from pathlib import Path
from typing import Optional

from serve_web import serve, validate_export


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_EXPORT_DIRECTORY = PROJECT_ROOT / "export" / "web"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Path to a Godot 4 executable")
    parser.add_argument("--port", type=int, default=8060)
    parser.add_argument("--no-browser", action="store_true")
    parser.add_argument(
        "--serve-only",
        action="store_true",
        help="Serve an existing export without invoking Godot",
    )
    return parser.parse_args()


def find_godot(explicit_path: Optional[str]) -> str:
    requested_path = explicit_path or os.environ.get("GODOT_BIN")
    if requested_path:
        resolved_path = Path(requested_path).expanduser().resolve()
        if resolved_path.is_file():
            return str(resolved_path)
        raise SystemExit(f"Godot executable not found: {resolved_path}")

    for executable_name in ("godot4", "godot", "godot4.exe", "godot.exe"):
        executable_path = shutil.which(executable_name)
        if executable_path:
            return executable_path

    raise SystemExit(
        "Godot 4 was not found. Add it to PATH, set GODOT_BIN, or pass "
        "--godot /path/to/godot."
    )


def export_web_project(godot_binary: str, export_directory: Path) -> None:
    if export_directory.exists():
        shutil.rmtree(export_directory)
    export_directory.mkdir(parents=True, exist_ok=True)
    output_path = export_directory / "index.html"
    command = [
        godot_binary,
        "--headless",
        "--path",
        str(PROJECT_ROOT),
        "--export-release",
        "Web",
        str(output_path),
    ]
    print("Exporting School Wars for Web...")
    result = subprocess.run(command, check=False)
    if result.returncode != 0:
        raise SystemExit(
            "Godot Web export failed. Install the matching Web export templates "
            "through Editor > Manage Export Templates, then retry."
        )

    validate_export(export_directory)


def main() -> None:
    args = parse_args()
    if not args.serve_only:
        export_web_project(find_godot(args.godot), DEFAULT_EXPORT_DIRECTORY)
    serve(DEFAULT_EXPORT_DIRECTORY, args.port, not args.no_browser)


if __name__ == "__main__":
    main()
