# PlyScan - Unified 3D Scanning & Processing App

PlyScan is a comprehensive iOS app that combines 3D scanning with automated processing. It features three modes accessible via bottom tabs:

## 🏗️ Architecture

### 📱 Three Main Modes

1. **Library (Left Tab)** 📚
   - View all past scans with measurements
   - Browse scan history with timestamps
   - See dimensions for each scan
   - Delete unwanted scans

2. **Scan (Middle Tab)** 📷
   - Capture 3D scans using LiDAR/TrueDepth/RGB
   - Real-time coverage feedback
   - Auto-upload to backend on completion
   - Instant dimension results

3. **Manual Upload (Right Tab)** ⬆️
   - Pick any PLY file from device
   - Upload and process manually
   - View results before saving to library
   - Great for processing existing files

## 🚀 Getting Started

### Backend Setup

1. **Activate Python environment:**
   ```bash
   source venv310/bin/activate
   ```

2. **Start the backend server:**
   ```bash
   ./start_backend.sh
   ```
   Or manually:
   ```bash
   python -m uvicorn src.api.ply_upload:app --host 0.0.0.0 --port 8000 --reload
   ```

3. **Verify server is running:**
   ```bash
   python test_api.py
   ```

### iOS App Setup

1. **Open in Xcode:**
   ```bash
   cd PlyScan
   open PlyScan.xcodeproj
   ```

2. **Update server URL** (if needed):
   - Edit `PlyScan/Export/UploadService.swift`
   - Change `baseURL` to your server's IP address
   - For local testing: `http://YOUR_IP:8000`
   - For production: Use the Render URL

3. **Build and Run:**
   - Select your iPhone (requires LiDAR for best results)
   - Build and install

## 📁 Project Structure

```
PlyScan/
├── App/
│   ├── PLYScanApp.swift           # App entry point
│   ├── MainTabView.swift          # Tab navigation
│   ├── ScanView.swift             # Scanning interface
│   ├── LibraryView.swift          # History browser
│   └── ManualUploadView.swift    # File picker & upload
├── AR/
│   ├── ARSessionManager.swift     # Scan coordination
│   ├── TrueDepthScanner.swift     # Front camera scanning
│   └── FrameCaptureManager.swift  # Frame processing
├── Export/
│   ├── UploadService.swift        # HTTP upload
│   ├── FileManagerService.swift   # Local file management
│   └── ZiipService.swift          # [Future: Compression]
├── Models/
│   ├── ScanRecord.swift           # Scan data model
│   ├── LibraryManager.swift       # Persistent storage
│   └── CameraPose.swift           # Camera metadata
└── Networking/
    ├── APIClient.swift            # API wrapper
    └── Endpoints.swift            # API routes

Backend:
src/api/ply_upload.py              # FastAPI server
```

## 🔄 Workflow

### Scanning & Auto-Upload
1. Open app → **Scan** tab
2. Tap "Start Scan"
3. Move around object (watch coverage indicator)
4. Tap "Stop & Upload"
5. Results appear automatically
6. Saved to library for future reference

### Manual Upload
1. Open app → **Upload** tab
2. Tap "Choose PLY File"
3. Select file from device
4. Tap "Process File"
5. View results
6. Optionally save to library

### Viewing History
1. Open app → **Library** tab
2. Browse all past scans
3. Tap any scan for details
4. Swipe to delete

## 🎯 Key Features

- **Multi-Mode Scanning**: LiDAR, TrueDepth, or RGB
- **Real-time Feedback**: Coverage rings and height tracking
- **Automatic Upload**: Seamless scan → process → results
- **Persistent History**: All scans saved locally
- **Manual Processing**: Upload any PLY file
- **Clean UI**: Native iOS design with SwiftUI

## 🔧 Configuration

### Server URLs

Update in `UploadService.swift`:
```swift
private var baseURL: String {
    #if DEBUG
    return "http://localhost:8000"  // Local testing
    #else
    return "https://cs179m-project-test.onrender.com"  // Production
    #endif
}
```

### Processing Method

Update in `src/api/ply_upload.py`:
```python
dimensions = dataclean(
    str(file_path),
    method="HULL",  # Options: AABB, OBB, HULL, PCA, HULL_PCA
    visualize_flag=False,
    verbose=False
)
```

## 📊 API Endpoints

- `GET /api/health` - Health check
- `POST /api/upload-ply` - Upload & process PLY file
- `GET /api/download-cleaned/{filename}` - Download processed file

## 🐛 Troubleshooting

**Upload fails:**
- Check server is running (`python test_api.py`)
- Verify IP address in UploadService.swift
- Check firewall settings
- Ensure both devices on same network (for local)

**Scan quality issues:**
- Ensure good lighting
- Move slowly around object
- Maintain 0.5-2m distance
- Use LiDAR mode for best results

**App crashes:**
- Check Xcode console for errors
- Verify iOS 15+ and device permissions
- Clean build folder (Cmd+Shift+K)

## 📝 Development Notes

- Built with SwiftUI (iOS 15+)
- Requires ARKit and LiDAR support
- Backend uses FastAPI + Open3D
- Data persisted via UserDefaults
- Files stored in app Documents directory

## 🎓 Credits

CS179M Project - 3D Scanning & Dimensioning System
