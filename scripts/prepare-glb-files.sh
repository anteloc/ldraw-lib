#!/bin/bash

parent_dir="$(dirname "$0")/.."
parent_dir="$(realpath "$parent_dir")"

# This script is provisional
# Prepare the required files, indexes, zipped files, etc. for external apps to consume
# models in .glb format, in order to reduce the amount of API calls to GitHub, save bandwidth, etc.

function usage() {
    echo "Usage: $0 --run"
    echo "Prepare the required files, indexes, zipped files, etc. for external apps to consume"
    echo "models in .glb format, in order to reduce the amount of API calls to GitHub, save bandwidth, etc."
    echo "This script is provisional and may delete files. Use the --run option to execute it."
    exit 1
}

function add_glb_size() {
    # make this input pipeable, so it can be used as a filter to add the glb_size to each line of a jsonl file
    cat | while IFS= read -r json_line; do
        add_glb_size_to_json "$json_line"
    done
}

function add_glb_size_to_json() {
    local json_line="$1"
    local model_name=$(echo "$json_line" | jq -r '.name')
    local glb_file="$parent_dir/models-glb/${model_name%.mpd.zip}.glb"
    if [ -f "$glb_file" ]; then
        local glb_size=$(stat -f%z "$glb_file")
        local glb_size_kb=$((glb_size / 1024))
        echo "$json_line" | jq -c --arg size_kb "$glb_size_kb" '. + {glb_size_kb: ($size_kb | tonumber)}'
    else
        echo "$json_line" | jq -c '. + {glb_size_kb: null}'
    fi
}

# At least the --run option is required, in order to avoid accidental execution of the script.
run_flag="${1:-}"

if [ "$run_flag" != "--run" ]; then
    echo "This script is provisional and may delete files. Use the --run option to execute it."
    exit 1
fi

cd "$parent_dir"

# Use GitHub LFS, large files can be downloaded from raw urls too, but it could deplete LFS download budget! 
[ -f 'thumbnails.zip' ] && echo "Deleting thumbnails.zip archive..." && rm 'thumbnails.zip'
[ -f 'thumbnails-small.zip' ] && echo "Deleting thumbnails-small.zip archive..." && rm 'thumbnails-small.zip'

# zip the thumbnails directory, if it exists, into a zip file with only a thumbnails/ prefix, and delete the original directory
echo "Zipping thumbnails directories into thumbnails.zip and thumbnails-small.zip ..."
zip -r 'thumbnails.zip' 'thumbnails'
zip -r 'thumbnails-small.zip' 'thumbnails-small'

# create a temp file to store the names of the .glb model files, but replacing extension with .mpd.zip
tmp_file=$(mktemp)

ls -1 models-glb | sed 's/\.glb/.mpd.zip/g' > "$tmp_file"

# grep the models-index.jsonl file, filtering by exact matches on the tmp_file
grep -F -f "$tmp_file" 'models-index.jsonl' | add_glb_size > 'models-glb-index.jsonl'


rm "$tmp_file"

echo "GLB required files prepared. Models index file created at: models-glb-index.jsonl"
