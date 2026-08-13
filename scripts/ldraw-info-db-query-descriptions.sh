#!/bin/bash

scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"
parent_dir="$(dirname "$scripts_dir")"

DB="$scripts_dir/ldraw-info.db"

function usage() {
    echo "Usage: $(basename $0) <--parts | --models | --submodels> [--max-results <number>] [--where "column=value"] [--query <'query'>"]
    echo "FTS (full-text-search) descriptions for parts, models and submodels from ldraw-info.db"
    echo " --parts: matches query against parts descriptions"
    echo " --models: matches query against models descriptions"
    echo " --submodels: matches query against submodels descriptions"
    echo " --where 'column=value': both column and value *must* be unquoted, used to build a WHERE clause to filter by specific columns (e.g. --where \"model=41606-1.mpd\")"
    echo " --max-results <number>: limits the number of results returned (default: 10), -1 no limit"
    echo " --query <'query'>: FTS query string to search for (enclose in single quotes), in SQLite FTS5 syntax"
    echo ""
    echo "Example: $(basename $0) --parts --max-results 10 --query 'star'"
    echo "Example: $(basename $0) --submodels --where \"model=41606-1.mpd\" --max-results 2 --query 'rebel'"
    echo ""
    echo 'Output format (JSON):'
    echo '[{"part":"1-16chrd.dat","description":"Block xxx"}, ...]'
    echo '[{"model":"41606-1.mpd","description":"Star-Lord"}, ...]'
    echo '[{"model":"41606-1.mpd","submodel":"41606-1.mpd","description":"Star-Lord"}, ...]'
    echo ""
    cat <<'SQL'
### SQLite FTS `MATCH` Query Syntax

Provide **only the FTS query expression** as the search argument. Do **not** generate SQL, `MATCH`, `WHERE`, table names, or SQL quoting—the script builds and parameterizes the SQL.

**Patterns**

* `term` — contains token
* `prefix*` — token beginning with prefix
* `"exact phrase"` — adjacent tokens in exact order
* `foo bar` — both terms (implicit AND)
* `foo AND bar` — both terms
* `foo OR bar` — either term
* `foo NOT bar` — foo, excluding bar
* `foo NEAR bar` — terms near each other (default proximity of 10 tokens)
* `NEAR(foo bar, 5)` — terms separated by ≤5 intervening tokens
* `column:term` — restrict term to an FTS column
* `column:"exact phrase"` — restrict phrase to a column
* `(foo OR bar) AND baz` — explicit grouping (enhanced syntax)

**Rules for agents**

1. Return the **query expression only**, e.g. `sqlite AND "full text"`.
2. Use uppercase `AND`, `OR`, `NOT`, and `NEAR`.
3. Quote multi-token phrases with `"..."`.
4. Append `*` for prefix matching; it is not a general glob/wildcard.
5. Use `column:` only for known FTS columns.
6. Prefer explicit parentheses when combining boolean operators.
7. Do not add `%`, `LIKE`, regex syntax, SQL clauses, or SQL string quotes.
8. Keep the expression minimal: use synonyms with `OR`, required concepts with `AND`, and `NOT` only when exclusion is intentional.
9. Avoid apostrophes in bare tokens (e.g. `logo's`) — FTS5 will reject them; drop the apostrophe (`logos`) or quote the whole term as a phrase (`"logo's"`).

**Example script arg**

```text
sqlite AND ("full text" OR fts*) NOT deprecated
```

SQL
    exit 1
}

function query_part_descriptions() {
    local max_results="$1"
    local where_clause="$2"
    local query="$3"
    local sql_query=${query//\'/\'\'}

    sqlite3 -json "$DB" \
<<SQL
    SELECT part, description
    FROM PARTS_DESCRIPTIONS_FTS
    WHERE $where_clause
    AND ('$sql_query' = '' OR PARTS_DESCRIPTIONS_FTS MATCH '$sql_query')
    ORDER BY rank
    LIMIT $max_results;
SQL
}

function query_model_descriptions() {
    local max_results="$1"
    local where_clause="$2"
    local query="$3"
    local sql_query=${query//\'/\'\'}

    sqlite3 -json "$DB" \
<<SQL
    SELECT model, description
    FROM MODELS_DESCRIPTIONS_FTS
    WHERE $where_clause
    AND MODELS_DESCRIPTIONS_FTS MATCH '$sql_query'
    ORDER BY rank
    LIMIT $max_results;
SQL
}

function query_submodel_descriptions() {
 local max_results="$1"
 local where_clause="$2"
 local query="$3"
 local sql_query=${query//\'/\'\'}

    sqlite3 -json "$DB" \
<<SQL
    SELECT model, submodel, description
    FROM SUBMODELS_DESCRIPTIONS_FTS
    WHERE $where_clause
    AND SUBMODELS_DESCRIPTIONS_FTS MATCH '$sql_query'
    ORDER BY rank
    LIMIT $max_results;
SQL
}

max_results=10
where_clause="1=1"
query=""

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
        --where)
            where_clause="$2"
            # Add quotes where required for SQL
            where_clause="$(printf '"%s"=%s' "${where_clause%%=*}" "'${where_clause#*=}'")"
            shift 2
            ;;
        --max-results)
            max_results="$2"
            # if unlimited, set to a high number, more than parts and models could be, for SQLite LIMIT
            [ "$max_results" -lt 0 ] && max_results=1000000
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
if [[ -z "$query_type" ]]; then
    echo "Error: one of --parts, --models or --submodels must be specified."
    usage
fi

case "$query_type" in
    parts)
        query_part_descriptions "$max_results" "$where_clause" "$query"
        ;;
    models)
        query_model_descriptions "$max_results" "$where_clause" "$query"
        ;;
    submodels)
        query_submodel_descriptions "$max_results" "$where_clause" "$query"
        ;;
esac

