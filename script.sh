#!/bin/bash

# Install jq if it is not installed
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Installing jq..."
    apt-get install jq -y
fi

# Configuration
GITHUB_API_KEY="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" # Set this as an environment variable instead of hardcoding it
REPO_OWNER="diepnt90"
REPO_NAME="SiteAuditing"
README_PATH="README.md"
DLL_DIRECTORY="/app"

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

# Get the current README content from GitHub
readme_url="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/${README_PATH}"
readme_response=$(curl -s --header "Authorization: Bearer ${GITHUB_API_KEY}" "$readme_url")

# Check if README response is valid
if [ "$(echo "$readme_response" | jq -r .message)" == "Not Found" ]; then
    echo "README.md not found at the specified path: ${README_PATH}"
    exit 1
fi

# Extract the SHA and current content of README
readme_sha=$(echo "$readme_response" | jq -r .sha)
readme_content=$(echo "$readme_response" | jq -r .content | base64 --decode)

# Replace the old table with the new table in README content
updated_readme_content=$(echo "$readme_content" | sed -e "/| Module Name/,/| Notes |/c\\$new_table_content")

# Encode the updated content to base64
updated_readme_base64=$(echo "$updated_readme_content" | base64 -w 0)

# Update the README on GitHub
update_response=$(curl -s -X PUT --header "Authorization: Bearer ${GITHUB_API_KEY}" \
    -H "Content-Type: application/json" \
    -d @- <<EOF
{
  "message": "Test update to README.md",
  "content": "${updated_readme_base64}",
  "sha": "${readme_sha}"
}
EOF
"$readme_url")

# Check if the update was successful
if echo "$update_response" | jq -e .commit.sha > /dev/null; then
    echo "README.md updated successfully."
else
    echo "Failed to update README.md."
    echo "$update_response"
fi
