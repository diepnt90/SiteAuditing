#!/bin/bash

# GitHub API token
API_TOKEN="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"

# GitHub repository details
REPO_OWNER="diepnt90"
REPO_NAME="SiteAuditing"
FILE_PATH="README.md"

# Get the current content of the README.md file
RESPONSE=$(curl -s -H "Authorization: token $API_TOKEN" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$FILE_PATH")

# Extract content and SHA using grep and cut
CONTENT=$(echo "$RESPONSE" | grep '"content":' | cut -d '"' -f 4)
SHA=$(echo "$RESPONSE" | grep '"sha":' | cut -d '"' -f 4)

# Decode content
DECODED_CONTENT=$(echo "$CONTENT" | base64 --decode)

# Find the table in the content
TABLE_START=$(echo "$DECODED_CONTENT" | grep -n "| Module" | cut -d: -f1)
TABLE_END=$(echo "$DECODED_CONTENT" | tail -n +$TABLE_START | grep -n "^$" | head -n 1 | cut -d: -f1)
TABLE_END=$((TABLE_START + TABLE_END - 1))

# Extract the table header and footer
TABLE_HEADER=$(echo "$DECODED_CONTENT" | sed -n "${TABLE_START}p")
TABLE_FOOTER=$(echo "$DECODED_CONTENT" | sed -n "${TABLE_END}p")

# Generate new table content
NEW_TABLE_CONTENT="$TABLE_HEADER"$'\n'

# Scan DLL files and get their modified dates
for file in *.dll; do
    if [ -f "$file" ]; then
        mod_date=$(stat -c "%y" "$file" | cut -d. -f1)
        NEW_TABLE_CONTENT+="| $file | $mod_date | | | | |"$'\n'
    fi
done

NEW_TABLE_CONTENT+="$TABLE_FOOTER"

# Replace the old table with the new one in the content
NEW_CONTENT="${DECODED_CONTENT:0:$((TABLE_START-1))}"$'\n'"$NEW_TABLE_CONTENT"$'\n'"${DECODED_CONTENT:$TABLE_END}"

# Encode the new content
ENCODED_CONTENT=$(echo "$NEW_CONTENT" | base64 -w 0)

# Update the file on GitHub
curl -s -X PUT \
  -H "Authorization: token $API_TOKEN" \
  -d "{\"message\":\"Update DLL information\",\"content\":\"$ENCODED_CONTENT\",\"sha\":\"$SHA\"}" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$FILE_PATH"

echo "README.md has been updated with the latest DLL information."
