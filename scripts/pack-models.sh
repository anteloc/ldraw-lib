#!/bin/bash
set -euo pipefail

parent_dir="$(dirname "$0")/.."
parent_dir="$(realpath "$parent_dir")"

ldraw_dir="$parent_dir/ldraw"

models_dir="$1"
packed_models_dir="$2"

echo "Packing models from $models_dir into $packed_models_dir" >&2

[ ! -d "$models_dir" ] && echo "[ERROR] Models directory does not exist: $models_dir" && exit 1
[ ! -d "$packed_models_dir" ] && echo "[INFO] Creating packed models directory: $packed_models_dir" && mkdir -p "$packed_models_dir"

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

for f in *_Packed.mpd; do 
    mv "$f" "${f/_Packed.mpd/}"
done
