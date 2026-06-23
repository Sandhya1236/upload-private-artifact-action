#!/bin/bash
set -e

# Step 1: Check AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS credentials are missing or invalid."
  exit 1
fi

# Step 2: Upload artifacts
aws s3 cp "$INPUT_PATH" "s3://$INPUT_S3_BUCKET/$INPUT_DESTINATION" --recursive --progress-frequency 30

# Step 3: Tag already upload artifacts
#Validate TAGs
for tag in "$INPUT_OBJECT_TAG" "$INPUT_BUILD_BRANCH" "$INPUT_BUILD_TYPE"; do  
  if [[ -z "$tag" ]]; then
    echo "INFO: Required TAG variable is not set, skipping"
    continue
  fi

  if [[ "$tag" != *=* ]]; then
    echo "WARNING: Invalid tag format: $tag, The TAG should be in the form of key=value"    
  fi
done

OBJ_TAG_KEY="${INPUT_OBJECT_TAG%%=*}"
OBJ_TAG_VALUE="${INPUT_OBJECT_TAG#*=}"

BRANCH_TAG_KEY="${INPUT_BUILD_BRANCH%%=*}"
BRANCH_TAG_VALUE="${INPUT_BUILD_BRANCH#*=}"

BTYPE_TAG_KEY="${INPUT_BUILD_TYPE%%=*}"
BTYPE_TAG_VALUE="${INPUT_BUILD_TYPE#*=}"

TAGGING_JSON="$(cat <<EOF
{
  "TagSet": [
    { "Key": "$OBJ_TAG_KEY",    "Value": "$OBJ_TAG_VALUE" },
    { "Key": "$BRANCH_TAG_KEY", "Value": "$BRANCH_TAG_VALUE" },
    { "Key": "$BTYPE_TAG_KEY",  "Value": "$BTYPE_TAG_VALUE" }
  ]
}
EOF
)"

# Loop through all files recursively
find "$INPUT_PATH" -type f | while read file; do
    # Remove base path to preserve relative structure
    relative_path="${file#$INPUT_PATH/}"
    echo "Tagging Object at: $relative_path"
    aws s3api put-object-tagging \
        --bucket "$INPUT_S3_BUCKET" \
        --key "$INPUT_DESTINATION$relative_path" \
        --tagging "$TAGGING_JSON"
done

# Step 3: Publish fileserver URL containing the artifacts
output_file="${GITHUB_OUTPUT}"
echo "url=${INPUT_FILESERVER_URL}/${INPUT_S3_BUCKET}/${INPUT_DESTINATION}" >> ${output_file}