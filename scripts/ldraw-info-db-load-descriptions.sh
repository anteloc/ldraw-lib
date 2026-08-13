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

    WITH RECURSIVE
    -- Normalize the '~Moved to <target>' text into something that can be matched
    -- against PART_INFOS.alias: char(92) is the backslash separator used by some
    -- targets, and the '.dat' extension is usually omitted.
    moved(alias, dir, target) AS (
        SELECT
            alias,
            CASE WHEN instr(alias, '/') > 0
                 THEN substr(alias, 1, instr(alias, '/'))
                 ELSE '' END,
            lower(
                CASE WHEN replace(trim(substr(description, length('~Moved to') + 1)), char(92), '/') LIKE '%.%'
                     THEN replace(trim(substr(description, length('~Moved to') + 1)), char(92), '/')
                     ELSE replace(trim(substr(description, length('~Moved to') + 1)), char(92), '/') || '.dat'
                END
            )
        FROM PART_INFOS
        WHERE description LIKE '~Moved to%'
    ),

    -- Exactly one target alias per moved alias: the literal target first, then the
    -- form relative to the source's own directory. NULL when neither exists.
    link(alias, target_alias) AS (
        SELECT
            m.alias,
            COALESCE(
                (SELECT p.alias FROM PART_INFOS AS p WHERE lower(p.alias) = m.target),
                (SELECT p.alias FROM PART_INFOS AS p WHERE lower(p.alias) = m.dir || m.target)
            )
        FROM moved AS m
    ),

    resolved(origin_alias, alias, description, path) AS (
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
        JOIN link AS l
          ON l.alias = r.alias
        JOIN PART_INFOS AS p
          ON p.alias = l.target_alias
        WHERE r.description LIKE '~Moved to%'
          AND instr(r.path, '|' || p.alias || '|') = 0
    )

    -- Keep every alias. Prefer a real description over a '~Moved to' placeholder,
    -- and among real ones the deepest hop of the chain. Aliases whose chain never
    -- reaches a real description keep their raw placeholder text.
    INSERT INTO PARTS_DESCRIPTIONS(part, description)
    SELECT part, description
    FROM (
        SELECT
            lower(origin_alias) AS part,
            description,
            row_number() OVER (
                PARTITION BY lower(origin_alias)
                ORDER BY (description LIKE '~Moved to%') ASC, length(path) DESC
            ) AS rn
        FROM resolved
    )
    WHERE rn = 1;

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

