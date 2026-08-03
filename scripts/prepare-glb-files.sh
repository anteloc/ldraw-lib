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
    local glb_dir="$1"
    # make this input pipeable, so it can be used as a filter to add the glb_size to each line of a jsonl file
    cat | while IFS= read -r json_line; do
        add_glb_size_to_json "$glb_dir" "$json_line"
    done
}

function add_glb_size_to_json() {
    local glb_dir="$1"
    local json_line="$2"
    local model_name=$(echo "$json_line" | jq -r '.name')
    local glb_file="$glb_dir/${model_name%.mpd.zip}.glb"
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

### Models

# create a temp file to store the names of the .glb model files, but replacing extension with .mpd.zip
tmp_file=$(mktemp)

ls -1 models-glb | sed 's/\.glb/.mpd.zip/g' > "$tmp_file"

# Create models-glb-index.jsonl: use the models index plus add size of the .glb files
grep -F -f "$tmp_file" 'models-index.jsonl' | add_glb_size 'models-glb' | sed 's/\.mpd\.zip/.glb/g' > 'models-glb-index.jsonl'

rm "$tmp_file"


### Minifigs

# Create convert minifig-props to glb and create minifig-props-glb-index.jsonl: use the minifig-props index plus add size of the .glb files
# This we will create from scratch, not based on a non-glb index

minifig_idx_entry_tmpl='{"category":"Minifig","description":"%s","keywords":["minifig","prop","tool","weapon","shield"],"name":"%s","glb_size_kb":%d}'

[ -f 'minifig-props-glb-index.jsonl' ] && echo "Deleting minifig-props-glb-index.jsonl..." && rm 'minifig-props-glb-index.jsonl'

for d in ./minifig-props/*.dat; do 
    prop_name=$(basename "$d" .dat)
    prop_desc=$(head -n 1 "$d" | tr -d '\r' | sed 's/^0 Minifig //') # first line of the .dat file, without the leading "0 Minifig "
    
    glb_file="./minifig-props-glb/${prop_name}.glb"

    mpd2glb.sh -l ldraw -c meshopt -o "$glb_file" "$d" 2>/dev/null

    if [ -f "$glb_file" ]; then
        glb_size=$(stat -f%z "$glb_file")
        glb_size_kb=$((glb_size / 1024))
        printf "$minifig_idx_entry_tmpl\n" "$prop_desc" "$prop_name.glb" "$glb_size_kb" >> 'minifig-props-glb-index.jsonl'
    fi
done 

## Thumbnails

# minifig-props thumbnails, 400x400, just in case new props were added
scripts/create-thumbnails.sh ./minifig-props ./thumbnails 400x400

# Use GitHub LFS, large files can be downloaded from raw urls too, but it could deplete LFS download budget! 
[ -f 'thumbnails.zip' ] && echo "Deleting thumbnails.zip archive..." && rm 'thumbnails.zip'
[ -f 'thumbnails-small.zip' ] && echo "Deleting thumbnails-small.zip archive..." && rm 'thumbnails-small.zip'

# zip the thumbnails directory, if it exists, into a zip file with only a thumbnails/ prefix, and delete the original directory
echo "Zipping thumbnails directories into thumbnails.zip and thumbnails-small.zip ..."
zip -r 'thumbnails.zip' 'thumbnails'
zip -r 'thumbnails-small.zip' 'thumbnails-small'


echo "GLB required files prepared. Indexes created at: models-glb-index.jsonl and minifig-props-glb-index.jsonl"
