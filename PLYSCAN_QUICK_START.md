# PlyScan Quick Start Guide

## Overview
PlyScan now features a unified 3-tab interface:
- **Library**: View scan history and measurements
- **Scan**: Capture and auto-upload 3D scans
- **Upload**: Manually process PLY files

## 🚀 Quick Start (5 minutes)

### Step 1: Start Backend Server
```bash
cd /Users/jamesliu/CS179M_Project
source venv310/bin/activate
python -m uvicorn src.api.ply_upload:app --host 0.0.0.0 --port 8000 --reload
```

### Step 2: Test Backend
In a new terminal:
```bash
cd /Users/jamesliu/CS179M_Project
source venv310/bin/activate
python test_api.py
```

You should see:
```
✅ Health check passed
✅ Upload and processing successful!
✅ All tests passed!
```

### Step 3: Configure iOS App
1. Find your Mac's IP address:
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```

2. Update server URL in Xcode:
   - Open `PlyScan/Export/UploadService.swift`
   - Line 31: Change to `return "http://YOUR_IP:8000"`

### Step 4: Build & Run
1. Open Xcode: `open PlyScan/PlyScan.xcodeproj`
2. Select your iPhone (with LiDAR)
3. Build and run (Cmd+R)

## 📱 Using the App

### Scan Tab (Middle)
1. Tap "Start Scan"
2. Move around object in a circle
3. Watch coverage indicator
4. Tap "Stop & Upload" when done
5. View instant results!

### Library Tab (Left)
- All scans automatically saved here
- Tap any scan to see full details
- Swipe left to delete

### Upload Tab (Right)
- Pick any PLY file from your device
- Process existing scans
- Save results to library

## 🎯 What Changed

### New Files Created:
```
PlyScan/App/
  ├── MainTabView.swift          ← Tab navigation
  ├── ScanView.swift             ← Renamed from ContentView
  ├── LibraryView.swift          ← NEW: History viewer
  └── ManualUploadView.swift     ← NEW: File picker

PlyScan/Models/
  ├── ScanRecord.swift           ← NEW: Data model
  └── LibraryManager.swift       ← NEW: Storage manager

PlyScan/Export/
  └── UploadService.swift        ← NOW IMPLEMENTED

PlyScan/Networking/
  ├── APIClient.swift            ← NOW IMPLEMENTED
  └── Endpoints.swift            ← NOW IMPLEMENTED

Backend:
  src/api/ply_upload.py          ← NEW: FastAPI server
```

### Modified Files:
- `PLYScanApp.swift`: Now launches MainTabView
- `ARSessionManager.swift`: Added lastScanFolder property

## 🔧 Troubleshooting

**"Upload failed: Could not connect"**
- Ensure backend is running (Step 1)
- Check IP address matches
- Both devices on same WiFi

**"No scan folder found"**
- Complete a full scan before stopping
- App needs camera permissions

**Build errors in Xcode**
- Clean build: Cmd+Shift+K
- Rebuild: Cmd+B
- Check iOS deployment target is 15.0+

## 📊 Backend API

The backend now provides these endpoints:

- `GET /api/health` - Check server status
- `POST /api/upload-ply` - Upload and process PLY files
  - Accepts: multipart/form-data with "file" field
  - Returns: JSON with dimensions
- `GET /api/download-cleaned/{filename}` - Download processed files

## 🎓 Next Steps

1. **Test locally** with the steps above
2. **Deploy backend** to Render (see RENDER_DEPLOYMENT.md)
3. **Update production URL** in UploadService.swift
4. **Distribute app** via TestFlight or enterprise

## 💡 Tips

- Use LiDAR mode for best accuracy
- Move slowly around object
- Maintain 0.5-2m distance
- Good lighting helps
- Scan until 80%+ coverage

## 📁 File Locations

- Scans saved to: `Documents/Scan_YYYYMMDD_HHMMSS/`
- History stored in: UserDefaults
- Uploads go to: `output/mobile_uploads/`

Enjoy your unified scanning experience! 🎉
