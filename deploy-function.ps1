# Deploy Appwrite Function
# This script packages the function for deployment to Appwrite

Write-Host "Packaging Appwrite Function for deployment..." -ForegroundColor Cyan
Write-Host ""

$functionPath = "appwrite_functions\process-ply"
$outputZip = "appwrite_functions\process-ply-deploy.zip"

# Check if function directory exists
if (-not (Test-Path $functionPath)) {
    Write-Host "Error: Function directory not found at $functionPath" -ForegroundColor Red
    exit 1
}

# Remove old zip if exists
if (Test-Path $outputZip) {
    Remove-Item $outputZip
    Write-Host "Removed old deployment package" -ForegroundColor Yellow
}

# Create zip file
try {
    Compress-Archive -Path "$functionPath\*" -DestinationPath $outputZip -CompressionLevel Optimal
    Write-Host "✓ Function packaged successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Package location: $outputZip" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Go to Appwrite Console: https://cloud.appwrite.io"
    Write-Host "2. Navigate to Functions → process-ply"
    Write-Host "3. Click 'Deploy' tab"
    Write-Host "4. Upload the zip file: $outputZip"
    Write-Host "5. Click 'Activate'"
    Write-Host ""
    Write-Host "Package size: $((Get-Item $outputZip).Length / 1KB) KB"
} catch {
    Write-Host "Error packaging function: $_" -ForegroundColor Red
    exit 1
}
