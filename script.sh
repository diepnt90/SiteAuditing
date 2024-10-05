#!/bin/bash

# Install jq if it is not installed
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Installing jq..."
    apt-get install jq -y
fi

# Configuration
GITHUB_API_KEY="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" # Replace with your GitHub API key or use an environment variable
REPO_OWNER="diepnt90"
REPO_NAME="SiteAuditing"
README_PATH="README.md"
DLL_DIRECTORY="/app"

# Get the current README content from GitHub
readme_url="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/${README_PATH}"
readme_response=$(curl -s -H "Authorization: Bearer ${GITHUB_API_KEY}" "$readme_url")

# Check if README response is valid
if [ "$(echo "$readme_response" | jq -r .message)" == "Not Found" ]; then
    echo "README.md not found at the specified path: ${README_PATH}"
    exit 1
fi

# Extract the SHA and download URL
readme_sha=$(echo "$readme_response" | jq -r .sha)
download_url=$(echo "$readme_response" | jq -r .download_url)

# Download the current README.md file
curl -s -H "Authorization: Bearer ${GITHUB_API_KEY}" -o README.md "$download_url"

# Get the modified date of all DLL files
dll_info=""
while IFS= read -r -d '' file; do
    modified_date=$(stat -c "%y" "$file" | cut -d'.' -f1)
    dll_name=$(basename "$file")
    dll_info="${dll_info}| ${dll_name} | ${modified_date} |\n"
done < <(find "$DLL_DIRECTORY" -type f -name "*.dll" -print0)

# Prepare the new table content
table_header="| Module Name | Modified Date |\n|-------------|---------------|\n"
new_table_content="${table_header}${dll_info}"

# Modify the README.md file locally
sed -i "/| Module Name/,/| Notes |/c\\$new_table_content" README.md

# Encode the modified README.md file to base64
updated_readme_base64=$(base64 README.md | tr -d '\n')

# Prepare the payload for the update request
update_payload=$(jq -n --arg msg "Update README with DLL files and modified dates" \
    --arg content "$updated_readme_base64" \
    --arg sha "$readme_sha" \
    '{message: $msg, content: $content, sha: $sha}')

# Update the README on GitHub
update_response=$(curl -s -X PUT -H "Authorization: Bearer ${GITHUB_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$update_payload" "$readme_url")

# Check if the update was successful
if echo "$update_response" | jq -e .commit.sha > /dev/null; then
    echo "README.md updated successfully."
else
    echo "Failed to update README.md."
    echo "$update_response"
fi

# Clean up the downloaded README.md file
rm README.md
