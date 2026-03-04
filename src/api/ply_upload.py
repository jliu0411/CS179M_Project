from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import shutil
from pathlib import Path
import tempfile
from src.logic.dataclean import dataclean
import os

app = FastAPI(title="PLY File Processor API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_DIR = Path("uploads")
OUTPUT_DIR = Path("output/mobile_uploads")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


@app.post("/api/upload-ply")
async def upload_ply(file: UploadFile = File(...)):
    """
    Accept PLY file upload from iOS app, process through dataclean,
    and return dimensions + cleaned PLY file path.
    """

    if not file.filename.endswith('.ply'):
        raise HTTPException(status_code=400, detail="Only .ply files are accepted")
    
    print(f"\n Received file: {file.filename}")
    
    try:
        file_path = UPLOAD_DIR / file.filename
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        print(f"File saved to: {file_path}")

        file_size = file_path.stat().st_size
        print(f"File size: {file_size} bytes")
        
        if file_size < 100:
            raise HTTPException(status_code=400, detail="File too small - may be corrupted")
  
        print(f"Processing with dataclean...")
        dimensions = dataclean(
            dir=str(file_path),
            visualize_flag=False,
            output_dir=str(OUTPUT_DIR)
        )
        
        print(f" Processing complete!")
        print(f"  Width:  {dimensions['width']:.3f} m")
        print(f"  Length: {dimensions['length']:.3f} m")
        print(f"  Height: {dimensions['height']:.3f} m")
        
        cleaned_filename = f"{Path(file.filename).stem}_cleaned.ply"
        cleaned_file_path = OUTPUT_DIR / cleaned_filename
        
        return JSONResponse({
            "success": True,
            "original_filename": file.filename,
            "cleaned_filename": cleaned_filename,
            "dimensions": dimensions,
            "message": "File processed successfully"
        })
    
    except Exception as e:
        error_msg = f"Processing error: {str(e)}"
        print(f"{error_msg}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=error_msg)


@app.get("/api/download-cleaned/{filename}")
async def download_cleaned(filename: str):
    """
    Download the cleaned PLY file
    """
    file_path = OUTPUT_DIR / filename
    
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found")
    
    return FileResponse(
        path=file_path,
        media_type="application/octet-stream",
        filename=filename
    )


@app.get("/api/health")
async def health_check():
    """
    Health check endpoint
    """
    return {"status": "healthy", "service": "PLY Processor API"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
