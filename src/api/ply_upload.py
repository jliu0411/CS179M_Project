"""
FastAPI backend for PLY file upload and processing
"""

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from pathlib import Path
import shutil
import uuid
from typing import Dict
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
        
        # Create cleaned filename
        cleaned_filename = f"{file_id}_cleaned.ply"
        
        return JSONResponse(content={
            "success": True,
            "original_filename": original_filename,
            "cleaned_filename": cleaned_filename,
            "dimensions": {
                "width": float(dimensions["width"]),
                "length": float(dimensions["length"]),
                "height": float(dimensions["height"])
            },
            "processing_time": round(elapsed, 2)
        })
    
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
