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
import joblib
import numpy as np
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

# Load trained ML confidence model (produced by run_ml_benchmark in main.py)
CONFIDENCE_MODEL_PATH = Path("output/models/best_model.joblib")
confidence_model = None
confidence_scaler = None

def load_confidence_model():
    """Load the trained classifier + scaler at startup."""
    global confidence_model, confidence_scaler
    if CONFIDENCE_MODEL_PATH.exists():
        try:
            data = joblib.load(CONFIDENCE_MODEL_PATH)
            if isinstance(data, dict):
                # Prefer proba_model (smooth probabilities) over best-accuracy model
                if "proba_model" in data and "proba_scaler" in data:
                    confidence_model = data["proba_model"]
                    confidence_scaler = data["proba_scaler"]
                    print(f"✅ Loaded confidence model ({data.get('proba_name', 'unknown')}) from {CONFIDENCE_MODEL_PATH}")
                elif "model" in data and "scaler" in data:
                    confidence_model = data["model"]
                    confidence_scaler = data["scaler"]
                    print(f"✅ Loaded ML model ({data.get('name', 'unknown')}) from {CONFIDENCE_MODEL_PATH}")
                else:
                    print(f"⚠️  Unexpected format in {CONFIDENCE_MODEL_PATH}")
            else:
                # Legacy format: just the model, no scaler
                confidence_model = data
                confidence_scaler = None
                print(f"⚠️  Loaded model from {CONFIDENCE_MODEL_PATH} but no scaler found")
                print(f"   Re-run main.py with ML benchmark to save model+scaler.")
        except Exception as e:
            print(f"⚠️  Failed to load confidence model: {e}")
            confidence_model = None
    else:
        print(f"⚠️  No confidence model found at {CONFIDENCE_MODEL_PATH}")
        print(f"   Run main.py → compare CSV → ML benchmark to generate one.")

# Load model on import
load_confidence_model()


def predict_ml_confidence(dimensions: Dict) -> Optional[float]:
    """
    Predict confidence score using the trained regression model.
    
    Args:
        dimensions: Dict with quality metrics from dataclean()
    
    Returns:
        ML-predicted confidence score (0-100), or None if model not available
    """
    if confidence_model is None or confidence_scaler is None:
        return None
    
    try:
        features = np.array([[
            dimensions.get('point_count', 0),
            dimensions.get('ransac_inlier_ratio', 0),
            dimensions.get('std_x', 0),
            dimensions.get('std_y', 0),
            dimensions.get('std_z', 0),
            dimensions.get('aspect_ratio', 1),
        ]])
        
        features_scaled = confidence_scaler.transform(features)
        
        # The proba_model is a regressor that predicts confidence % directly
        prediction = confidence_model.predict(features_scaled)[0]
        
        return round(max(0.0, min(100.0, prediction)), 2)
    except Exception as e:
        print(f"⚠️  ML prediction failed: {e}")
        return None

def calculate_quality_confidence(dimensions: Dict) -> float:
    """
    Calculate confidence score based on scan quality metrics alone.
    Works for ANY PLY file without needing reference measurements.
    
    Args:
        dimensions: Dict with quality metrics from dataclean()
    
    Returns:
        Quality-based confidence score (0-100)
    """
    scores = []
    
    # 1. Point density score (20k-50k is optimal)
    point_count = dimensions.get('point_count', 0)
    if point_count >= 20000:
        point_score = min(point_count / 30000, 1.5) * 0.67  # Cap at 100%
    else:
        point_score = point_count / 20000  # Linear below 20k
    scores.append(min(point_score, 1.0))
    
    # 2. RANSAC quality (lower ratio = cleaner object extraction)
    ransac_ratio = dimensions.get('ransac_inlier_ratio', 0)
    # Invert: high inlier ratio means lots of floor, we want low ratio
    ransac_score = 1.0 - min(ransac_ratio, 1.0)
    scores.append(ransac_score)
    
    # 3. Aspect ratio (1.0-3.0 is typical for household objects)
    aspect = dimensions.get('aspect_ratio', 0)
    if 1.0 <= aspect <= 3.0:
        aspect_score = 1.0
    elif aspect < 1.0:
        aspect_score = aspect  # Penalize if too small
    else:
        # Penalize extreme aspect ratios (may indicate bad segmentation)
        aspect_score = max(0, 1.0 - (aspect - 3.0) / 5.0)
    scores.append(aspect_score)
    
    # 4. Point spread consistency (lower std = more uniform density)
    std_x = dimensions.get('std_x', 0.05)
    std_y = dimensions.get('std_y', 0.05)
    std_z = dimensions.get('std_z', 0.05)
    avg_std = (std_x + std_y + std_z) / 3
    # Good scans have std around 0.01-0.03
    if avg_std <= 0.03:
        spread_score = 1.0
    else:
        spread_score = max(0, 1.0 - (avg_std - 0.03) / 0.05)
    scores.append(spread_score)
    
    # Weighted average (point count and RANSAC are most important)
    weights = [0.25, 0.35, 0.20, 0.20]
    confidence = sum(s * w for s, w in zip(scores, weights)) * 100
    
    return round(confidence, 2)

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
        
        # Confidence priority: ML model → reference-based → quality heuristic
        confidence = predict_ml_confidence(dimensions)
        confidence_type = "ml_model"
        
        if confidence is None:
            # Fall back to reference-based if ML model unavailable
            confidence = calculate_confidence(dimensions, original_filename)
            confidence_type = "reference"
        
        if confidence is None:
            # Fall back to quality heuristic as last resort
            confidence = calculate_quality_confidence(dimensions)
            confidence_type = "quality"
        
        print(f"   Confidence: {confidence:.1f}% ({confidence_type})")
        
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
            "confidence": confidence,  # Always present now (reference or quality-based)
            "processing_time": round(elapsed, 2)
        }
        
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
