#!/bin/bash

scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"
parent_dir="$(dirname "$scripts_dir")"

DB="$scripts_dir/ldraw-info.db"

function usage() {
    echo "Usage: $(basename $0) <--parts | --models | --submodels | --submodels-for-model <model name> [--max-results <number>] --query <'query'>"
    echo "FTS (full-text-search) descriptions for parts, models and submodels from ldraw-info.db"
    echo " --parts: matches query against parts descriptions"
    echo " --models: matches query against models descriptions"
    echo " --submodels: matches query against submodels descriptions"
    echo " --submodels-for-model <model name>: matches query against submodels descriptions for a specific model"
    echo " --max-results <number>: limits the number of results returned (default: 10)"
    echo " --query <'query'>: the query string to search for (enclose in single quotes), in SQLite FTS5 syntax"
    echo ""
    echo "Example: $(basename $0) --parts --max-results 10 --query 'star'"
    echo "Example: $(basename $0) --submodels-for-model '41606-1.mpd' --max-results 2 --query 'rebel'"
    echo ""
    echo 'Output format is JSON'
    echo 'For both parts and models has the following structure:'
    echo '[{"model":"41606-1.mpd","description":"Star-Lord"}, ...]'
    echo ""
    echo 'For submodels has the following structure:'
    echo '[{"alias":"41606-1.mpd","submodel":"41606-1.mpd","description":"Star-Lord"}, ...]'
    echo ""
    exit 1
}

function query_part_descriptions() {
    local max_results="$1"
    local query="$2"

       sqlite3 -json "$DB" \
           -cmd '.parameter init' \
           -cmd '.parameter set :query '"$(printf '%q' "$query")" \
           -cmd '.parameter set :limit '"$(printf '%q' "$max_results")" \
<<'SQL'
    SELECT part, description
    FROM PARTS_DESCRIPTIONS_FTS
    WHERE PARTS_DESCRIPTIONS_FTS MATCH :query
    ORDER BY rank
    LIMIT :limit;
SQL
}

function query_model_descriptions() {
    local max_results="$1"
    local query="$2"

    sqlite3 -json "$DB" \
        -cmd '.parameter init' \
        -cmd '.parameter set :query '"$(printf '%q' "$query")" \
        -cmd '.parameter set :limit '"$(printf '%q' "$max_results")" \
<<'SQL'
    SELECT model, description
    FROM MODELS_DESCRIPTIONS_FTS
    WHERE MODELS_DESCRIPTIONS_FTS MATCH :query
    ORDER BY rank
    LIMIT :limit;
SQL
}

function query_submodel_descriptions() {

 local max_results="$1"
 local query="$2"
 local alias="${3:-}" # empty string if not provided

    sqlite3 -json "$DB" \
        -cmd '.parameter init' \
        -cmd '.parameter set :query '"$(printf '%q' "$query")" \
        -cmd '.parameter set :limit '"$(printf '%q' "$max_results")" \
        -cmd '.parameter set :alias '"$(printf '%q' "$alias")" \
<<'SQL'
    SELECT model, submodel, description
    FROM SUBMODELS_DESCRIPTIONS_FTS
    WHERE (:alias = '' OR alias = :alias)
    AND SUBMODELS_DESCRIPTIONS_FTS MATCH :query
    ORDER BY rank
    LIMIT :limit;
SQL
}

max_results=10

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --parts)
            query_type="parts"
            shift
            ;;
        --models)
            query_type="models"
            shift
            ;;
        --submodels)
            query_type="submodels"
            shift
            ;;
        --submodels-for-model)
            query_type="submodels-for-model"
            model_alias="$2"
            shift 2
            ;;
        --max-results)
            max_results="$2"
            shift 2
            ;;
        --query)
            query="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$query_type" || -z "$query" ]]; then
    echo "Error: --query and one of --parts, --models, --submodels, or --submodels-for-model must be specified."
    usage
fi

case "$query_type" in
    parts)
        query_part_descriptions "$max_results" "$query"
        ;;
    models)
        query_model_descriptions "$max_results" "$query"
        ;;
    submodels)
        query_submodel_descriptions "$max_results" "$query"
        ;;
    submodels-for-model)
        if [[ -z "$model_alias" ]]; then
            echo "Error: --submodels-for-model requires a model alias."
            usage
        fi
        query_submodel_descriptions "$max_results" "$query" "$model_alias"
        ;;
esac

