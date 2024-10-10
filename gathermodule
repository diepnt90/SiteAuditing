#!/bin/bash

# Create the temp_folder in the current directory
mkdir -p ./temp_folder

# Find the first PID of the process running '/usr/share/dotnet/dotnet'
pid=$(/tools/dotnet-dump ps | grep '/usr/share/dotnet/dotnet' | awk '{print $1}' | head -n 1)

# Check if PID is found
if [ -z "$pid" ]; then
  echo "No process found for '/usr/share/dotnet/dotnet'."
  exit 1
fi

# Extract the environment variables of the process
environ=$(cat "/proc/$pid/environ" | tr '\0' '\n')

# Extract WEBSITESITENAME from the environment variable
WEBSITESITENAME=$(echo "$environ" | grep '^WEBSITE_SITE_NAME=' | cut -d= -f2)

# Check if WEBSITESITENAME is found
if [ -z "$WEBSITESITENAME" ]; then
  echo "WEBSITESITENAME not found in environment."
  exit 1
fi

# Define the current date
current_date=$(date +%Y-%m-%d)

# Define the CSV file path
CSV_FILE="./temp_folder/${WEBSITESITENAME}_${current_date}.csv"

# Write the updated headers to the CSV file
echo "module_name,current_version,newest_version,links,notes,tag" > "$CSV_FILE"

# Loop through all .dll files in the /app directory and gather information
find /app -type f -name "*.dll" | while read dll_file
do
    # Extract the module name (file name without path)
    module_name=$(basename "$dll_file")

    # Get the modified date and time using stat, then trim to the desired format (YYYY-MM-DD HH:MM)
    current_version=$(stat -c %y "$dll_file" | cut -d'.' -f1 | cut -d':' -f1,2)

    # Append the information to the CSV file (leaving other columns empty)
    echo "$module_name,\"$current_version\",,,," >> "$CSV_FILE"
done

# Search for a *.deps.json file in the /app directory
deps_file=$(find /app -type f -name "*.deps.json" | head -n 1)

# Check if the .deps.json file is found
if [ -z "$deps_file" ]; then
  echo "No .deps.json file found in /app directory."
  exit 1
fi

# Rename the .deps.json file and move it to the temp_folder
deps_filename="${WEBSITESITENAME}_${current_date}.deps.json"
cp "$deps_file" "./temp_folder/$deps_filename"

# Upload the CSV and deps.json files using curl
upload_url="http://daulac.duckdns.org:8080/upload"
curl -F "file1=@./temp_folder/${WEBSITESITENAME}_${current_date}.csv" -F "file2=@./temp_folder/${deps_filename}" "$upload_url"

# Display the success message with the review link
echo "Link for review: http://daulac.duckdns.org:8080/${WEBSITESITENAME}_${current_date}"
