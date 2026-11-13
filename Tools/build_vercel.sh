#!/usr/bin/env bash
# Native, threadless Godot export for a static Vercel deployment.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
build_directory="$(mktemp -d "${TMPDIR:-/tmp}/school-wars-build.XXXXXX")"
trap 'rm -rf "$build_directory"' EXIT

release="4.3-stable"
release_url="https://github.com/godotengine/godot/releases/download/${release}"
curl --fail --location --retry 3 --output "$build_directory/godot.zip" \
  "$release_url/Godot_v${release}_linux.x86_64.zip"
curl --fail --location --retry 3 --output "$build_directory/templates.tpz" \
  "$release_url/Godot_v${release}_export_templates.tpz"

# Pin both downloaded tool archives to the exact release used for validation.
printf '%s  %s\n' \
  '7de56444b130b10af84d19c7e0cf63cf9e9937ee4ba94364c3b7dd114253ca21' "$build_directory/godot.zip" \
  'f5f10dbaf56a7908349e64b94ea8c2c93c2cc11fb1014c9565b68a2bb437b922' "$build_directory/templates.tpz" \
  | sha256sum --check --status

unzip -q "$build_directory/godot.zip" -d "$build_directory/engine"
unzip -q "$build_directory/templates.tpz" 'templates/web_nothreads_release.zip' -d "$build_directory"
export XDG_DATA_HOME="$build_directory/data"
template_directory="$XDG_DATA_HOME/godot/export_templates/4.3.stable"
mkdir -p "$template_directory" export/web
cp "$build_directory/templates/web_nothreads_release.zip" "$template_directory/"
godot_binary="$build_directory/engine/Godot_v${release}_linux.x86_64"
chmod +x "$godot_binary"
"$godot_binary" --headless --editor --path . --quit
"$godot_binary" --headless --path . --export-release Web export/web/index.html

# Godot's generated shell uses the project name for both variants. Set the
# route-specific tab title before the engine downloads and starts.
python3 - <<'PY'
from pathlib import Path

html_path = Path("export/web/index.html")
html = html_path.read_text(encoding="utf-8")
title = "<title>School Wars</title>"
bootstrap = """<script>
(() => {
  const path = window.location.pathname;
  const is_school_wars = path === "/schoolwars" || path.startsWith("/schoolwars/");
  document.title = is_school_wars ? "School Wars" : "Medieval Wars";
})();
</script>"""
if html.count(title) != 1:
    raise SystemExit("Expected exactly one default Godot page title in the web export")
if "const is_school_wars" in html:
    raise SystemExit("Route-specific page title bootstrap was already inserted")
html = html.replace(title, title + "\n\t\t" + bootstrap, 1)
html_path.write_text(html, encoding="utf-8")
PY

for file in index.html index.js index.wasm index.pck; do
  test -s "export/web/$file"
done
