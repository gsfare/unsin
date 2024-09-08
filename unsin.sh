#!/bin/bash

# Function to check if a file is a gzipped tar file
is_gzipped_tar() {
  local file="$1"
  file_type=$(file --mime-type -b "$file")
  [[ "$file_type" == "application/gzip" || "$file_type" == "application/x-tar" ]]
}

# Ensure an input file is provided
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 <file> [output_prefix]"
  exit 1
fi

# Define input file
INPUT_FILE="$1"

# Define output filename prefix; default to the input file's name before the first dot '.'
if [ -n "$2" ]; then
  OUTPUT_PREFIX="$2"
else
  OUTPUT_PREFIX=$(basename "$INPUT_FILE" | cut -d'.' -f1)
fi

# Define output image file name
OUTPUT_IMAGE="${OUTPUT_PREFIX}.img"

# Check if the input file exists
if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: File '$INPUT_FILE' not found!"
  exit 1
fi

# Check if the input file is a gzipped tar file
if ! is_gzipped_tar "$INPUT_FILE"; then
  echo "Error: File '$INPUT_FILE' is not a gzipped tar file!"
  exit 1
fi

# Create a temporary directory to store the unpacked files
TEMP_DIR=$(mktemp -d)

# Unpack the tar.gz file into the temporary directory
tar -xzf "$INPUT_FILE" -C "$TEMP_DIR"

# Remove any file that is not a sparse Android image
for file in "$TEMP_DIR"/*; do
  # Sparse Android images typically have a magic number at the beginning
  if ! file "$file" | grep -q 'Android sparse image'; then
    rm -f "$file"
  fi
done

# Check if there are any sparse files left
if [ -z "$(ls -A "$TEMP_DIR")" ]; then
  echo "Error: No Android sparse image files found after extraction."
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Construct the raw image from all sparse images in one command
simg2img "$TEMP_DIR"/* "$OUTPUT_IMAGE"

# Clean up the temporary directory
rm -rf "$TEMP_DIR"

# Notify the user of the output image
echo "Successfully created $OUTPUT_IMAGE from $INPUT_FILE."

