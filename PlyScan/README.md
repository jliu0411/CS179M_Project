# PlyScan - Unified 3D Scanning & Processing App

PlyScan is a comprehensive iOS app that combines 3D scanning with automated processing and automatic server discovery. 

## Getting Started

### Backend Setup

1. **Activate Python environment:**
   ```bash
   cd /Users/jamesliu/CS179M_Project
   source venv310/bin/activate
   ```

2. **Start the backend server:**
   ```bash
   python -m uvicorn src.api.ply_upload:app --host 0.0.0.0 --port 8000 --reload
   ```

### iOS App Setup

#### Prerequisites

**Install XcodeGen** (required to generate the Xcode project):

XcodeGen is a command-line tool that generates Xcode projects from a `project.yml` specification file.

**Install via Homebrew**
```bash
brew install xcodegen
```

**Verify installation:**
```bash
xcodegen --version
#Should output: Version: 2.45.2 (or similar)
```

#### Building the App

1. **Generate Xcode Project:**
   ```bash
   cd PlyScan
   xcodegen  #Generates PlyScan.xcodeproj from project.yml
   open PlyScan.xcodeproj #Opens PlyScan in XCode 
   ```

   **What this does:**
   - Reads `project.yml` configuration
   - Generates `PlyScan.xcodeproj` with all source files
   - Configures build settings, targets, and dependencies
   - Must be run whenever `project.yml` changes

2. **Build and Run:**
   - Connect your iPhone (iOS 15+)
   - Select your device in Xcode
   - Press Cmd+R to build and install
   - **iPhone and Mac must be on the same WiFi network**

3. **First Launch:**
   - Grant camera and photo library permissions
   - The app will automatically scan the network for the server
   - First scan may take 5-10 seconds (caches server IP after)

**Network Requirements:**
- iPhone and server must be on same WiFi
- Server must be bound to `0.0.0.0` (not `localhost`)
- Port 8000 must be accessible (check firewall)

