#!/bin/bash

# Step 1: Create a temporary folder
temp_folder="temp_folder"
mkdir -p "$temp_folder"
cd "$temp_folder" || exit

# Step 2: Download README.md
curl -o README.md https://raw.githubusercontent.com/diepnt90/SiteAuditing/main/README.md

# Step 3: Scan all DLLs in the /app directory
app_directory="../app"
readme_file="README.md"

if [[ ! -d "$app_directory" ]]; then
  echo "The directory $app_directory does not exist."
  exit 1
fi

# Loop through all DLLs in the /app directory
for dll in "$app_directory"/*.dll; do
  # Skip if no DLLs found
  [[ -e "$dll" ]] || continue

  dll_name=$(basename "$dll")
  dll_modified_date=$(date -r "$dll" "+%Y-%m-%d %H:%M:%S")

  # Check if the DLL is in the README.md and has tag=1
  if grep -q "$dll_name.*tag=1" "$readme_file"; then
    # Update the README.md with the DLL modified date
    sed -i "/$dll_name/s/\(modified_date: \)\(.*\)/\1$dll_modified_date/" "$readme_file"
  fi
done

# Step 4: Upload the modified README.md to file.io
response=$(curl -F "file=@$readme_file" https://file.io)

# Step 5: Extract and output the link
link=$(echo "$response" | grep -o '"link":"[^"]*' | cut -d'"' -f4)
echo "Download link: $link"
