#!/bin/bash
target_dir="$(dirname "$0")/../../anteloc.github.io"
project_dir="$(dirname "$0")/.."

cp "$project_dir/ldraw-viewer-vr.html" "$target_dir/"

cd "$target_dir"

git add ldraw-viewer-vr.html
git commit -m "Deploy LDraw viewer for web and VR/MR"
git push origin