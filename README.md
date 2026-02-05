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
