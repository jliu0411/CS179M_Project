# Project Progress – Dimensioner & Pivot Exploration

## Overview
This project explores camera-based **Dimensioner systems** and potential pivots if access to hardware, meetings, or datasets becomes unavailable. Our goal is to deliver a practical, computer-vision–driven solution within a limited timeline.

---

## What Is a Dimensioner?

A **Dimensioner** estimates a box’s physical dimensions (Length × Width × Depth).

### Camera-Based (Depth Sensors)
- Captures photos of a box
- Isolates box from background
- Estimates depth from images
- Outputs: `L × W × D`

**Pros**
- No moving parts  
- Fast  
- Cheap at scale  

**Cons**
- Sensitive to lighting  
- Depth noise  
- Occlusion issues  

### Laser / LiDAR-Based
- Laser sweeps across the box
- Captures height profile per line scan

**Pros**
- High precision  
- Lighting independent  
- Handles dark/reflective surfaces well  

**Cons**
- Expensive  
- Mechanical complexity  
- Calibration drift  

---

## System Pipeline

The Dimensioner processes point clouds through a distinct five-step pipeline:
- Data Acquisition: The process begins with an iPhone scan that generates a .ply file. It utilizes the device's LiDAR Scanner.
- Pre-processing: The system performs data cleaning and plane removal.
- Segmentation: The point cloud undergoes clustering and alignment.
- Calculation: The system executes dimension estimation.
- Output: The final result yields the exact Width, Length, and Height of the object.

---

## The Intelligence & Model Details

The system's optimization engine calculates dimensions using a geometric method based on linear regression.
- Core Approach: It pairs Axis-Aligned Bounding Boxes (AABB) with multiple machine learning models (Linear, Logistical, KMeans, DTrees, MLP).
- Optimization: It selects optimal dimensions based on the best-fitting model. The underlying equation is $y=\beta_{0}+\beta_{1}x+\epsilon$.
- Model Architecture: Point Cloud Dimension Prediction utilizes Linear Regression with Gradient Descent.
- Feature Set: The model is trained on 15 Point Cloud Stats.
- Dataset: The dataset consists of 40 samples.

---

## Current Status
- Polishing current methods for data cleaning
- Implementing current machine learning models
- Imrpove Mobile UI/UX


---


## Environment & Usage Notes

### 1. Versions & Requirements

This project was developed and tested with the following environment:

- **Python**: `3.10.x` (required)  
  > ⚠️ Python 3.12+ and 3.13 are **not supported** due to Open3D compatibility.
- **Operating System**: Windows, macOS/Linux
- **Required Libraries**:
  - `open3d`
  - `numpy`

Install dependencies using:
```bash
pip install -r requirements.txt
```

If `requirements.txt` is not available:
```bash
pip install open3d numpy
```

---


### 2. Virtual Environment (venv) Setup

To avoid dependency and version conflicts, using a virtual environment is strongly recommended.

**Download Python 3.10 if needed**
*Windows:*
```powershell
winget install --id Python.Python.3.10 --exact
```

*macOS/Linux:*
```bash
brew install python@3.10
echo 'export PATH="/opt/homebrew/opt/python@3.10/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Create a virtual environment**

*Windows:*
```powershell
py -3.10 -m venv venv310
```

*macOS/Linux:*
```bash
python3.10 -m venv venv310
```

**Activate the virtual environment**

*Windows:*
```powershell
.\venv310\Scripts\Activate
```

*macOS/Linux:*
```bash
source venv310/bin/activate
```

Verify the Python version (windows/macOS/Linux):
```bash
python --version
# Python 3.10.x
```

**Install dependencies**
*Windows:*
```powershell
python.exe -m pip install --upgrade pip
pip install open3d numpy
```

*macOS/Linux:*
```bash
pip install --upgrade pip
pip install open3d numpy
```

---


### 3. ML Model Setup

To access model libraries:

Install pandas for data analysis and manipulation:
```bash
pip install pandas
```

Install scikit-learn for access to large library of models:
```bash
pip install scikit-learn
```

---



### 4. Running the Code
The project is structured as a Python module and should be executed **from the project root directory.**

**Recommended (module-based execution)**
```bash
python -m main
```
This method ensures:
 * Correct module imports
 * Consistent behavior across environments


**Alternative (direct execution)**
```bash
python main.py
```
Direct execution may also work, but module-based execution is preferred.


---


### Notes

Output point clouds are saved to the configured output directory (e.g., `outputs/`)
 * All geometric measurements are reported in **meters**, consistent with the original point cloud units
 * The processing pipeline includes:
   * Radius-based outlier removal
   * Histogram-based depth normalization
   * RANSAC plane (floor) removal
   * Large-plane cleanup and clustering
   * Final object dimension estimation

