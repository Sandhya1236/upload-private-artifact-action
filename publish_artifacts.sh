#!/bin/sh
set -e

# Step 1: Check AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS credentials are missing or invalid."
  exit 1
fi

# Step 2: Upload artifacts
#aws s3 cp "$INPUT_PATH" "s3://$INPUT_S3_BUCKET/$INPUT_DESTINATION" --recursive --progress-frequency 30

# Loop through all files recursively
find "$INPUT_PATH" -type f | while read file; do
    # Remove base path to preserve relative structure
    relative_path="${file#$INPUT_PATH/}"

    echo "Uploading: $relative_path"

    aws s3api put-object \
        --bucket "$INPUT_S3_BUCKET" \
        --key "$INPUT_DESTINATION$relative_path" \
        --body "$file" \
        --tagging "$INPUT_OBJECT_TAG&$INPUT_BUILD_BRANCH&$INPUT_BUILD_TYPE"
done

# Step 3: Publish fileserver URL containing the artifacts
output_file="${GITHUB_OUTPUT}"
echo "url=${INPUT_FILESERVER_URL}/${INPUT_S3_BUCKET}/${INPUT_DESTINATION}" >> ${output_file}
