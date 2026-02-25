# PLY File Processor Mobile App

A React Native Expo mobile application for uploading and processing PLY (Point Cloud) files using Appwrite as the backend.

## Features

- 📁 Upload PLY files from your mobile device
- ☁️ Cloud-based processing with Appwrite (no local server needed!)
- 🔄 Process files using three different methods:
  - AABB (Axis-Aligned Bounding Box)
  - OBB (Oriented Bounding Box)
  - PCA (Principal Component Analysis)
- 📊 Display dimensions (width, length, height) of processed objects
- 📱 Clean, intuitive mobile interface
- ⚡ Real-time upload and processing progress
- 🌐 Works from anywhere with internet connection

## Prerequisites

Before running the app, make sure you have:

1. **Node.js** (v14 or later) - [Download](https://nodejs.org/)
2. **Expo CLI** - Install globally:
   ```bash
   npm install -g expo-cli
   ```
3. **Expo Go app** on your mobile device:
   - [iOS App Store](https://apps.apple.com/app/expo-go/id982107779)
   - [Google Play Store](https://play.google.com/store/apps/details?id=host.exp.exponent)
4. **Appwrite Account** - Sign up at [https://cloud.appwrite.io](https://cloud.appwrite.io) (free tier available)

## Setup Instructions

### 1. Set Up Appwrite Backend

Follow the detailed setup guide: [APPWRITE_SETUP.md](../APPWRITE_SETUP.md)

**Quick summary:**
1. Create an Appwrite project at https://cloud.appwrite.io
2. Create database (`main`) with collection (`results`)
3. Create storage bucket (`ply-files`)
4. Deploy the processing function
5. Copy your Project ID

### 2. Install App Dependencies

Navigate to the app folder and install dependencies:

```bash
cd app
npm install
```

### 3. Configure Appwrite

Edit `config.js` and add your Appwrite Project ID:

```javascript
export const APPWRITE_CONFIG = {
  endpoint: 'https://cloud.appwrite.io/v1',
  projectId: 'YOUR_PROJECT_ID_HERE',  // Paste your Project ID
  databaseId: 'main',
  collectionId: 'results',
  bucketId: 'ply-files',
  functionId: 'process-ply'
};
```

### 4. Start the Expo App

In the app folder:

```bash
npm start
```

This will open Expo Dev Tools in your browser.

### 5. Run on Your Device

1. Open the **Expo Go** app on your phone
2. Scan the QR code shown in the terminal or Expo Dev Tools
3. The app will load on your device

## Usage

1. **Check Connection**: Ensure the green "Connected" indicator appears at the top
2. **Select File**: Tap "Choose File" and select a PLY file from your device
3. **Choose Method**: Select one of three processing methods (AABB, OBB, or PCA)
4. **Process**: Tap "Process File" to upload and analyze
5. **View Results**: Dimensions will be displayed after processing

## Project Structure

```
app/
├── App.js              # Main application component
├── config.js           # Appwrite configuration ⚠️ EDIT THIS
├── package.json        # Dependencies and scripts
├── app.json           # Expo configuration
├── babel.config.js    # Babel configuration
├── services/
│   └── apiService.js  # Appwrite service layer
└── README.md          # This file
```

## How It Works

1. **File Upload**: User selects a PLY file using Expo Document Picker
2. **Cloud Storage**: File is uploaded to Appwrite Storage
3. **Database Entry**: A processing record is created in Appwrite Database
4. **Serverless Processing**: Appwrite Function processes the file using Open3D
5. **Real-time Updates**: App polls the database for processing status
6. **Results Display**: Dimensions are displayed when processing completes

## Appwrite Architecture

```
Mobile App (React Native)
    ↓
Appwrite SDK
    ↓
┌─────────────────────┐
│  Appwrite Cloud     │
│  ┌───────────────┐  │
│  │ Storage       │  │ ← PLY files stored here
│  └───────────────┘  │
│  ┌───────────────┐  │
│  │ Database      │  │ ← Results stored here
│  └───────────────┘  │
│  ┌───────────────┐  │
│  │ Functions     │  │ ← Processing happens here
│  │ (Python 3.10) │  │
│  └───────────────┘  │
└─────────────────────┘
```

## Development

To run on specific platforms:

```bash
npm run android  # Run on Android emulator
npm run ios      # Run on iOS simulator (Mac only)
npm run web      # Run in web browser
```

## Troubleshooting

### "Cannot connect to Appwrite"

- Verify the Project ID in `config.js` is correct
- Check your internet connection
- Ensure your Appwrite project is active at https://cloud.appwrite.io

### "Processing timeout"

- Large files (>50MB) may take longer
- Check function logs in Appwrite Console
- Verify the function is deployed and active

### "Invalid file type"

- Only PLY files are supported
- Make sure the file has a `.ply` extension

### App won't load

- Try clearing the Expo cache: `expo start -c`
- Reinstall dependencies: `rm -rf node_modules && npm install`

### Upload fails

- Check file size (max 100MB)
- Ensure stable internet connection
- Check Appwrite Console for error logs

## Appwrite Free Tier

The Appwrite Cloud free tier includes:
- **2GB Storage** - Plenty for PLY files
- **10GB Bandwidth/month** - ~100-200 file uploads/downloads
- **750K Function Executions/month** - 100s of file processing operations
- **Unlimited Users**

Perfect for development and small-scale projects!

## Notes

- Processing may take 10-60 seconds depending on file size and complexity
- All measurements are in **meters**
- Processed files are stored in Appwrite Storage
- Results are saved in Appwrite Database for history
- Works from anywhere with internet (no local server required!)

## Advanced Features

The service includes additional methods you can integrate:

- `getHistory()` - Fetch processing history
- `deleteResult()` - Delete results and files
- Real-time updates using Appwrite Realtime API (coming soon)

## Support

For issues or questions, check:
- The main project README
- Flask server console output for errors
- Expo documentation: https://docs.expo.dev
