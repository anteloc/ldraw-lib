#!/bin/bash

script_dir=$(dirname "$0")
script_dir=$(realpath "$script_dir")

DB="$script_dir/ldraw-info.db"

function usage() {
    echo "Usage: $0 <part name>"
    echo "Returns a part description, resolving it if required when the part has been '~Moved to'"
    echo "Example: $0 71944.dat"
    exit 1
}

part_name="$1"


if [ -z "$part_name" ]; then
    usage
fi

sqlite3 -json "$DB" "
    SELECT part, description
    FROM PARTS_DESCRIPTIONS
    WHERE part = '$part_name';
" | jq -c '.[0]'
