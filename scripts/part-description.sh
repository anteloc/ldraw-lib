#!/bin/bash

script_dir=$(dirname "$0")
script_dir=$(realpath "$script_dir")

function usage() {
    echo "Usage: $0 <part name>"
    echo "Returns a part description, resolving it if required when the part has been '~Moved to'"
    echo "Example: $0 71944.dat"
    exit 1
}

function rec_resolve_description() {
    local part_name="$1"

    # add .dat suffix if not present
    if [[ "$part_name" != *.dat ]]; then
        part_name="${part_name}.dat"
    fi

    local query="select description from part_infos where lower(alias) = lower('$part_name')"
    # echo "Query: [$query]" >&2
    local description="$(sqlite-utils query ./ldraw-info.db "$query" | jq -r '.[].description' | head -1)"

    if [[ "$description" == "~Moved"* ]]; then
        # the new part name is the last token in the description, with delimiter blanks
        local new_part_name=$(echo "$description" | awk '{print $NF}')
        rec_resolve_description "$new_part_name"
    else
        echo "$description"
    fi
}

part_name="$1"

if [ -z "$part_name" ]; then
    usage
fi

cd "$script_dir" || exit 1

rec_resolve_description "$part_name"

