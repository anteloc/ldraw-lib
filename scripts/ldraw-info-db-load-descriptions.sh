#!/bin/bash

scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"
parent_dir="$(dirname "$scripts_dir")"

function usage() {
    echo "Usage: $0 --run"
    echo "Loads descriptions on ldraw-info.db, tables PARTS_DESCRIPTIONS, MODELS_DESCRIPTIONS and SUBMODELS_DESCRIPTIONS"
    echo "Sources for these descriptions are:"
    echo " - PARTS_DESCRIPTIONS: copied from PART_INFOS(alias, description) table"
    echo " - MODELS_DESCRIPTIONS: taken from the model description lines from ../models-annotated/*.mpd files"
    echo " - SUBMODELS_DESCRIPTIONS: taken from the model description lines from ../models-annotated/*.mpd files"
    echo "Example: $0 71944.dat"
    exit 1
}

function load_part_descriptions() {
    echo "Loading PARTS_DESCRIPTIONS..."

    sql_file=$(mktemp)

    # FIXME the description that should be loaded for "~Moved to" cases, should be resolved via part-description.sh executions,
    # not just copied from PART_INFOS table, which will have the description of the moved part, not the original part.
    echo "
    PRAGMA trusted_schema = ON;
    PRAGMA foreign_keys = ON;
    DELETE FROM PARTS_DESCRIPTIONS;" > "$sql_file"

    sqlite3 ldraw-info.db <<EOF
    PRAGMA trusted_schema = ON;
    PRAGMA foreign_keys = ON;
    
    DELETE FROM PARTS_DESCRIPTIONS;
    INSERT INTO PARTS_DESCRIPTIONS (alias, description)
    SELECT alias, description FROM PART_INFOS;
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

    awk 'FNR==2 { printf "INSERT INTO MODELS_DESCRIPTIONS(alias, description) VALUES(|%s|, |%s|);\n", FILENAME, $0 }' *.mpd \
    | sed -e 's/|0 FILE /|/' -e 's/|0 /|/' \
    | sed "s/'/''/g" \
    | tr '|' "'" >> "$sql_file"

    cd - || exit 1

    sqlite3 ldraw-info.db < "$sql_file"
    
    rm "$sql_file"
}

function load_submodel_descriptions() {
    echo "Loading SUBMODELS_DESCRIPTIONS..."
    
    sql_file=$(mktemp)

    echo "
    PRAGMA trusted_schema = ON;
    PRAGMA foreign_keys = ON;
    DELETE FROM SUBMODELS_DESCRIPTIONS;" > "$sql_file"

    cd "$parent_dir/models-annotated" || exit 1

    awk 'FNR>2 && $0 ~"^0 FILE" { printf "INSERT INTO SUBMODELS_DESCRIPTIONS(alias, submodel, description) VALUES(|%s|, |%s|, ", FILENAME, $0; matched=1; next;} matched {printf "|%s|);\n", $0; matched=0;}' *.mpd \
    | sed -e 's/|0 FILE /|/' -e 's/|0 /|/' \
    | sed "s/'/''/g" \
    | tr '|' "'" >> "$sql_file"
    
    cd - || exit 1

    sqlite3 ldraw-info.db < "$sql_file"

    rm "$sql_file"
}

# Verify that the script is run with the --run option
if [[ "$1" != "--run" ]]; then
    usage
fi

cd "$scripts_dir" || exit 1

load_part_descriptions
load_model_descriptions
load_submodel_descriptions

