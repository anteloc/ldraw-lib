#!/bin/bash

parent_dir="$(dirname "$0")/.."
parent_dir="$(realpath "$parent_dir")"

function usage() {
    echo "Usage: $0 <--search | --copy> <prop kind>"
    echo "Examples:"
    echo "  $0 --search sword # will show results for sword props"
    echo "  $0 --copy sword # will copy the sword props, same as found before, to ./minifig-props"
}

operation="${1:-}"
prop_kind="${2:-}"

# Verify all required arguments are provided
if [ -z "$operation" ] || [ -z "$prop_kind" ]; then
    usage
    exit 1
fi

case "$operation" in
    --search)
        echo "Searching for minifig props of kind: $prop_kind"
        rg --pcre2 -i -d 1 "^0 (Minifig|Bar) (?!Head\b|Torso\b|Hips\b|Leg\b|Arm\b|Hand\b).*(${prop_kind}).*" "$parent_dir/ldraw/parts" | less
        ;;
    --copy)
        echo "Copying minifig props of kind: $prop_kind to ./minifig-props"
        rg --pcre2 -l -i -d 1 "^0 (Minifig|Bar) (?!Head\b|Torso\b|Hips\b|Leg\b|Arm\b|Hand\b).*(${prop_kind}).*" "$parent_dir/ldraw/parts" | xargs -I{} cp {} "$parent_dir/minifig-props"
        ;;
    *)
        usage
        exit 1
        ;;
esac

