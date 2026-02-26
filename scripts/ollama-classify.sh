#!/bin/bash

# this script accepts an image as input and outputs a description, category and keywords for the image using ollama and a vision model
function usage() {
    echo "Usage: $0 <image file> <description file | - for stdout>"
    echo "Example: $0 image.jpg description.txt"
    exit 1
}

model="qwen2.5vl:3b"

img_file="$1"
desc_file="$2"

if [[ -z "$img_file" || -z "$desc_file" ]]; then
    usage
fi

if [[ ! -f "$img_file" ]]; then
    echo "Error: Image file '$img_file' does not exist."
    exit 1
fi

img_file="$(realpath "$img_file")"

read -r -d '' prompt <<'EOF'
For the following image: %s

Provide the following: category, description and 5 keywords

* Category: one of the following categories (choose the best fit):

- Space: Futuristic rockets, moon bases, aliens, and intergalactic exploration (e.g., Classic Space, Mars Mission, Galaxy Explorer).
- Castle: Medieval fortresses, knights, dragons, and peasant villages (e.g., classic Castle, Knights Kingdom, Lion Knights).
- Pirates: Galleons, treasure islands, imperial forts, and high-seas adventure.
- City / Town: Everyday urban life including police, fire, hospitals, construction sites, and civilian vehicles.
- Trains: Locomotives, passenger cars, cargo trains, and railway layouts (both 4.5v/12v and 9v/Power Functions eras).
- Technic: Function-over-form models featuring gears, axles, motors, and realistic mechanical functions (cars, cranes, aircraft).
- Vehicles: A broad category covering land, air, and sea transport that doesn't fit strictly into City (e.g., race cars, monster trucks, planes, helicopters, boats).
- Architecture: Famous skylines, landmarks, and buildings from the real world (e.g., Eiffel Tower, Fallingwater, Skyline series).
- Robots / Mecha: Posable humanoid robots, giant mechs, and buildable action figures (e.g., Exo-Force, Ninjago mechs, Titanfall-style builds).
- Fantasy / Mythical: Creatures and scenes involving magic, mythology, and folklore (e.g., elves, wizards, phoenixes, hydras).
- Dinosaurs / Prehistoric: Models of dinosaurs, ice age creatures, and caveman settings.
- Nautical / Submarine: Underwater exploration, submarines, deep-sea bases, and sunken treasure.
- Everyday Life / Interior: Detailed dollhouse-style builds including modular houses, rooms, furniture, cafes, and shops.
- Other: Any image that doesn't fit well into the above categories, including abstract builds, art pieces, and custom creations that defy categorization.

* Description: A one-liner description about the objects in the image, the "what is this". 
Do not mention that they are made of LEGO, just describe the scene and objects as if they were real. 
For example, "A red fire truck with an extended ladder and a firefighter climbing up to rescue a cat from a tree."

* Keywords: 5 keywords that describe the image, separated by commas. 
For example, "fire truck, firefighter, rescue, cat, tree".

Output format: JSON with the following structure:
{
  "category": "Category name",
  "description": "One-liner description of the image",
  "keywords": ["keyword1", "keyword2", "keyword3", "keyword4", "keyword5"]
}
EOF

# echo "Processing image '$(basename "$img_file")'..."
if [ "$desc_file" = "-" ]; then
    desc_file="/dev/stdout"
else
    touch "$desc_file"
    desc_file="$(realpath "$desc_file")"
fi

ollama run "$model" "$(printf "$prompt" "$img_file")" --hidethinking > "$desc_file"

