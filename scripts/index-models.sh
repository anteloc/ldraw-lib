#!/bin/bash
set -euo pipefail

models_dir="$1"

[ ! -d "$models_dir" ] && echo "[ERROR] Models directory does not exist: $models_dir" && exit 1

models_dir="$(realpath "$models_dir")"
models_idx_file="$(dirname "$models_dir")/models-index.jsonl"

# work with a tmp file, just in case the indexing fails in the middle and we end up deleting the existing index file without replacing it with a new one
tmp_idx="$(mktemp)"
trap "rm -rf $tmp_idx" EXIT

find "$models_dir" -type f \( -iname "*.ldr" -o -iname "*.mpd" -o -iname "*.dat" \) \
| while IFS= read -r model_file; do
    m_name="$(basename "$model_file")"
    m_search_key="$(head -n 1 "$model_file" | tr -d '\r' | sed -e 's/^0//' -e 's/FILE//')"
    
    # sanitize the search key: sometimes it will be the description, others will be the FILE meta info, e.g. a file name...
    m_search_key="$(echo "$m_search_key" | tr -d '[:space:]')"
    m_search_key="$(basename "$m_search_key" .ldr)"
    # replace all non-alphanumeric characters with a single space, then trim leading and trailing spaces
    m_search_key="$(echo "$m_search_key" | sed -E 's/[^a-zA-Z0-9]+/ /g' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"

    json_name="$(echo "$m_name" | jq -r -R '@json')"
    json_search_key="$(echo "$m_search_key" | jq -r -R '@json')"
    
    # output one json object per file, then combine them into a json array at the end
    printf '{"name":%s,"search_key":%s}\n' "$json_name" "$json_search_key"
done > "$tmp_idx"

# now, replace the existing index with the new one
mv "$tmp_idx" "$models_idx_file"