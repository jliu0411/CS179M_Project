"""
FastAPI backend for PLY file upload and processing
"""

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from pathlib import Path
import shutil
import uuid
import pandas as pd
import re
from typing import Dict, Optional
from src.logic.dataclean import dataclean

app = FastAPI(title="PLY Processor API")

# Enable CORS for mobile apps
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Directories
UPLOAD_DIR = Path("output/mobile_uploads")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

# Reference measurements CSV
REFERENCE_CSV = Path("Measurements_clean - Sheet1.csv")

def calculate_confidence(dimensions: Dict, filename: str) -> Optional[float]:
    """
    Calculate confidence score by comparing against reference measurements.
    Returns None if reference data is not available for this object.
    
    Args:
        dimensions: Dict with 'width', 'length', 'height' in meters
        filename: Original filename (e.g., "1.ply", "box2.ply")
    
    Returns:
        Confidence score (0-100) or None if no reference available
    """
    # Try to extract object number from filename
    match = re.search(r'\d+', filename)
    if not match:
        return None
    
    object_number = int(match.group())
    
    # Check if reference CSV exists
    if not REFERENCE_CSV.exists():
        return None
    
    try:
        # Load reference measurements
        reference_df = pd.read_csv(REFERENCE_CSV)
        reference_df.columns = reference_df.columns.str.strip()
        
        # Find the reference row for this object
        ref_row = reference_df[reference_df['number'] == object_number]
        if ref_row.empty:
            return None
        
        # Get reference dimensions (in cm)
        ref_height = ref_row['Height'].values[0]
        ref_width = ref_row['Width'].values[0]
        ref_length = ref_row['Length'].values[0]
        
        # Convert our dimensions from meters to cm
        created_height = dimensions['height'] * 100
        created_width = dimensions['width'] * 100
        created_length = dimensions['length'] * 100
        
        # Calculate ratios for each dimension (same as compare_between_csv)
        ratios = []
        for created, reference in [(created_height, ref_height), 
                                    (created_width, ref_width), 
                                    (created_length, ref_length)]:
            if reference == 0:
                ratios.append(0)
            else:
                ratio = min(created, reference) / max(created, reference)
                ratios.append(ratio)
        
        # Average confidence across all dimensions
        confidence = (sum(ratios) / len(ratios)) * 100
        return round(confidence, 2)
        
    except Exception as e:
        print(f"⚠️  Could not calculate confidence: {e}")
        return None

@app.get("/")
async def root():
    return {"message": "PLY Processor API", "version": "1.0"}

@app.get("/api/health")
async def health_check():
    return {"status": "ok", "message": "Server is running"}

@app.post("/api/upload-ply")
async def upload_ply(file: UploadFile = File(...), method: str = "AABB"):
    """
    Upload a PLY file, process it, and return dimensions
    
    Args:
        file: The PLY file to upload
        method: Processing method - "AABB" (fast) or "HULL" (accurate, slow)
    """
    # Validate file extension
    if not file.filename.endswith('.ply'):
        raise HTTPException(status_code=400, detail="File must be a .ply file")
    
    # Generate unique filename
    file_id = str(uuid.uuid4())[:8]
    original_filename = file.filename
    saved_filename = f"{file_id}_{original_filename}"
    file_path = UPLOAD_DIR / saved_filename
    
    # Save uploaded file
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to save file: {str(e)}")
    
    # Process the PLY file
    try:
        import time
        start_time = time.time()
        print(f"⏱️  Processing {original_filename} with {method} method...")
        
        # Use AABB (fast) by default, or HULL (accurate but slower)
        dimensions = dataclean(
            str(file_path),
            visualize_flag=False,
            method=method,
            verbose=False
        )
        
        elapsed = time.time() - start_time
        print(f"✅ Processing complete in {elapsed:.2f}s")
        print(f"   Dimensions: {dimensions['width']:.3f} x {dimensions['length']:.3f} x {dimensions['height']:.3f} m")
        
        # Calculate confidence if reference data is available
        confidence = calculate_confidence(dimensions, original_filename)
        if confidence is not None:
            print(f"   Confidence: {confidence:.1f}% (vs reference measurements)")
        
        # Create cleaned filename
        cleaned_filename = f"{file_id}_cleaned.ply"
        
        response_data = {
            "success": True,
            "original_filename": original_filename,
            "cleaned_filename": cleaned_filename,
            "dimensions": {
                "width": float(dimensions["width"]),
                "length": float(dimensions["length"]),
                "height": float(dimensions["height"])
            },
            "quality_metrics": {
                "point_count": int(dimensions["point_count"]),
                "ransac_inlier_ratio": float(dimensions["ransac_inlier_ratio"]),
                "aspect_ratio": float(dimensions["aspect_ratio"])
            },
            "processing_time": round(elapsed, 2)
        }
        
        # Add confidence if available
        if confidence is not None:
            response_data["confidence"] = confidence
        
        return JSONResponse(content=response_data)
    
    except Exception as e:
        # Clean up uploaded file on error
        if file_path.exists():
            file_path.unlink()
        raise HTTPException(status_code=500, detail=f"Failed to process PLY file: {str(e)}")

@app.get("/api/download-cleaned/{filename}")
async def download_cleaned(filename: str):
    """
    Download a processed/cleaned PLY file
    """
    file_path = UPLOAD_DIR / filename
    
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found")
    
    return FileResponse(
        path=file_path,
        media_type="application/octet-stream",
        filename=filename
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
