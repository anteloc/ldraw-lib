#!/bin/bash

# FIXME too slow, could cause issues on github's actions in periodic executions, maybe timeouts
# Besides that, ldr2img maybe won't work on github, due to it needing a GPU for rendering: does github containers provide GPU access?

models_dir="$1"
thumbs_dir="$2"
thumb_size="$3"

if [ -z "$models_dir" ] || [ -z "$thumbs_dir" ] || [ -z "$thumb_size" ]; then
    echo "Usage: $0 <models directory> <thumbnails directory> <thumbnail size, e.g. 512x512>"
    exit 1
fi

[ ! -d "$models_dir" ] && echo "[ERROR] Models directory not found: $models_dir" && exit 1
[ ! -d "$thumbs_dir" ] && echo "[INFO] Thumbnails directory not found, creating: $thumbs_dir" && mkdir -p "$thumbs_dir"

# verify if commands exists
{ 
    command ldr2img --help && command magick --help; 
}  > /dev/null 2>&1 || \
{ 
    echo "[ERROR] Please make sure ldr2img and ImageMagick's magick command are installed and working properly." >&2 \
    && exit 1;
}

# by default, this will create a thumbnail in the same directory as the model file, ending in -isometric.png
echo "Generating isometric thumbnails for models in $models_dir, this **could take a while**..." >&2
ldr2img --jobs 10 --view "isometric"  "$models_dir"    

# get all isometrics, copy removing the -isometric suffix, and resize them to thumb_size thumbnail size

find "$models_dir" -type f -name '*-isometric.png' \
    | while IFS= read -r thumb_iso; do 
        iso_base="$(basename $thumb_iso)"; 
        thumb="${iso_base/-isometric/}";
        thumb="$thumbs_dir/$thumb"; 

        if [ -f "$thumb" ]; then
            echo "Thumbnail already exists, skipping: '$thumb'" >&2;
            continue; 
        fi

        echo "Processing thumbnail: '$iso_base'" >&2;
        cp "$thumb_iso" "$thumb"; 
        magick "$thumb" -resize "$thumb_size" "$thumb"
done

# there are many files, delete like this just in case
find "$models_dir" -type f -name '*-isometric.png' -delete
