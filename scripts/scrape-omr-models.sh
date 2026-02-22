#!/bin/bash

set -euo pipefail

# install aria2c if not already installed, it will be used to download the models in parallel
command -v aria2c >/dev/null 2>&1 \
    || { 
            sudo apt-get update && sudo apt-get install -y aria2 \
            || { 
                echo >&2 "aria2c is required but it can't be installed. Aborting."; 
                exit 1; 
            } 
    }

### Main script starts here ###
echo "[INFO] Starting OMR models scraping..."

models_dir="$1"

[ ! -d "$models_dir" ] && mkdir -p "$models_dir"

sets_url='https://library.ldraw.org/omr/sets'

tmp_dir="$(mktemp -d)"
trap "rm -rf $tmp_dir" EXIT

echo "[INFO] Temporary directory created at: $tmp_dir"

cd "$tmp_dir" || { echo "[ERROR] Unable to change directory to $tmp_dir"; exit 1; }

# get last page number from the default sets page html element
last_page_num="$(curl -s "$sets_url" \
    | awk 'BEGIN{output="false"}; /fi-pagination-item-label/{ output="true"; next}; /span>/{output="false"; next} output == "true" {print $0}' \
    | tr -d ' ' \
    | tail -1)"

# calculate the urls for all sets pages and save them to a file for wget to read
seq 1 "$last_page_num" | xargs -I{} printf "${sets_url}?page=%s\n" {} >>sets-pages-urls.txt

# scrape only the web pages html files, it will be faster
cat -i sets-pages-urls.txt  | xargs -n 1 -P 2 wget \
     --mirror \
     --no-parent \
     --page-requisites \
     --convert-links \
     --no-clobber \
     --execute robots=off \
     --wait=1 \
     --random-wait \
     --reject-regex '\.(ldr|mpd|dat|jpg|png|gif|pdf|zip|7z|mp3|mp4|avi|mov|exe|deb|rpm|dmg|iso|css|png\?v.*|js\?v.*|css\?v.*)$'

sets_dir="library.ldraw.org/omr/sets"

# extract the urls of the models from the downloaded html files
grep --no-filename -r -o -E 'https://library.ldraw.org/library/omr/.*\.(mpd|ldr)' $sets_dir > models-urls.txt

# parallel download the models using aria2c, it will be faster than wget
num_jobs=10

aria2c -i models-urls.txt \
    --dir=$models_dir \
    --max-concurrent-downloads=$num_jobs \
    --split=4 \
    --file-allocation=none

echo "[INFO] Download completed. Models are stored in: $models_dir"
