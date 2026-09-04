#!/bin/bash

scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"
parent_dir="$(dirname "$scripts_dir")"

MODELS_DIR="$parent_dir/models-annotated"
PARTS_DIR="$parent_dir/ldraw/parts"
COLOURS_FILE="$parent_dir/ldraw/LDConfig.ldr"

function usage() {
    echo "Usage: $(basename "$0") <--colour <colour_name or colour_code> | --model <model_name> | --part <part_name> | --submodel <model_name> <submodel_name>>"
    echo "Returns a summary for either a part, a model or a submodel from a model, or if given a colour name it returns the code, and viceversa."
    echo "Execute the following examples for real outputs:"
    echo "$(basename "$0") --part 3832.dat"
    echo "$(basename "$0") --model 106-1.mpd"
    echo "$(basename "$0") --submodel 106-1.mpd '106 - Minifig.ldr'"
    echo "$(basename "$0") --colour Blue"
    echo "$(basename "$0") --colour 10"
    exit 1
}

function colour_summary() {
    local name_or_code="$1"
    found_name_or_code=$(awk -v name_or_code="$name_or_code" '
        $1 == "0" && $2 == "!COLOUR" && toupper($3) == toupper(name_or_code) { print $5; exit;}
        $1 == "0" && $2 == "!COLOUR" && $5 == name_or_code { print $3; exit;}' "$COLOURS_FILE")

    if [[ -z "$found_name_or_code" ]]; then
        echo "Colour not found: '$name_or_code'" >&2
        exit 1
    fi
    echo "$name_or_code -> $found_name_or_code"
}

function parts_bom() {
    cat | grep '0 //' | sort | uniq -c | sed 's|0 //|x|' | xargs -I{} echo "  * {}"
}

function main_header() {
    local item_type="$1"
    local item_name="$2"
    echo "# ${item_type}: $item_name"
    echo ""
}

function submodel_header() {
    cat | grep -A 1 ' FILE ' | sed -e 's/0 FILE/## Submodel:/' -e 's/^0 /\n**Description:** \n\n  /'
}

function model_summary() {
    local model_name="$1"
    local model_file="$MODELS_DIR/$model_name"
    if [[ ! -f "$model_file" ]]; then
        echo "Model file not found: '$model_file'" >&2
        exit 1
    fi

    subs="$(cat "$model_file" | grep '0 FILE' | sed 's/0 FILE //' | awk '{$1=$1;print}')"

    echo "$subs" | while IFS= read -r sm; do 
        submodel_summary "$model_name" "$sm"; 
        echo ""
    done
}

function submodel_summary() {
    local model_name="$1"
    local submodel_name="$2"
    local model_file="$MODELS_DIR/$model_name"
    if [[ ! -f "$model_file" ]]; then
        echo "Model file not found: '$model_file'" >&2
        exit 1
    fi

    # Extract the submodel from the model file using awk, if empty then submodel not found
    submodel_src=$(awk -v submodel="$submodel_name" '
        BEGIN { in_submodel = 0; in_submodel_found = 0 }
        $1 == "0" && $2 == "FILE" {
            rest = $0
            sub(/^0[ \t]+FILE[ \t]+/, "", rest)
            if (rest == submodel) {
                in_submodel = 1; in_submodel_found = 1; print; next
            } else if (in_submodel) {
                in_submodel = 0
            }
        }
        in_submodel { print }
    ' "$model_file")

    if [[ -z "$submodel_src" ]]; then
        echo "Submodel not found: '$submodel_name'" >&2
        exit 1
    fi


    echo "$submodel_src" | submodel_header
    echo ""
    echo "**Parts BOM:**"
    echo ""
    echo "$submodel_src" | parts_bom
}

function part_summary() {
    local part_name="$1"
    local part_file="$PARTS_DIR/$part_name"
    if [[ ! -f "$part_file" ]]; then
        echo "Part file not found: '$part_file'" >&2
        exit 1
    fi
    cat "$part_file" | head -1 | sed 's/^0 /**Description:** /'
}

query_type=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --colour)
            query_type="colour"
            colour_name_or_code="$2"
            shift 2
            ;;
        --model)
            query_type="model"
            model_name="$2"
            shift 2
            ;;
        --part)
            query_type="part"
            part_name="$2"
            shift 2
            ;;
        --submodel)
            query_type="submodel"
            model_name="$2"
            submodel_name="$3"
            shift 3
            ;;
        *)
            usage
            ;;
    esac
done

if [[ -z "$query_type" ]]; then
    usage
fi

case "$query_type" in
    model)
        main_header "Model" "$model_name"
        model_summary "$model_name"
        ;;
    part)
        main_header "Part" "$part_name"
        part_summary "$part_name"
        ;;
    submodel)
        main_header "Model" "$model_name"
        submodel_summary "$model_name" "$submodel_name"
        ;;
    colour)
        colour_summary "$colour_name_or_code"
        ;;
    *)
        usage
        ;;
esac

