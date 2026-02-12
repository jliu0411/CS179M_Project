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

## Proposal Ideas

- **Damage Detection**
- **Label Reading & Verification**
- Online lookup to validate labels/details
- **3D Tetris** for shipping containers
  - Optimize packing across *multiple* containers
- **Weight Detection**
  - Ask if weight sensors are available
  - Useful for detecting fake returns
- **AI Support for Dimension Detection**
  - Background removal
  - Bad scan detection
  - Confidence score for scan accuracy

---

## Week 5 – Issue & Pivot Decision

We may need to pivot due to time and access constraints.

### Options
1. **Continue with Dimensioner**
   - Generate our own dataset
   - Focus on accuracy analysis or AI-assisted improvements
2. **Full Pivot**
   - Analyze a sports dataset
   - Predict win rate or game outcomes

Decision depends on feasibility within the remaining 5 weeks.

---

## Current Status
- Exploring feasibility of Dimensioner-based solutions
- Preparing pivot options in parallel
- Awaiting clarity on meetings, hardware, and data access


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


### 3. Running the Code
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

