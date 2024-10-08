#!/bin/bash

# Step 1: Install jq
echo "Installing jq..."
apt-get install jq -y

# Step 2: Create or recreate "temp_folder"
echo "Creating temp folder..."
if [ -d "./temp_folder" ]; then
  echo "Cleaning up previous temp folder..."
  rm -rf ./temp_folder
fi
mkdir ./temp_folder

# Step 3: Download the module.json from the GitHub repository
echo "Downloading module.json from GitHub..."
curl -o ./temp_folder/module.json https://raw.githubusercontent.com/diepnt90/SiteAuditing/main/module.json
if [ $? -eq 0 ]; then
  echo "Downloaded module.json successfully."
else
  echo "Failed to download module.json."
  exit 1
fi

# Step 4: Scan all .dll files in the /app folder and save them into a temp file
echo "Scanning for DLL files in /app folder..."
find /app -type f -name "*.dll" > ./temp_folder/dll_files.txt
echo "DLL scan completed."

# Step 5: Iterate over each .dll file, check if it's in the module.json and update accordingly
echo "Processing DLL files..."
while read dll_file; do
  dll_name=$(basename "$dll_file")

  # Check if the DLL file is found in the module.json with tag: "1"
  jq_filter=".[] | select(.module_name == \"$dll_name\" and .tag == \"1\")"
  module=$(jq "$jq_filter" ./temp_folder/module.json)

  if [ -n "$module" ]; then
    echo "Found $dll_name in module.json with tag '1'."
    modified_date=$(stat -c %y "$dll_file" | cut -d'.' -f1)

    jq --arg dll "$dll_name" --arg date "$modified_date" \
      '(.[] | select(.module_name == $dll and .tag == "1") | .modified_date) = $date' \
      ./temp_folder/module.json > ./temp_folder/temp.json && mv ./temp_folder/temp.json ./temp_folder/module.json
    
    if [ $? -eq 0 ]; then
      echo "Successfully updated modified_date for $dll_name."
    else
      echo "Failed to update modified_date for $dll_name."
    fi
  else
    echo "$dll_name not found in module.json. Adding a new object with tag '2'."
    modified_date=$(stat -c %y "$dll_file" | cut -d'.' -f1)
    new_entry=$(jq -n --arg dll "$dll_name" --arg date "$modified_date" '{
      module_name: $dll,
      modified_date: $date,
      current_version: "",
      newest_version: "",
      links: "",
      notes: "",
      tag: "2"
    }')

    jq ". += [$new_entry]" ./temp_folder/module.json > ./temp_folder/temp.json && mv ./temp_folder/temp.json ./temp_folder/module.json
    
    if [ $? -eq 0 ]; then
      echo "Successfully added $dll_name to module.json."
    else
      echo "Failed to add $dll_name to module.json."
    fi
  fi
done < ./temp_folder/dll_files.txt

# Step 7: Remove all objects with "tag": "0"
echo "Removing all objects with tag '0'..."
jq 'del(.[] | select(.tag == "0"))' ./temp_folder/module.json > ./temp_folder/temp.json && mv ./temp_folder/temp.json ./temp_folder/module.json
if [ $? -eq 0 ]; then
  echo "Successfully removed objects with tag '0'."
else
  echo "Failed to remove objects with tag '0'."
fi

# Step 8: Remove objects with "modified_date" set to an empty string
echo "Removing objects with empty 'modified_date'..."
jq 'del(.[] | select(.modified_date == ""))' ./temp_folder/module.json > ./temp_folder/temp.json && mv ./temp_folder/temp.json ./temp_folder/module.json
if [ $? -eq 0 ]; then
  echo "Successfully removed objects with empty 'modified_date'."
else
  echo "Failed to remove objects with empty 'modified_date'."
fi

# Step 9: Check and update the "newest_version" based on the "links" field
echo "Updating newest_version for each module based on links..."
jq -c '.[]' ./temp_folder/module.json | while read module; do
  links=$(echo "$module" | jq -r '.links')
  newest_version=""

  if [[ $links == *"github.com"* ]]; then
    release_version=$(curl -s "$links" | grep -oP '(?<=/releases/tag/)[^"]*')
    newest_version=$release_version
    echo "GitHub link detected for $(echo "$module" | jq -r '.module_name'). Latest version: $newest_version."
  elif [[ $links == *"nuget.optimizely.com"* ]]; then
    newest_version=$(curl -s "$links" | grep -oP "(?<=document.title = ')[^']*")
    # Extract only the version number by removing the name part
    newest_version=$(echo "$newest_version" | sed 's/.*\s\([0-9.]*\)$/\1/')
    echo "Nuget.Optimizely link detected for $(echo "$module" | jq -r '.module_name'). Latest version: $newest_version."
  elif [[ $links == *"api.nuget.org"* ]]; then
    newest_version=$(curl -s "$links" | jq -r '.versions[-1]')
    echo "API.Nuget.org link detected for $(echo "$module" | jq -r '.module_name'). Latest version: $newest_version."
  else
    echo "No valid link found for $(echo "$module" | jq -r '.module_name'). Skipping."
  fi

  if [ -n "$newest_version" ]; then
    module_name=$(echo "$module" | jq -r '.module_name')
    jq --arg dll "$module_name" --arg version "$newest_version" \
      '(.[] | select(.module_name == $dll) | .newest_version) = $version' \
      ./temp_folder/module.json > ./temp_folder/temp.json && mv ./temp_folder/temp.json ./temp_folder/module.json
    
    if [ $? -eq 0 ]; then
      echo "Successfully updated newest_version for $module_name."
    else
      echo "Failed to update newest_version for $module_name."
    fi
  fi
done

# Step 10: Remove the "links" field from all objects
echo "Removing the 'links' field from all objects..."
jq 'del(.[] | .links)' ./temp_folder/module.json > ./temp_folder/temp.json && mv ./temp_folder/temp.json ./temp_folder/module.json
if [ $? -eq 0 ]; then
  echo "'links' field successfully removed from all objects."
else
  echo "Failed to remove 'links' field."
fi

# Step 11: Upload the updated module.json to file.io and output the download link
echo "Uploading updated module.json to file.io..."
upload_response=$(curl -F "file=@./temp_folder/module.json" https://file.io)
upload_link=$(echo $upload_response | jq -r '.link')
if [ $? -eq 0 ]; then
  echo "Upload successful. Download link: $upload_link"
else
  echo "Failed to upload module.json."
fi

# Step 12: Clean up the temp_folder
echo "Cleaning up temp_folder..."
rm -rf ./temp_folder
echo "Cleanup complete."
