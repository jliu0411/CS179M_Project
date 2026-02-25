#!/bin/bash
# Deploy Appwrite Function
# This script packages the function for deployment to Appwrite

echo -e "\033[36mPackaging Appwrite Function for deployment...\033[0m"
echo ""

FUNCTION_PATH="appwrite_functions/process-ply"
OUTPUT_ZIP="appwrite_functions/process-ply-deploy.zip"

# Check if function directory exists
if [ ! -d "$FUNCTION_PATH" ]; then
    echo -e "\033[31mError: Function directory not found at $FUNCTION_PATH\033[0m"
    exit 1
fi

# Remove old zip if exists
if [ -f "$OUTPUT_ZIP" ]; then
    rm "$OUTPUT_ZIP"
    echo -e "\033[33mRemoved old deployment package\033[0m"
fi

# Create zip file
cd "$FUNCTION_PATH"
zip -r "../../process-ply-deploy.zip" * > /dev/null 2>&1
cd ../..

if [ -f "$OUTPUT_ZIP" ]; then
    echo -e "\033[32m✓ Function packaged successfully!\033[0m"
    echo ""
    echo -e "\033[36mPackage location: $OUTPUT_ZIP\033[0m"
    echo ""
    echo -e "\033[33mNext steps:\033[0m"
    echo "1. Go to Appwrite Console: https://cloud.appwrite.io"
    echo "2. Navigate to Functions → process-ply"
    echo "3. Click 'Deploy' tab"
    echo "4. Upload the zip file: $OUTPUT_ZIP"
    echo "5. Click 'Activate'"
    echo ""
    FILE_SIZE=$(du -h "$OUTPUT_ZIP" | cut -f1)
    echo "Package size: $FILE_SIZE"
else
    echo -e "\033[31mError packaging function\033[0m"
    exit 1
fi
