#!/bin/bash

# Set variables
REPO_OWNER="diepnt90"
REPO_NAME="SiteAuditing"
README_PATH="README.md"
API_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$README_PATH"
TEMP_FILE="temp_readme.md"
TABLE_FILE="table_content.md"

# Insert your GitHub API key here
GITHUB_API_KEY="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"

# Ensure the API key is present
if [ -z "$GITHUB_API_KEY" ]; then
  echo "Please set your GitHub API key in the script (GITHUB_API_KEY)."
  exit 1
fi

# Scan all DLL files in the /app folder
DLL_FILES=$(find /app -type f -name "*.dll")

# Prepare the updated table content and save it to a temporary file
echo "| Module                     | Date modified |Current Version | Newest version|Link| Bug   |" > "$TABLE_FILE"
echo "| -------------------------- |:---------------:|:---------------:| -------------:|-------------:| -----:|" >> "$TABLE_FILE"

for DLL_FILE in $DLL_FILES; do
  DLL_NAME=$(basename "$DLL_FILE")
  MODIFIED_DATE=$(stat -c "%y" "$DLL_FILE" | cut -d' ' -f1)
  echo "| $DLL_NAME | $MODIFIED_DATE | | | | |" >> "$TABLE_FILE"
done

# Fetch the README file from GitHub
echo "Fetching README.md from GitHub..."
RESPONSE=$(curl -s -H "Authorization: token $GITHUB_API_KEY" -H "Accept: application/vnd.github.v3.raw" "$API_URL")

if [ $? -ne 0 ]; then
  echo "Failed to fetch README.md from GitHub."
  exit 1
fi

# Write the content of README.md to a temp file
echo "$RESPONSE" > "$TEMP_FILE"

# Update the README.md content using awk
awk -v table_file="$TABLE_FILE" '
  BEGIN {print_table=0}
  /| Module/ {
    print_table=1
    while ((getline line < table_file) > 0) {
      print line
    }
    close(table_file)
    next
  }
  print_table==0 {print}
  print_table==1 && /^\|/ {next}
  print_table==1 && !/^\|/ {print_table=0}
' "$TEMP_FILE" > "updated_$TEMP_FILE"

# Get the SHA of the current README.md (required for updating via API)
SHA=$(curl -s -H "Authorization: token $GITHUB_API_KEY" "$API_URL" | grep '"sha"' | head -n 1 | cut -d '"' -f 4)

# Check if SHA is retrieved correctly
if [ -z "$SHA" ]; then
  echo "Failed to retrieve SHA. Please check your API credentials and permissions."
  exit 1
fi

# Update README.md on GitHub
echo "Updating README.md on GitHub..."
UPDATE_RESPONSE=$(curl -s -X PUT -H "Authorization: token $GITHUB_API_KEY" -H "Accept: application/vnd.github.v3+json" "$API_URL" -d @- <<EOF
{
  "message": "Update DLL modified dates in README.md",
  "content": "$(base64 -w 0 < updated_$TEMP_FILE)",
  "sha": "$SHA"
}
EOF
)

# Clean up temporary files
rm "$TEMP_FILE" "updated_$TEMP_FILE" "$TABLE_FILE"

# Check if the update was successful
if echo "$UPDATE_RESPONSE" | grep -q '"commit"'; then
  echo "README.md updated successfully."
else
  echo "Failed to update README.md. Response:"
  echo "$UPDATE_RESPONSE"
fi
