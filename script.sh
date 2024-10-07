#!/bin/bash

# Step 1: Create a temporary folder
temp_folder="temp_folder"
mkdir -p "$temp_folder"
cd "$temp_folder" || exit

# Step 2: Download README.md
curl -o README.md https://raw.githubusercontent.com/diepnt90/SiteAuditing/main/README.md

# Step 3: Scan all DLLs in the /app directory
app_directory="/app"
readme_file="README.md"

if [[ ! -d "$app_directory" ]]; then
  echo "The directory $app_directory does not exist."
  exit 1
fi

# Step 4: Check if jq is installed, if not install it
if ! command -v jq &> /dev/null
then
    echo "jq is not installed. Installing jq..."
    apt-get install -y jq
fi

# Step 5: Read the content of README.md and format it to eliminate any formatting discrepancies
readme_content=$(cat "$readme_file" | jq '.')

# Loop through all DLLs in the /app directory
for dll in "$app_directory"/*.dll; do
  # Skip if no DLLs found
  [[ -e "$dll" ]] || continue

  # Get the name of the DLL file, including the .dll extension
  dll_name=$(basename "$dll")

  # Get the Modify date using stat command
  dll_modified_date=$(stat "$dll" | grep 'Modify:' | awk '{print $2, $3}' | cut -d'.' -f1)

  # Check if the DLL is in the README.md and has tag=1, then update modified_date
  updated_content=$(echo "$readme_content" | jq --arg dll_name "$dll_name" --arg modified_date "$dll_modified_date" '
    map(
      if .module_name == $dll_name and .tag == "1" then
        .modified_date = $modified_date
      else
        .
      end
    )')

  # Update readme_content for the next iteration
  readme_content="$updated_content"

  # Debug message when updating
  if echo "$updated_content" | jq --arg dll_name "$dll_name" 'map(select(.module_name == $dll_name and .tag == "1"))' | grep -q "$dll_name"; then
    echo "Updated modified date for DLL: $dll_name with date: $dll_modified_date"
  else
    echo "DLL: $dll_name not updated, either not found or tag is not set to 1."
  fi
done

# Step 6: Write the updated content back to README.md
echo "$readme_content" > "$readme_file"

# Step 7: Upload the modified README.md to file.io
response=$(curl -F "file=@$readme_file" https://file.io)

# Step 8: Extract and output the link
link=$(echo "$response" | grep -o '"link":"[^"]*' | cut -d'"' -f4)
echo "Download link: $link"
