#!/bin/bash

scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"
parent_dir="$(dirname "$scripts_dir")"

MODELS_DIR="$parent_dir/models-annotated"
PARTS_DIR="$parent_dir/ldraw/parts"
COLOURS_FILE="$parent_dir/ldraw/LDConfig.ldr"

function usage() {
    echo "Usage: $(basename "$0") <--colour <colour_name or colour_code> | --model <model_name> | --part <part_name> | --submodel <model_name> <submodel_name>>"
    echo "Returns the source code for either a part, a model or a submodel from a model, or if given a colour name it returns the code, and viceversa."
    echo "Example: "
    echo "$(basename "$0") --part 71944.dat"
    echo "$(basename "$0") --model 3001.mpd"
    echo "$(basename "$0") --submodel 3001.mpd '41606 - Step 30.ldr'"
    echo "$(basename "$0") --colour Blue # returns: 1"
    echo "$(basename "$0") --colour 1 # returns: Blue"
    echo "$(basename "$0") --submodel 3001.mpd '41606 - Step 30.ldr'"
    exit 1
}

function colour_src() {
    local name_or_code="$1"
    found_name_or_code=$(awk -v name_or_code="$name_or_code" '
        $1 == "0" && $2 == "!COLOUR" && toupper($3) == toupper(name_or_code) { print $5; exit;}
        $1 == "0" && $2 == "!COLOUR" && $5 == name_or_code { print $3; exit;}' "$COLOURS_FILE")

    if [[ -z "$found_name_or_code" ]]; then
        echo "Colour not found: '$name_or_code'" >&2
        exit 1
    fi
    echo "$found_name_or_code"
}

function model_src() {
    local model_name="$1"
    local model_file="$MODELS_DIR/$model_name"
    if [[ ! -f "$model_file" ]]; then
        echo "Model file not found: '$model_file'" >&2
        exit 1
    fi
    cat "$model_file"
}

function submodel_src() {
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
    echo "$submodel_src"
}

function part_src() {
    local part_name="$1"
    local part_file="$PARTS_DIR/$part_name"
    if [[ ! -f "$part_file" ]]; then
        echo "Part file not found: '$part_file'" >&2
        exit 1
    fi
    cat "$part_file"
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
        model_src "$model_name"
        ;;
    part)
        part_src "$part_name"
        ;;
    submodel)
        submodel_src "$model_name" "$submodel_name"
        ;;
    colour)
        colour_src "$colour_name_or_code"
        ;;
    *)
        usage
        ;;
esac

