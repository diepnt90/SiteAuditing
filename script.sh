import csv
import os
import re
import sys
import json
import subprocess

# URL of the module.csv file on GitHub
module_csv_url = "https://raw.githubusercontent.com/diepnt90/SiteAuditing/main/module.csv"

# Path to save the downloaded module.csv
module_csv_path = os.path.expanduser('~/siteaudit/module.csv')

# Step 0: Download the latest module.csv using curl
def download_module_csv(url, save_path):
    try:
        print(f"Starting download of module.csv from {url} using curl")
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        # Use curl to download the file
        result = subprocess.run(['curl', '-L', url, '-o', save_path], capture_output=True)
        if result.returncode == 0:
            print(f"Downloaded module.csv successfully to {save_path}")
        else:
            print(f"Failed to download module.csv. curl error: {result.stderr.decode('utf-8')}")
            sys.exit(1)
    except Exception as e:
        print(f"Error downloading module.csv: {e}")
        sys.exit(1)

# Function to get the current version from a .deps.json file
def find_current_version(module_name, deps_file):
    print(f"Searching for current version of module: {module_name} in {deps_file}")
    with open(deps_file, 'r') as f:
        data = json.load(f)
        targets = data.get('targets', {})
        for target_name, target_data in targets.items():
            for key, value in target_data.items():
                if 'runtime' in value and any(module_name in runtime_key for runtime_key in value['runtime']):
                    match = re.search(r'/([\d.]+)', key)
                    if match:
                        print(f"Found current version {match.group(1)} for module {module_name}")
                        return match.group(1)
                if 'compile' in value and any(module_name in compile_key for compile_key in value['compile']):
                    match = re.search(r'/([\d.]+)', key)
                    if match:
                        print(f"Found current version {match.group(1)} for module {module_name}")
                        return match.group(1)
    print(f"No current version found for module: {module_name}")
    return None

# Function to get the newest version from nuget.org API
def get_newest_version_nuget(link):
    print(f"Fetching newest version from NuGet API: {link}")
    try:
        response = requests.get(link)
        if response.status_code == 200:
            data = response.json()
            versions = data.get("versions", [])
            if versions:
                print(f"Newest version from NuGet API: {versions[-1]}")
                return versions[-1]  # Get the latest version from the list
    except Exception as e:
        print(f"Error fetching from nuget.org: {e}")
    return None

# Function to get the newest version from nuget.optimizely.com using regex
def get_newest_version_optimizely(link):
    print(f"Fetching newest version from Optimizely NuGet: {link}")
    try:
        response = requests.get(link)
        if response.status_code == 200:
            match = re.search(r"document\.title\s*=\s*'.*? (\d+\.\d+\.\d+)';", response.text)
            if match:
                print(f"Newest version from Optimizely: {match.group(1)}")
                return match.group(1)  # Extract the version number
    except Exception as e:
        print(f"Error fetching from nuget.optimizely.com: {e}")
    return None

# Function to get the newest version from GitHub using regex
def get_newest_version_github(link):
    print(f"Fetching newest version from GitHub: {link}")
    try:
        response = requests.get(link)
        if response.status_code == 200:
            match = re.search(r'href=".*?/releases/tag/([\d.]+)"', response.text)
            if match:
                print(f"Newest version from GitHub: {match.group(1)}")
                return match.group(1)  # Extract the version number
    except Exception as e:
        print(f"Error fetching from GitHub: {e}")
    return None

# Get input file and .deps.json from command line arguments
if len(sys.argv) < 3:
    print("Usage: python script.py <input_csv_file> <deps_json_file>")
    sys.exit(1)

input_csv = sys.argv[1]
deps_json = sys.argv[2]

# Step 0: Download the latest module.csv file using curl
download_module_csv(module_csv_url, module_csv_path)

# Extract the file name from the input path
input_filename = os.path.basename(input_csv)
output_directory = os.path.expanduser('~/siteaudit/outputfiles')

# Create the output file path with the same name as the input file
output_csv = os.path.join(output_directory, input_filename)

# Step 1: Process the input CSV, updating or marking as necessary
print(f"Processing input CSV file: {input_csv}")
dll_scan_rows = []
with open(input_csv, mode='r', newline='') as dll_scan_csv:
    reader = csv.DictReader(dll_scan_csv)
    for row in reader:
        module_name = row['module_name']
        link = row.get('links', '').strip()
        newest_version = None

        # Step 2: Find the current version by scanning the provided .deps.json file
        current_version = find_current_version(module_name, deps_json)
        if current_version:
            row['current_version'] = current_version
        
        # Step 3: Check if the link is from nuget.org, nuget.optimizely.com, or GitHub
        if "api.nuget.org" in link:
            newest_version = get_newest_version_nuget(link)
        elif "nuget.optimizely.com" in link:
            newest_version = get_newest_version_optimizely(link)
        elif "github.com" in link:
            newest_version = get_newest_version_github(link)
        
        # Step 4: Update the newest_version in the row
        if newest_version:
            row['newest_version'] = newest_version
        else:
            print(f"No newest version found for {module_name}")
            row['newest_version'] = ""  # Leave it empty if no version found

        # Step 5: Empty the 'links' column value
        row['links'] = ""

        dll_scan_rows.append(row)

# Step 6: Create the output directory if it doesn't exist
os.makedirs(output_directory, exist_ok=True)
print(f"Output directory: {output_directory}")

# Step 7: Write back to output CSV file with the same name as the input file
print(f"Writing modified CSV to {output_csv}")
with open(output_csv, mode='w', newline='') as dll_scan_csv:
    fieldnames = ['module_name', 'modified_date', 'current_version', 'newest_version', 'links', 'notes', 'tag']
    writer = csv.DictWriter(dll_scan_csv, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(dll_scan_rows)

print(f"Modified CSV saved to {output_csv}")
