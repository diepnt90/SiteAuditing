#!/bin/bash

# Step 1: Install jq
apt-get install jq -y

# Step 2: Create or recreate "temp_folder"
if [ -d "./temp_folder" ]; then
  rm -rf ./temp_folder
fi
mkdir ./temp_folder

# Step 3: Download the module.json from the GitHub repository
curl -o ./temp_folder/module.json https://raw.githubusercontent.com/diepnt90/SiteAuditing/main/module.json

# Step 4: Scan all .dll files in the /app folder and save them into a temp file
find /app -type f -name "*.dll" > ./temp_folder/dll_files.txt

# Step 5: Iterate over each .dll file, check if it's in the module.json and update accordingly
while read dll_file; do
  dll_name=$(basename "$dll_file")

  # Check if the DLL file is found in the module.json with tag: "1"
  jq_filter=".[] | select(.module_name == \"$dll_name\" and .tag == \"1\")"
  module=$(jq "$jq_filter" ./temp_folder/module.json)

  if [ -n "$module" ]; then
    # Extract the last modified date of the DLL file
    modified_date=$(stat -c %y "$dll_file" | cut -d'.' -f1)

    # Update the modified_date in the module.json for the matching DLL
    jq --arg dll "$dll_name" --arg date "$modified_date" \
      '(.[] | select(.module_name == $dll and .tag == "1") | .modified_date) = $date' \
      ./temp_folder/module.json > ./temp_folder/temp.json && mv ./temp_folder/temp.json ./temp_folder/module.json
  else
    # Step 6: If the DLL is not found in module.json, add a new object for it with "tag": "2"
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

    # Append the new object to module.json
    jq ". += [$new_entry]" ./temp_folder/module.json > ./temp_folder/temp.json && mv ./temp_folder/temp.json ./temp_folder/module.json
  fi

done < ./temp_folder/dll_files.txt

# Step 7: After processing, remove all objects with "tag": "0"
jq 'del(.[] | select(.tag == "0"))' ./temp_folder/module.json > ./temp_folder/temp.json && mv ./temp_folder/temp.json ./temp_folder/module.json

# Step 8: Convert the module.json to a table format and save it as a txt file

# Define the output file
output_file="./temp_folder/module_table.txt"

# Print headers with dotted lines into the output file
echo "Module Name             | Modified Date        | Current Version | Newest Version | Links | Notes | Tag" > "$output_file"
echo "------------------------|----------------------|-----------------|----------------|-------|-------|----" >> "$output_file"

# Iterate through each entry in the module.json and format it as a table row
jq -r '.[] | [.module_name, .modified_date, .current_version, .newest_version, .links, .notes, .tag] | @tsv' ./temp_folder/module.json | while IFS=$'\t' read -r module_name modified_date current_version newest_version links notes tag; do
    # Print each line in table format, aligning columns properly
    printf "%-23s | %-20s | %-15s | %-14s | %-5s | %-5s | %-2s\n" \
    "$module_name" "$modified_date" "$current_version" "$newest_version" "$links" "$notes" "$tag" >> "$output_file"
done
# Step 9: Upload the updated module.txt to file.io and output the download link
upload_response=$(curl -F "file=@./temp_folder/module.txt" https://file.io)
echo "Download link: $(echo $upload_response | jq -r '.link')"

# Step 10: Clean up the temp_folder
rm -rf ./temp_folder
