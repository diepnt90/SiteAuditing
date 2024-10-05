#!/bin/bash

# Set variables
REPO_OWNER="diepnt90"
REPO_NAME="SiteAuditing"
README_PATH="README.md"
API_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$README_PATH"
TEMP_FILE="temp_readme.md"

# Insert your GitHub API key here
GITHUB_API_KEY="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"

# Ensure the API key is present
if [ -z "$GITHUB_API_KEY" ]; then
  echo "Please set your GitHub API key in the script (GITHUB_API_KEY)."
  exit 1
fi

# Ensure jq is installed, install it if not
if ! command -v jq &> /dev/null; then
  echo "jq is not installed. Installing jq..."
  apt-get install -y jq
fi

# Scan all DLL files in the /app folder
DLL_FILES=$(find /app -type f -name "*.dll")

# Prepare the updated table content
UPDATED_TABLE="| Module                     | Date modified |Current Version | Newest version|Link| Bug   |\n"
UPDATED_TABLE+="| -------------------------- |:---------------:|:---------------:| -------------:|-------------:| -----:|\n"

for DLL_FILE in $DLL_FILES; do
  DLL_NAME=$(basename "$DLL_FILE")
  MODIFIED_DATE=$(stat -c "%y" "$DLL_FILE" | cut -d' ' -f1)
  UPDATED_TABLE+="| $DLL_NAME | $MODIFIED_DATE | | | | |\n"
done

# Fetch the README file from GitHub
echo "Fetching README.md from GitHub..."
RESPONSE=$(curl -s -H "Authorization: token $GITHUB_API_KEY" "$API_URL")

if [ $? -ne 0 ]; then
  echo "Failed to fetch README.md from GitHub."
  exit 1
fi

# Extract content and SHA from the GitHub API response
CONTENT=$(echo "$RESPONSE" | jq -r '.content' | base64 -d)
SHA=$(echo "$RESPONSE" | jq -r '.sha')

if [ -z "$CONTENT" ] || [ -z "$SHA" ]; then
  echo "Failed to extract content or SHA from the GitHub response."
  exit 1
fi

# Update the README.md content by replacing the existing table with the new one
# Using awk to find and replace table
echo "$CONTENT" > "$TEMP_FILE"

awk -v new_table="$(printf '%s\n' "$UPDATED_TABLE")" '
  BEGIN {print_table=0}
  /| Module/ {print_table=1; print new_table; next}
  print_table==0 {print}
  print_table==1 && /^\|/ {next}
  print_table==1 && !/^\|/ {print_table=0}
' "$TEMP_FILE" > "updated_$TEMP_FILE"

# Encode the updated README content in base64
UPDATED_CONTENT=$(base64 -w 0 < updated_$TEMP_FILE)

# Update README.md on GitHub
echo "Updating README.md on GitHub..."
UPDATE_RESPONSE=$(curl -s -X PUT -H "Authorization: token $GITHUB_API_KEY" -H "Accept: application/vnd.github.v3+json" "$API_URL" -d @- <<EOF
{
  "message": "Update DLL modified dates in README.md",
  "content": "$UPDATED_CONTENT",
  "sha": "$SHA"
}
EOF
)

# Clean up temporary files
rm "$TEMP_FILE" "updated_$TEMP_FILE"

# Check if the update was successful
if echo "$UPDATE_RESPONSE" | grep -q '"commit"'; then
  echo "README.md updated successfully."
else
  echo "Failed to update README.md. Response:"
  echo "$UPDATE_RESPONSE"
fi
