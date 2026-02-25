#!/bin/bash
set -euo pipefail

function usage() {
    echo "Usage: $0 <models_dir> <packed_models_dir> [models_index_file]"
    echo "  models_dir: directory containing the original LDraw models (.ldr, .mpd, .dat)"
    echo "  packed_models_dir: directory where the packed and zipped models will be saved"
    echo "  models_index_file: (optional, ignored if not provided) path to the models index JSONL file to update with .zip extensions"
    exit 1
}

[ "$#" -lt 2 ] && usage

parent_dir="$(dirname "$0")/.."
parent_dir="$(realpath "$parent_dir")"

ldraw_dir="$parent_dir/ldraw"

models_dir="$1"
packed_models_dir="$2"
models_index_file="${3:-}"

echo "Packing models from $models_dir into $packed_models_dir" >&2

[ ! -d "$models_dir" ] && echo "[ERROR] Models directory does not exist: $models_dir" && exit 1
[ ! -d "$packed_models_dir" ] && echo "[INFO] Creating packed models directory: $packed_models_dir" && mkdir -p "$packed_models_dir"

if [ -f "$models_index_file" ]; then
    models_index_file="$(realpath "$models_index_file")"
else
    echo "[INFO] No index file provided, skipping index update"
fi

models_dir="$(realpath "$models_dir")"
# packDrawModel.mjs requires a relative path to the model file from $ldraw_dir
models_dir_rel="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$models_dir" "$ldraw_dir")"

packed_models_dir="$(realpath "$packed_models_dir")"

cd $ldraw_dir

set -x
# this will create a packed version of the models, with all the parts inlined, on the same dir as the models
find "$models_dir_rel" -type f \( -iname "*.ldr" -o -iname "*.mpd" -o -iname "*.dat" \) -exec printf "Packing: %s\n" {} \; -exec node packLDrawModel.mjs {} \;

# copy the packed models with find command
find "$models_dir" -type f -name '*_Packed.mpd'  -exec mv {} "$packed_models_dir/" \;

cd "$packed_models_dir"

# fix the name and zip the packed models, then delete the original .mpd
for f in *_Packed.mpd; do
    renamed="${f/_Packed.mpd/}"
    mv "$f" "$renamed"
    # zip renamed and delete the original
    zip -j "${renamed}.zip" "$renamed"
    rm "$renamed"
done

# now, update the models index to append .zip to every "name" field
if [ -f "$models_index_file" ]; then
    tmp_file="$(mktemp)"
    cat "$models_index_file" | jq -c '.name += ".zip"' > "$tmp_file" && mv "$tmp_file" "$models_index_file"
fi
