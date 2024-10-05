#!/bin/bash

# Set your GitHub information
GITHUB_OWNER="diepnt90"                           # GitHub username
GITHUB_REPO="SiteAuditing"                         # Repository name
GITHUB_BRANCH="main"                               # Branch name, e.g., 'main'
FILE_PATH="dll_updates.md"                         # File to be uploaded
GITHUB_TOKEN="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"              # Your GitHub Personal Access Token

# GitHub API endpoint for the file
GITHUB_API_URL="https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/contents/$FILE_PATH"

# Get the content of the file encoded in base64
FILE_CONTENT=$(base64 -w 0 "$FILE_PATH") # -w 0 removes line wrapping for the base64 output

# Get SHA of the existing file if it exists
SHA=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" "$GITHUB_API_URL" | jq -r '.sha')

# Step 1: Delete the existing file if it exists (Optional but will ensure it's a new upload)
if [ "$SHA" != "null" ]; then
    DELETE_PAYLOAD=$(jq -n --arg message "Delete old dll_updates.md" --arg branch "$GITHUB_BRANCH" --arg sha "$SHA" \
    '{ message: $message, branch: $branch, sha: $sha }')
    
    curl -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" -H "Content-Type: application/json" -d "$DELETE_PAYLOAD" "$GITHUB_API_URL"
    
    echo "Old dll_updates.md deleted."
fi

# Step 2: Upload the new file
# Create JSON payload for GitHub API to add the new file
UPLOAD_PAYLOAD=$(jq -n --arg path "$FILE_PATH" --arg message "Add new dll_updates.md" --arg content "$FILE_CONTENT" --arg branch "$GITHUB_BRANCH" \
'{ path: $path, message: $message, content: $content, branch: $branch }')

# Upload the file using GitHub API
RESPONSE=$(curl -X PUT -H "Authorization: Bearer $GITHUB_TOKEN" -H "Content-Type: application/json" -d "$UPLOAD_PAYLOAD" "$GITHUB_API_URL")

# Check for successful upload
if echo "$RESPONSE" | grep -q '"commit":'; then
    echo "New dll_updates.md uploaded successfully."
else
    echo "Failed to upload dll_updates.md. Response:"
    echo "$RESPONSE"
fi
