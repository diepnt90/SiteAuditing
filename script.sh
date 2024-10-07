#!/bin/bash

# Step 1: Install jq without sudo
apt-get install -y jq

# Step 2: Make the temp_folder in the current directory
TEMP_FOLDER="./temp_folder"
mkdir -p "$TEMP_FOLDER"

# Step 3: Go to the temp_folder
cd "$TEMP_FOLDER" || exit

# Step 4: Download the JSON file from GitHub
curl -L -o modules.json https://raw.githubusercontent.com/diepnt90/SiteAuditing/main/modules.json

# Step 5 & 6: Gather all DLL files in folder /app and update the JSON
APP_DIR="/app"
for dll_file in "$APP_DIR"/*.dll; do
    dll_name=$(basename "$dll_file")
    
    # Check if module_name exists in JSON and tag = 1
    jq_filter='.[] | select(.module_name == "'"$dll_name"'" and .tag == "1")'
    module_exists=$(jq "$jq_filter" modules.json)

    if [[ -n "$module_exists" ]]; then
        # Update modified_date of the DLL file
        modified_date=$(stat -c %y "$dll_file" | cut -d' ' -f1)
        jq '(.[] | select(.module_name == "'"$dll_name"'" and .tag == "1") | .modified_date) |= "'"$modified_date"'"' modules.json > temp.json && mv temp.json modules.json
        
        # Find version in .deps.json
        for deps_file in "$APP_DIR"/*.deps.json; do
            version=$(jq -r 'to_entries[] | select(.value.runtime | has("lib/net6.0/'"$dll_name"'")) | .key' "$deps_file" | awk -F '/' '{print $2}')
            if [[ -n "$version" ]]; then
                jq '(.[] | select(.module_name == "'"$dll_name"'" and .tag == "1") | .current_version) |= "'"$version"'"' modules.json > temp.json && mv temp.json modules.json
            fi
        done
    else
        # Add new module if it doesn't exist in JSON
        jq --arg module_name "$dll_name" --arg tag "2" \
           '. += [{module_name: $module_name, modified_date: "", current_version: "", newest_version: "", links: "", notes: "", tag: $tag}]' \
           modules.json > temp.json && mv temp.json modules.json
    fi
done

# Step 7: Reorder the downloaded JSON with the date modified desc
jq 'sort_by(.modified_date) | reverse' modules.json > temp.json && mv temp.json modules.json

# Step 8: Upload the downloaded JSON to file.io
response=$(curl -F "file=@modules.json" https://file.io)

# Step 9: Get the downloaded link and show to the screen
download_link=$(echo "$response" | jq -r '.link')
echo "Download link: $download_link"

# Step 10: Clear the temp_folder
cd ..
rm -rf "$TEMP_FOLDER"
