#!/bin/bash

models_idx="$1"
models_dir="$2"
thumbs_dir="$3"

if [ -z "$models_idx" ] || [ -z "$models_dir" ] || [ -z "$thumbs_dir" ]; then
    echo "Usage: $0 <models index file> <models directory> <thumbnails directory>"
    echo "Shows a summary of each model from the index file, and opens its thumbnail if available for inspection"
    exit 1
fi

# line: {"category":"Trains","description":"A model train on a circular track, featuring a locomotive and passenger cars.","keywords":["model train","circular track","locomotive","passenger cars","train model"],"name":"10001-1_B-Model-from-Instruction.mpd.zip"}
while IFS= read -r line; do

    echo "$line" >&2

    m_name=$(echo "$line" | jq -r '.name')
    m_category=$(echo "$line" | jq -r '.category')
    m_desc=$(echo "$line" | jq -r '.description')

    # remove any file extension, even if there are multiple (e.g. .mpd.zip)
    m_basename="${m_name%%.*}"
    # m_basename="$(basename "$m_name" .mpd.zip)"

    m_file="$models_dir/$m_basename.mpd"
    m_file_packed="${models_dir}-packed/$m_basename.mpd.zip"

    m_file_size=$(stat -f%z "$m_file")
    m_file_packed_size=$(stat -f%z "$m_file_packed")

    m_file_size_kb=$((m_file_size / 1024))
    m_file_packed_size_kb=$((m_file_packed_size / 1024))
    

    m_thumb="${m_basename}.png"
    thumb_path="$thumbs_dir/$m_thumb"

    echo "==================================================" >&2
    echo "Model: '$m_name', Size: ${m_file_size_kb}KB (Packed: ${m_file_packed_size_kb}KB)" >&2
    echo "Category: '$m_category'" >&2
    echo "Keywords: $(echo "$line" | jq -r '.keywords | join(", ")')" >&2
    echo "Description: '$m_desc'" >&2
    echo "==================================================" >&2

    if [ ! -f "$thumb_path" ]; then
        echo "MISSING thumbnail for: '$m_name'..."
    else 
        open "$thumb_path"
    fi

    # wait for keypress before moving to the next one
    # read from /dev/tty to avoid issues if the input is being piped from a file
    echo "Press any key to continue to the next model..." >&2
    read -n 1 -s < /dev/tty
   
done < "$models_idx"