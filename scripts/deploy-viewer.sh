#!/bin/bash
target_dir="$(dirname "$0")/../../anteloc.github.io"
project_dir="$(dirname "$0")/.."

cp "$project_dir/modelscope-xr.html" "$target_dir/"

cd "$target_dir"

git add modelscope-xr.html
git commit -m "Deploy ModelScope XR viewer for web and VR/MR"
git push
