#!/bin/bash

scripts_dir="$(dirname "$(realpath "$0")")"

models_dir="$1"
thumbs_dir="$2"
models_idx_file="$3"

if [ -z "$models_dir" ] || [ -z "$thumbs_dir" ] || [ -z "$models_idx_file" ]; then
    echo "Usage: $0 <models directory> <thumbnails directory> <models index file jsonl>"
    echo "Uses a vision model running on ollama to get textual descriptions of the models"
    exit 1
fi

[ ! -d "$thumbs_dir" ] && echo "[ERROR] Thumbnails directory not found: $thumbs_dir" && exit 1
[ ! -d "$models_dir" ] && echo "[ERROR] Models directory not found: $models_dir" && exit 1

# if index exists, ask if it should be overwritten
if [ -f "$models_idx_file" ]; then
    read -p "Models index file already exists: $models_idx_file. Do you want to overwrite it? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting."
        exit 1
    fi
fi


tmp_idx="$(mktemp)"
echo "Indexing thumbnails from $thumbs_dir into temp file: $tmp_idx" >&2

total_thumbs=$(find "$thumbs_dir" -type f -name '*.png' | wc -l | tr -d ' ')
current=0

avg_secs=0

for thumb in "$thumbs_dir"/*.png; do
    current=$((current + 1))
    
    echo "Processing thumbnail ($current/$total_thumbs, avg: $avg_secs s/thumb): $(basename "$thumb")" >&2
    base_name="$(basename "$thumb" .png)"
    model_name="$base_name.mpd.zip" # this should be the same as the model file name, without the extension
    
    start_time=$(date +%s)
    "$scripts_dir/ollama-classify.sh" "$models_dir" - "$thumb" | jq -c --arg model_name "$model_name" '. + {name: $model_name}'
    
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    
    avg_secs=$(( (avg_secs * (current - 1) + elapsed) / current ))
done | tee "$models_idx_file"

echo "Indexing complete. Models index file created at: $models_idx_file" >&2
