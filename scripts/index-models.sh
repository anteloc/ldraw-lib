#!/bin/bash

set -euo pipefail

function tags_arr() {
    local tag="$1"
    local model_file="$2"

    cat "$model_file" \
        | tr -d '\r' \
        | grep "$tag" \
        | sed "s|0 $tag||g" \
        | tr ',' '\n' \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' \
        | sort \
        | uniq \
        | jq -r -R '@json' \
        | jq -c -s

    return 0
}

# function create_thumbnails() {
#     # FIXME too slow, could cause issues on github's actions in periodic executions, maybe timeouts
#     # Besides that, ldr2img maybe won't work on github, due to it needing a GPU for rendering: does github containers provide GPU access?
#     local models_dir="$1"
#     local thumbnails_dir="$2"

#     # verify if command exists
#     command ldr2img --help > /dev/null 2>&1 && \
#         ldr2img --view "isometric" -o "$thumbnail_file" "$model_file" &&
#         magick "$thumbnail_file" -resize 200x220 "$thumbnail_file" || { 
#             echo "[ERROR] Failed to generate thumbnail for model: $model_file" >&2
#         }

#     # by default, this will create a thumbnail in the same directory as the model file, ending in -isometric.png
#     echo "Generating isometric thumbnails for models in $models_dir, this **could take a while**..." >&2
#     ldr2img --view "isometric"  "$models_dir"    

#     # get all isometrics, copy removing the -isometric suffix, and resize them to 200x220 thumbnail size
#     local iso_base thumb

#     find "$models_dir" -type f -name '*-isometric.png' \
#         | while IFS= read -r thumb_iso; do 
#             iso_base="$(basename $thumb_iso)"; 
#             thumb="${iso_base/-isometric/}";
#             thumb="$thumbnails_dir/$thumb"; 

#             if [ -f "$thumb" ]; then
#                 echo "Thumbnail already exists, skipping: '$thumb'" >&2;
#                 continue; 
#             fi

#             echo "Processing thumbnail: '$iso_base'" >&2;
#             cp "$thumb_iso" "$thumb"; 
#             magick "$thumb" -resize 200x220 "$thumb"
#     done

#     # there are many files, delete like this just in case
#     find "$models_dir" -type f -name '*-isometric.png' -delete

#     return 0
# }


models_dir="$1"
thumbnails_dir="$2"

[ ! -d "$models_dir" ] && echo "[ERROR] Models directory does not exist: $models_dir" && exit 1
[ ! -d "$thumbnails_dir" ] && echo "[INFO] (WIP REQUIRED BUT UNUSED) Creating thumbnails directory: $thumbnails_dir" && mkdir -p "$thumbnails_dir"

models_dir="$(realpath "$models_dir")"
thumbnails_dir="$(realpath "$thumbnails_dir")"
models_idx_file="$(dirname "$models_dir")/models-index.jsonl"

# work with a tmp file, just in case the indexing fails in the middle and we end up deleting the existing index file without replacing it with a new one
tmp_idx="$(mktemp)"
echo "Indexing models from $models_dir into temp file: $tmp_idx" >&2
trap "rm -rf $tmp_idx" EXIT

find "$models_dir" -type f \( -iname "*.ldr" -o -iname "*.mpd" -o -iname "*.dat" \) \
| while IFS= read -r model_file; do
    echo "Indexing: $(basename "$model_file")" >&2
    m_name="$(basename "$model_file")"

    # description will be either the first line or the 2nd one if the first is a FILE meta line.
    fst_2_lines="$(head -n 2 "$model_file" | tr -d '\r')"
    
    fst_line="$(echo "$fst_2_lines" | head -n 1)"
    sec_line="$(echo "$fst_2_lines" | tail -n 1)"

    # classify the file and description lines
    if [[ "$fst_line" =~ ^0[[:space:]]+FILE ]]; then
        # keep the FILE line, but discard 0 FILE from the description and also its extension
        m_file_line="$(echo "$fst_line" | sed -e 's/^0 FILE *//' -e 's/\.[^.]*$//')"
        m_desc_line="$sec_line"

        # keep the longest one: sometimes the description is not meaningful, some others it's the file line, so we keep the one with more content
        if [ ${#m_file_line} -gt ${#m_desc_line} ]; then
            m_description="$m_file_line"
        else
            m_description="$m_desc_line"
        fi
    else
        # when no FILE line is present, the description is just the first line
        m_description="$fst_line"
    fi
    
    # replace all non-alphanumeric characters with a single space, then trim leading and trailing spaces
    m_description="$(echo "$m_description" | sed -E 's/[^a-zA-Z0-9]+/ /g' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"

    json_name="$(echo "$m_name" | jq -r -R '@json')"
    json_description="$(echo "$m_description" | jq -r -R '@json')"
    json_keywords="$(tags_arr "!KEYWORDS" "$model_file")"
    json_categories="$(tags_arr "!CATEGORY" "$model_file")"

    # if no categories, set to "Other"
    if [ "$json_categories" = "[]" ]; then
        json_categories='["Other"]'
    fi

    # output one json object per file, then combine them into a json array at the end
    printf '{"name":%s,"description":%s,"keywords":%s,"categories":%s}\n' "$json_name" "$json_description" "$json_keywords" "$json_categories"
    
done > "$tmp_idx"

# now, replace the existing index with the new one
echo "Replacing existing index file with new index from temp file: $tmp_idx" >&2
mv "$tmp_idx" "$models_idx_file"

# FIXME this is too slow, this could cause issues on github's actions in periodic executions
# Besides that, ldr2img maybe won't work on github, due to it needing a GPU for rendering: does github containers provide GPU access?
# create_thumbnails "$models_dir" "$thumbnails_dir"