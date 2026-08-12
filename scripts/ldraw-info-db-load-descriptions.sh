#!/bin/bash

scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"
parent_dir="$(dirname "$scripts_dir")"

function usage() {
    echo "Usage: $0 --run"
    echo "Re-creates tables *_DESCRIPTIONS and loads descriptions on ldraw-info.db, tables PARTS_DESCRIPTIONS, MODELS_DESCRIPTIONS and SUBMODELS_DESCRIPTIONS"
    echo "Sources for these descriptions are:"
    echo " - PARTS_DESCRIPTIONS: copied from PART_INFOS(alias, description) table, with resolution of '~Moved to' descriptions"
    echo " - MODELS_DESCRIPTIONS: taken from the model description lines from ../models-annotated/*.mpd files"
    echo " - SUBMODELS_DESCRIPTIONS: taken from the model description lines from ../models-annotated/*.mpd files"
    echo "Example: $0 71944.dat"
    exit 1
}

function load_part_descriptions() {
    echo "Loading PARTS_DESCRIPTIONS..."

    sqlite3 ldraw-info.db <<EOF
    PRAGMA trusted_schema = ON;
    PRAGMA foreign_keys = ON;
    
    BEGIN;

    DELETE FROM PARTS_DESCRIPTIONS;

    WITH RECURSIVE resolved(origin_alias, alias, description, path) AS (
        SELECT
            alias,
            alias,
            description,
            '|' || alias || '|'
        FROM PART_INFOS

        UNION ALL

        SELECT
            r.origin_alias,
            p.alias,
            p.description,
            r.path || p.alias || '|'
        FROM resolved AS r
        JOIN PART_INFOS AS p
          ON p.alias = trim(
              substr(r.description, length('~Moved to') + 1)
          )
        WHERE r.description LIKE '~Moved to%'
          AND instr(r.path, '|' || p.alias || '|') = 0
    )

    INSERT INTO PARTS_DESCRIPTIONS(part, description)
    SELECT
        origin_alias AS part,
        description
    FROM resolved
    WHERE description NOT LIKE '~Moved to%';

    COMMIT;
EOF
    echo "PARTS_DESCRIPTIONS loaded."
}

function load_model_descriptions() {
    echo "Loading MODELS_DESCRIPTIONS..."
    
    sql_file=$(mktemp)

    echo "
    PRAGMA trusted_schema = ON;
    PRAGMA foreign_keys = ON;
    DELETE FROM MODELS_DESCRIPTIONS;" > "$sql_file"

    cd "$parent_dir/models-annotated" || exit 1

    awk 'FNR==2 { printf "INSERT INTO MODELS_DESCRIPTIONS(model, description) VALUES(|%s|, |%s|);\n", FILENAME, $0 }' *.mpd \
    | sed -e 's/|0 FILE /|/' -e 's/|0 /|/' \
    | sed "s/'/''/g" \
    | tr '|' "'" >> "$sql_file"

    cd - || exit 1

    sqlite3 ldraw-info.db < "$sql_file"
    
    rm "$sql_file"

    echo "MODELS_DESCRIPTIONS loaded."
}

function load_submodel_descriptions() {
    echo "Loading SUBMODELS_DESCRIPTIONS..."
    
    sql_file=$(mktemp)

    echo "
    PRAGMA trusted_schema = ON;
    PRAGMA foreign_keys = ON;
    DELETE FROM SUBMODELS_DESCRIPTIONS;" > "$sql_file"

    cd "$parent_dir/models-annotated" || exit 1

    awk 'FNR>2 && $0 ~"^0 FILE" { printf "INSERT INTO SUBMODELS_DESCRIPTIONS(model, submodel, description) VALUES(|%s|, |%s|, ", FILENAME, $0; matched=1; next;} matched {printf "|%s|);\n", $0; matched=0;}' *.mpd \
    | sed -e 's/|0 FILE /|/' -e 's/|0 /|/' \
    | sed "s/'/''/g" \
    | tr '|' "'" >> "$sql_file"
    
    cd - || exit 1

    sqlite3 ldraw-info.db < "$sql_file"

    rm "$sql_file"

    echo "SUBMODELS_DESCRIPTIONS loaded."
}

function recreate_descriptions_tables() {
    echo "Recreating tables PARTS_DESCRIPTIONS, MODELS_DESCRIPTIONS and SUBMODELS_DESCRIPTIONS..."
    
    sqlite3 ldraw-info.db < ldraw-info-db-descriptions.ddl
}

# Verify that the script is run with the --run option
if [[ "$1" != "--run" ]]; then
    usage
fi

cd "$scripts_dir" || exit 1

recreate_descriptions_tables
load_part_descriptions
load_model_descriptions
load_submodel_descriptions

