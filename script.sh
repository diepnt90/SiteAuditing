#!/bin/bash

# Define the output markdown file
OUTPUT_FILE="dll_updates.md"

# Write the headers to the markdown file
echo -e "Module Name\tModified Date\tCurrent Version\tNewest Version\tLinks\tNotes" > "$OUTPUT_FILE"

# Directory containing the DLL files
DLL_DIR="/app"

# Loop through each DLL file in the directory
find "$DLL_DIR" -name "*.dll" | while read -r dll_file; do
    # Extract the module name from the DLL file path
    module_name=$(basename "$dll_file")

    # Get the modified date of the DLL file
    modified_date=$(date -r "$dll_file" +"%Y-%m-%d")

    # Dummy current version for example purposes (extracting the version can be customized)
    # Here we are using a default "1.0.0", you should replace this logic with actual version retrieval
    current_version="1.0.0"

    # Dummy newest version for example purposes
    # You could replace this with a logic that pulls the actual latest version (perhaps from a database or API)
    newest_version="1.2.0"

    # Define the link for reference, here we put a placeholder
    link="Release Notes"

    # Determine if the module needs updating or is up-to-date
    if [ "$current_version" == "$newest_version" ]; then
        notes="Up-to-date"
    else
        notes="Needs updating"
    fi

    # Append the information to the output markdown file
    echo -e "$module_name\t$modified_date\t$current_version\t$newest_version\t$link\t$notes" >> "$OUTPUT_FILE"
done

echo "DLL information has been updated in $OUTPUT_FILE."
