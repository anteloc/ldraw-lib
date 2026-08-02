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
grep -F -f "$tmp_file" 'models-index.jsonl' > 'models-glb-index.jsonl'

rm "$tmp_file"
