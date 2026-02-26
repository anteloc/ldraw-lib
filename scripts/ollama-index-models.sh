#!/bin/bash

scripts_dir="$(dirname "$(realpath "$0")")"

thumbnails_dir="$1"
models_idx_file="$2"

if [ -z "$thumbnails_dir" ] || [ -z "$models_idx_file" ]; then
    echo "Usage: $0 <thumbnails directory> <models index file jsonl>"
    echo "Uses a vision model running on ollama to get textual descriptions of the models"
    exit 1
fi

[ ! -d "$thumbnails_dir" ] && echo "[ERROR] Thumbnails directory not found: $thumbnails_dir" && exit 1

tmp_idx="$(mktemp)"
echo "Indexing thumbnails from $thumbnails_dir into temp file: $tmp_idx" >&2

for thumb in "$thumbnails_dir"/*.png; do
    echo "Processing thumbnail: $(basename "$thumb")" >&2
    base_name="$(basename "$thumb" .png)"
    model_name="$base_name.mpd.zip" # this should be the same as the model file name, without the extension
    "$scripts_dir/ollama-classify.sh" "$thumb" - | jq -c --arg model_name "$model_name" '. + {name: $model_name}' 
done | tee "$tmp_idx"

touch "$models_idx_file"
modelx_idx_file="$(realpath "$models_idx_file")"

mv "$tmp_idx" "$modelx_idx_file"

echo "Indexing complete. Models index file created at: $models_idx_file" >&2
