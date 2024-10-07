#!/bin/bash

# Function to print debug messages
debug() {
    echo "[DEBUG] $1"
}

error() {
    echo "[ERROR] $1"
}

debug "Script started"

# 1. Install jq using apt-get if not already installed
if ! command -v jq &> /dev/null; then
    debug "jq is not installed. Attempting to install..."
    if [ "$(id -u)" -ne 0 ]; then
        error "This script requires sudo privileges to install jq. Please run with sudo or as root."
        exit 1
    fi
    apt-get install -y jq
    if [ $? -ne 0 ]; then
        error "Failed to install jq"
        exit 1
    fi
    debug "jq installation completed"
else
    debug "jq is already installed"
fi

# 2. Create temp_folder in the current directory
mkdir -p temp_folder
debug "temp_folder created"

# 3. Go to temp_folder
cd temp_folder
debug "Changed directory to temp_folder"

# 4. Download the JSON file
curl -L https://raw.githubusercontent.com/diepnt90/SiteAuditing/main/README.md -o modules.json
if [ $? -ne 0 ]; then
    error "Failed to download modules.json"
    exit 1
fi
debug "JSON file downloaded"

# 5 & 6. Process DLL files
debug "Starting to process DLL files"
for dll in /app/*.dll; do
    if [ -f "$dll" ]; then
        filename=$(basename "$dll")
        debug "Processing $filename"
        modified_date=$(stat -c %y "$dll")
        
        # Update existing entries or create new ones
        jq --arg filename "$filename" \
           --arg modified_date "$modified_date" \
           '(.[] | select(.module_name == $filename and .tag == "1") | .modified_date) |= $modified_date' modules.json > temp.json && mv temp.json modules.json
        debug "Updated modified date for $filename"

        # Check for version in deps.json files
        for deps_file in /app/*.deps.json; do
            if [ -f "$deps_file" ]; then
                debug "Checking $deps_file for version of $filename"
                version=$(jq -r --arg dll "$filename" 'to_entries[] | select(.key | contains($dll | rtrimstr(".dll"))) | .key | split("/")[1]' "$deps_file")
                if [ $? -ne 0 ]; then
                    error "Error parsing $deps_file"
                    debug "Content of $deps_file:"
                    cat "$deps_file"
                    continue
                fi
                if [ ! -z "$version" ]; then
                    jq --arg filename "$filename" \
                       --arg version "$version" \
                       '(.[] | select(.module_name == $filename and .tag == "1") | .current_version) |= $version' modules.json > temp.json && mv temp.json modules.json
                    debug "Updated current version for $filename to $version"
                else
                    debug "Version not found for $filename in $deps_file"
                fi
            fi
        done

        # 7. Create new entry if not exists
        if ! jq --arg filename "$filename" '.[] | select(.module_name == $filename)' modules.json | grep -q .; then
            jq --arg filename "$filename" '. += [{"module_name": $filename, "modified_date": "", "current_version": "", "newest_version": "", "links": "", "notes": "", "tag": "2"}]' modules.json > temp.json && mv temp.json modules.json
            debug "Created new entry for $filename"
        fi
    fi
done
debug "Finished processing DLL files"

# 7. Reorder by modified date
jq 'sort_by(.modified_date) | reverse' modules.json > temp.json && mv temp.json modules.json
debug "JSON file reordered by modified date"

# 8. Upload to file.io
debug "Uploading JSON file to file.io"
response=$(curl -F "file=@modules.json" https://file.io)
if [ $? -ne 0 ]; then
    error "Failed to upload file to file.io"
    exit 1
fi
debug "Upload completed"

# 9. Extract and display the download link
download_link=$(echo $response | jq -r .link)
if [ -z "$download_link" ]; then
    error "Failed to extract download link from file.io response"
    debug "file.io response: $response"
else
    echo "Download link: $download_link"
    debug "Download link extracted and displayed"
fi

# 10. Clear temp_folder
cd ..
rm -rf temp_folder
debug "temp_folder cleared"

debug "Script completed"
