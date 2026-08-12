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

function get_part_description() {
    local db="$DB"
    local alias="$1"

    sqlite3 -noheader "$db" <<SQL
.parameter init
.parameter set :alias $(printf '%q' "$alias")

WITH RECURSIVE resolved(alias, description) AS (
    SELECT alias, description
    FROM PART_INFOS
    WHERE alias = :alias

    UNION ALL

    SELECT p.alias, p.description
    FROM PART_INFOS AS p
    JOIN resolved AS r
      ON p.alias = trim(
          substr(r.description, length('~Moved to') + 1)
      )
    WHERE r.description LIKE '~Moved to%'
)
SELECT description
FROM resolved
WHERE description NOT LIKE '~Moved to%'
LIMIT 1;
SQL
}

function rec_resolve_description() {
    local part_name="$1"

    # add .dat suffix if not present
    if [[ "$part_name" != *.dat ]]; then
        part_name="${part_name}.dat"
    fi

    # local query="select description from part_infos where lower(alias) = lower('$part_name')"
    local query="
    WITH RECURSIVE resolved(alias, description) AS (
    -- Start with the requested alias.
    SELECT alias, description
    FROM PART_INFOS
    WHERE alias = :alias

    UNION ALL

    -- If it was moved, follow the referenced alias.
    SELECT p.alias, p.description
    FROM PART_INFOS AS p
    JOIN resolved AS r
      ON p.alias = trim(substr(r.description, length('~Moved to') + 1))
        WHERE r.description LIKE '~Moved to%'
    )
    SELECT description
    FROM resolved
    WHERE description NOT LIKE '~Moved to%'
    LIMIT 1;
    "

    # echo "Query: [$query]" >&2
    local description="$(sqlite3 ./ldraw-info.db "$query")"

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

# rec_resolve_description "$part_name"
get_part_description "$part_name"

