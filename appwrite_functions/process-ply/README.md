# Appwrite Function - Process PLY File

This function processes PLY (Point Cloud) files using Open3D to extract object dimensions.

## What it does

1. Receives file ID and processing method from mobile app
2. Downloads PLY file from Appwrite Storage
3. Processes file using Open3D:
   - Removes outliers and noise
   - Segments and removes floor/walls
   - Clusters to find main object
   - Calculates dimensions (width, length, height)
4. Updates database with results

## Processing Methods

- **AABB**: Axis-Aligned Bounding Box (fastest)
- **OBB**: Oriented Bounding Box (balanced)
- **PCA**: Principal Component Analysis (most accurate)

## Requirements

- Python 3.9
- Open3D >= 0.18.0
- Appwrite SDK >= 5.0.0
- NumPy >= 1.24.0

## Deployment

### Method 1: Using Appwrite Console

1. Zip the entire `process-ply` folder contents:
   ```bash
   zip -r function.zip src/ requirements.txt
   ```

2. In Appwrite Console:
   - Go to Functions → process-ply
   - Upload function.zip
   - Click "Activate"

### Method 2: Using Appwrite CLI

```bash
appwrite deploy function --functionId process-ply
```

## Function Configuration

- **Runtime**: Python 3.9
- **Timeout**: 300 seconds (5 minutes)
- **Execute Access**: Any (or configure for authenticated users)
- **Entry Point**: `src/main.py`

## Environment Variables

Automatically provided by Appwrite:
- `APPWRITE_ENDPOINT`
- `APPWRITE_FUNCTION_PROJECT_ID`
- `APPWRITE_API_KEY`

## Testing

### Test Payload

```json
{
  "fileId": "file-id-from-storage",
  "method": "AABB",
  "resultId": "document-id-from-database"
}
```

### Expected Response

```json
{
  "success": true,
  "dimensions": {
    "width": 0.123,
    "length": 0.456,
    "height": 0.789
  },
  "method": "AABB",
  "fileId": "file-id-from-storage"
}
```

## Error Handling

The function updates the database document with error information if processing fails:

```json
{
  "status": "failed",
  "error": "Error message here"
}
```

## Monitoring

View execution logs in Appwrite Console:
1. Go to Functions → process-ply
2. Click "Executions" tab
3. View logs for each execution

## Performance

| File Size | Processing Time | Memory Usage |
|-----------|----------------|--------------|
| < 10 MB   | 10-20 seconds  | ~500 MB      |
| 10-50 MB  | 30-60 seconds  | ~1-2 GB      |
| > 50 MB   | 60-120 seconds | ~2-4 GB      |

## Troubleshooting

**"Module not found" error:**
- Verify requirements.txt is included in deployment
- Check function logs for specific missing modules

**Timeout error:**
- Increase function timeout in Appwrite Console
- Maximum timeout is 900 seconds (15 minutes)

**Memory error:**
- Large PLY files may exceed memory limits
- Consider upgrading Appwrite plan for more resources

**Open3D errors:**
- Ensure PLY file format is valid
- Check if file is corrupted

## Local Testing

You can test the function locally:

```bash
cd appwrite_functions/process-ply
pip install -r requirements.txt

# Set environment variables
export APPWRITE_ENDPOINT="https://cloud.appwrite.io/v1"
export APPWRITE_FUNCTION_PROJECT_ID="your-project-id"
export APPWRITE_API_KEY="your-api-key"

# Run function
python src/main.py
```

## Notes

- Function runs in isolated container
- Processing is stateless
- Files are downloaded to temporary storage
- Temporary files are cleaned up after processing
- All dimensions are in meters
