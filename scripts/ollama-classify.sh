#!/bin/bash

# this script accepts an image as input and outputs a description, category and keywords for the image using ollama and a vision model
function usage() {
    echo "Usage: $0  <models-dir> <description file | - for stdout> <image file>... "
    echo "Example: $0 models/ description.txt image1.jpg image2.jpg"
    echo "If models-dir is provided, it will be used to extract hints for the classification, based on the model's file header."
    exit 1
}

function hints() {
    local img_file="$1"
    local m_description=""
    local m_file_line=""

    local model_file="$models_dir/$(basename "$img_file" .png).mpd"

    # description will be either the first line or the 2nd one if the first is a FILE meta line.
    local fst_2_lines="$(head -n 2 "$model_file" | tr -d '\r')"
    
    local fst_line="$(echo "$fst_2_lines" | head -n 1)"
    local sec_line="$(echo "$fst_2_lines" | tail -n 1)"

    # classify the file and description lines
    if [[ "$fst_line" =~ ^0[[:space:]]+FILE ]]; then
        # keep the FILE line, but discard 0 FILE from the description and also its extension
        m_model_name="$(echo "$fst_line" | sed -e 's/^0 FILE *//' -e 's/\.[^.]*$//')"
        local m_desc_line="$sec_line"

        # keep the longest one: sometimes the description is not meaningful, some others it's the file line, so we keep the one with more content
        if [ ${#m_file_line} -gt ${#m_desc_line} ]; then
            m_description="$m_file_line"
        else
            m_description="$m_desc_line"
        fi
    else
        # when no FILE line is present, the description is just the first line
        m_description="$fst_line"
    fi
    
    # sanitize description: replace all non-alphanumeric characters with a single space, then trim leading and trailing spaces, etc.
    m_description="$(echo "$m_description" | sed -E 's/[^a-zA-Z0-9]+/ /g' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"

    # output one json object per file, then combine them into a json array at the end
    echo -e "

* Image: $img_file
Model name hint: $m_model_name
Model description hint: $m_description

"
}

# vl_model="qwen3-vl:2b" # thinking, vision - slow and makes mistakes on json outputs  (local)
# vl_model="qwen3-vl:4b" # thinking, vision - slow (local)
vl_model="qwen2.5vl:3b" # vision - faster but doesn't understand hints as well (local)

models_dir="$1"
desc_file="$2"
prompt_hints=""

if [[ -z "$models_dir" || -z "$desc_file" ]]; then
    usage
fi

models_dir="$(realpath "$models_dir")"

if [ ! -d "$models_dir" ]; then
    echo "Error: Models directory '$models_dir' does not exist."
    exit 1
fi

# build model hints for every image
shift 2

while [ "$#" -gt 0 ]; do
    img_file="$1"
    if [ -f "$img_file" ]; then
        img_file="$(realpath "$img_file")"
        prompt_hints+="$(hints "$img_file")"
    else
        echo "Warning: Image file '$img_file' does not exist, skipping."
    fi
    shift
done

img_file="$(realpath "$img_file")"

read -r -d '' vl_prompt_tmpl <<'EOF'
For the following: 

%s

Provide the following: category, description and 5 keywords.

* Output format, JSON with the following structure:
{
  "category": "Category name",
  "description": "One-liner description of the image",
  "keywords": ["keyword1", "keyword2", "keyword3", "keyword4", "keyword5"]
}

* Category: one of the following categories (choose the best fit):

- Space: rockets, moon bases, aliens, spaceships, etc.
- Castle: fortresses, knights, dragons, peasant villages, etc.
- Pirates: Galleons, treasure, forts, high-seas adventure, etc.
- City / Town: urban life, police, fire, hospitals, construction sites, civilian vehicles, etc.
- Trains: locomotives, passenger cars, cargo trains, railway layouts, etc.
- Technic: function-over-form models featuring gears, axles, motors, realistic mechanical functions (cars, cranes, aircraft), etc.
- Vehicles: a broad category covering land, air, and sea transport that doesn't fit strictly into City (e.g., race cars, monster trucks, planes, helicopters, boats), etc.
- Architecture: famous skylines, landmarks, and buildings from the real world (e.g., Eiffel Tower, Fallingwater, Skyline series), etc.
- Robots / Mecha: posable humanoid robots, giant mechs, and buildable action figures (e.g., Exo-Force, Ninjago mechs, Titanfall-style builds), etc.
- Fantasy / Mythical: creatures and scenes involving magic, mythology, and folklore (e.g., elves, wizards, phoenixes, hydras), etc.
- Dinosaurs / Prehistoric: models of dinosaurs, ice age creatures, and caveman settings, etc.
- Nautical / Submarine: underwater exploration, submarines, deep-sea bases, and sunken treasure, etc.
- Everyday Life / Interior: detailed dollhouse-style builds including modular houses, rooms, furniture, cafes, and shops, etc.
- Other: any image that doesn't fit well into the above categories, including abstract builds, art pieces, and custom creations that defy categorization, etc.

* Description: A one-liner, brief description about the objects in the image, the "what is this". 
Describe the objects on the scene AS THEY ARE, as if they were real.
If the image represents a humanoid form, if it's a famous character or popular object on the internet, provide the character's or object's name.
If the image file name contains a meaningful description, you can use it as part of the description, but do not just repeat the file name as is.
DO NOT try to guess what people, animals or objects are doing or the context of the scene.
DO NOT try to guess what the objects are made of.
DO NOT use the word LEGO.
DO NOT start the description with "This image shows..." or "A train..." similar phrases, just provide the description directly.

Examples:
"Red fire truck with an extended ladder, a firefighter, a cat and a tree."
"Sports car with a sleek design, painted in bright red."
"Luke Skywalker from Star Wars, in white outfit, brown belt, holding a blue lightsaber."
"The Eiffel Tower, wrought-iron lattice tower detail."
"X-wing starfighter from Star Wars, wings forming an 'X' in attack position."

Counterexamples:
"This image shows a red fire truck with an extended ladder, a firefighter, a cat and a tree."
"A sports car with a sleek design, painted in bright red."
"An image of Luke Skywalker from Star Wars, in white outfit, brown belt, holding a blue lightsaber."
"The Eiffel Tower, wrought-iron lattice tower detail in this image."

* Keywords: 5 keywords that describe the image, separated by commas. 

Examples: 
"fire truck, firefighter, rescue, cat, tree".
"car, sports car, red, sleek, vehicle".
"Luke Skywalker, Star Wars, lightsaber, hero, character".

EOF

# echo "Processing image '$(basename "$img_file")'..."
if [ "$desc_file" = "-" ]; then
    desc_file="/dev/stdout"
else
    touch "$desc_file"
    desc_file="$(realpath "$desc_file")"
fi

vl_prompt="$(printf "$vl_prompt_tmpl" "$prompt_hints")"

# echo "===== PROMPT =====" >&2
# echo "$vl_prompt" >&2
# echo "==================" >&2


ollama run "$vl_model" "$vl_prompt" --hidethinking --verbose > "$desc_file"

