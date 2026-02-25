# PLY Processor Mobile App - Quick Start Guide

## 🚀 Getting Started in 3 Steps

### Step 1: Set Up Appwrite (5 minutes)

**Create Appwrite Project:**
1. Go to https://cloud.appwrite.io and sign up (free)
2. Create a new project called "PLY Processor"
3. Copy your **Project ID** (you'll need this!)

**Create Database:**
1. Go to Databases → Create Database
2. Name: `main`, ID: `main`
3. Create Collection: name `results`, ID: `results`
4. Add these attributes:
   - `filename` (String, 255)
   - `method` (String, 10)
   - `width` (Double)
   - `length` (Double)
   - `height` (Double)
   - `fileId` (String, 255)
   - `status` (String, 50)
   - `error` (String, 1000, optional)
5. Set Permissions: Read, Create, Update, Delete → **Any**

**Create Storage:**
1. Go to Storage → Create Bucket
2. Name: `PLY Files`, ID: `ply-files`
3. Max file size: `104857600` (100MB)
4. Allowed extensions: `ply`
5. Set Permissions: Read, Create, Update, Delete → **Any**

**Deploy Function:**
1. Go to Functions → Create Function
2. Name: `Process PLY File`, ID: `process-ply`
3. Runtime: `Python 3.10`
4. Zip the `appwrite_functions/process-ply/` folder
5. Upload and activate

📖 Need detailed instructions? See [APPWRITE_SETUP.md](../APPWRITE_SETUP.md)

### Step 2: Configure & Install

**Install App Dependencies:**
```bash
cd app
npm install
```

**Update Configuration:**

Edit `app/config.js` and add your Project ID:
```javascript
export const APPWRITE_CONFIG = {
  endpoint: 'https://cloud.appwrite.io/v1',
  projectId: 'YOUR_PROJECT_ID_HERE',  // ⚠️ PASTE HERE
  // ... rest stays the same
};
```

### Step 3: Run the App

**Start Expo:**
```bash
cd app
npm start
```

**On Your Phone:**
1. Install "Expo Go" from app store
2. Scan the QR code
3. Start uploading PLY files! ✅

---

## 📱 Using the App

1. ✅ Check that connection shows "Connected" (green indicator)
2. 📁 Tap "Choose File" and select a PLY file
3. 🔧 Select processing method (AABB, OBB, or PCA)
4. 🚀 Tap "Process File"
5. 📊 View the dimensions results!

---

## ❓ Troubleshooting

**Shows "Disconnected":**
- Verify Project ID in config.js is correct
- Check internet connection
- Ensure Appwrite project is active

**Can't select PLY files:**
- Make sure file has .ply extension
- File must be accessible on your device

**Processing timeout:**
- Check Appwrite Console → Functions → process-ply → Executions
- Verify function is deployed and active
- Large files (>50MB) may need more time

---

## 💰 Appwrite Free Tier

Perfect for this project!
- ✅ 2GB Storage
- ✅ 10GB Bandwidth/month
- ✅ 750K Function executions/month
- ✅ Unlimited users

No credit card required!

---

## 📖 More Information

- [app/README.md](README.md) - Complete app documentation
- [../APPWRITE_SETUP.md](../APPWRITE_SETUP.md) - Detailed Appwrite setup
- [../README.md](../README.md) - Main project documentation

## 🛠️ Project Structure

```
app/
├── App.js              # Main UI component
├── config.js           # Appwrite configuration ⚠️ EDIT THIS
├── services/
│   └── apiService.js   # Appwrite SDK wrapper
├── package.json        # Dependencies
└── app.json           # Expo configuration
```

---

## 🎯 How It Works

```
1. Upload PLY file → Appwrite Storage
2. Create record → Appwrite Database
3. Trigger → Appwrite Function (Python + Open3D)
4. Processing → Extract dimensions
5. Update → Database with results
6. Display → Show in app
```

All in the cloud! No server needed! ☁️

---

## 💡 Tips

- ✅ Use WiFi for faster uploads
- ✅ Keep files under 50MB for best performance
- ✅ AABB method is fastest, PCA is most accurate
- ✅ View processing history in Appwrite Console
- ✅ Monitor usage in Appwrite Console → Settings

---

Need help? Check:
- Appwrite Docs: https://appwrite.io/docs
- Appwrite Discord: https://appwrite.io/discord
