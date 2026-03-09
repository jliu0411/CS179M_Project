# Render Deployment Guide for PLY Scanner Backend

This guide will help you deploy your FastAPI backend to Render so your iOS app can work from anywhere without IP address matching.

## Why Render?
- ✅ **Free tier** - No credit card needed to start
- ✅ **Fixed URL** - No more IP address changes
- ✅ **Automatic deployments** - Push to GitHub and auto-deploy
- ✅ **Easy setup** - Takes ~10 minutes

---

## Step 1: Prepare Your Repository

### 1.1 Initialize Git (if not already done)
```bash
cd /Users/jamesliu/CS179M_Project
git init
git add .
git commit -m "Initial commit for Render deployment"
```

### 1.2 Create a GitHub Repository
1. Go to https://github.com/new
2. Create a new repository (e.g., `ply-scanner-backend`)
3. **Don't** initialize with README (you already have code)
4. Copy the repository URL

### 1.3 Push to GitHub
```bash
git remote add origin https://github.com/YOUR_USERNAME/ply-scanner-backend.git
git branch -M main
git push -u origin main
```

---

## Step 2: Deploy to Render

### 2.1 Sign Up for Render
1. Go to https://render.com
2. Sign up with your GitHub account (easiest option)
3. Authorize Render to access your repositories

### 2.2 Create a New Web Service
1. Click **"New +"** → **"Web Service"**
2. Connect your `ply-scanner-backend` repository
3. Render will auto-detect it's a Python project

### 2.3 Configure the Service
Use these settings:

| Setting | Value |
|---------|-------|
| **Name** | `ply-scanner-backend` (or your choice) |
| **Region** | Choose closest to you |
| **Branch** | `main` |
| **Runtime** | `Python 3` |
| **Build Command** | `pip install -r requirements.txt` |
| **Start Command** | `uvicorn src.api.ply_upload:app --host 0.0.0.0 --port $PORT` |
| **Plan** | **Free** |

### 2.4 Add Environment Variables (Optional)
Click **"Advanced"** → **"Add Environment Variable"**
- No variables needed for basic setup
- Can add later for features like API keys

### 2.5 Add Persistent Disk (for file storage)
1. Scroll to **"Disk"**
2. Click **"Add Disk"**
3. Name: `ply-storage`
4. Mount Path: `/opt/render/project/src/uploads`
5. Size: **1 GB** (free tier)

### 2.6 Deploy
1. Click **"Create Web Service"**
2. Render will start building (takes 5-10 minutes first time)
3. Watch the logs - you'll see:
   - Installing dependencies
   - Starting uvicorn
   - "Deployed successfully" ✅

---

## Step 3: Get Your Render URL

Once deployed, you'll see:
```
Your service is live at https://ply-scanner-backend.onrender.com
```

**Copy this URL** - you'll need it for the iOS app!

---

## Step 4: Update iOS App Configuration

### 4.1 Open NetworkService.swift
File: `iOS_App/PLYScanner/NetworkService.swift`

### 4.2 Update Production URL
Find this section:
```swift
case .production:
    // Replace with your Render URL after deployment
    return "https://ply-scanner-backend.onrender.com"
```

**Replace** `ply-scanner-backend.onrender.com` with **your actual Render URL**

### 4.3 Set Environment to Production
Change this line:
```swift
private let currentEnvironment: Environment = .production
```

### 4.4 Rebuild iOS App
1. Clean build: **Product** → **Clean Build Folder** (Shift+Cmd+K)
2. Build and run on your device

---

## Step 5: Test Your Deployment

### 5.1 Test the API Endpoint
Open this URL in your browser:
```
https://YOUR-APP.onrender.com/docs
```

You should see the FastAPI interactive docs (Swagger UI).

### 5.2 Test from iOS App
1. Open the PLY Scanner app
2. Select a PLY file
3. Upload it
4. ✅ Should work from **any WiFi network or cellular data**!

---

## Common Issues & Solutions

### Issue: "Service Unavailable" after 15 minutes
**Cause**: Free tier spins down after inactivity  
**Solution**: First request after inactivity takes ~30-60 seconds to wake up. This is normal on free tier.

**Fix**: Add a loading message in your iOS app:
```swift
// In NetworkService.swift, add a note:
print("⏳ Server may take up to 60 seconds to wake up if inactive...")
```

### Issue: Large PLY files timing out
**Cause**: Free tier has limited resources  
**Solution**: 
1. Increase timeout in NetworkService.swift:
   ```swift
   request.timeoutInterval = 120  // 2 minutes instead of 60
   ```
2. Or upgrade to Render's Starter plan ($7/month) for better performance

### Issue: "Disk full" errors
**Cause**: 1GB free disk fills up  
**Solution**: Add cleanup logic to delete old files:

```python
# In ply_upload.py, add cleanup function
import os
from datetime import datetime, timedelta

def cleanup_old_files():
    """Delete files older than 24 hours"""
    now = datetime.now()
    for folder in [UPLOAD_DIR, OUTPUT_DIR]:
        for file in folder.iterdir():
            if file.is_file():
                file_age = now - datetime.fromtimestamp(file.stat().st_mtime)
                if file_age > timedelta(hours=24):
                    file.unlink()
                    print(f"🗑️ Cleaned up old file: {file.name}")

# Call at start of upload_ply:
@app.post("/api/upload-ply")
async def upload_ply(file: UploadFile = File(...)):
    cleanup_old_files()  # Add this line
    # ... rest of code
```

### Issue: Deployment fails with "Module not found"
**Cause**: Missing dependency in requirements.txt  
**Solution**: 
1. Activate your local venv: `source venv310/bin/activate`
2. Generate requirements: `pip freeze > requirements.txt`
3. Commit and push: `git add requirements.txt && git commit -m "Update deps" && git push`
4. Render will auto-redeploy

---

## Switching Between Local and Production

Want to test locally sometimes? Easy!

1. In NetworkService.swift, change:
   ```swift
   private let currentEnvironment: Environment = .local  // For local testing
   ```

2. When ready for production:
   ```swift
   private let currentEnvironment: Environment = .production  // Use Render
   ```

3. Rebuild the app

---

## Monitoring & Logs

### View Logs
1. Go to Render dashboard
2. Click your service
3. Click **"Logs"** tab
4. See real-time logs of all API requests

### Useful log messages:
- `📥 Received file: example.ply` - Upload started
- `✅ Processing complete!` - Success
- `❌ Processing error:` - Error occurred

---

## Automatic Deployments

Once connected to GitHub:
1. Make code changes locally
2. Commit: `git add . && git commit -m "Your change"`
3. Push: `git push`
4. Render automatically deploys! (takes 2-3 minutes)

---

## Costs

**Free Tier Includes:**
- 750 hours/month runtime (enough for personal use)
- 1GB disk storage
- Automatic SSL (HTTPS)
- Auto-sleep after 15 min inactivity

**Limitations:**
- Cold start after inactivity (~30-60 sec)
- Limited CPU/memory
- 1GB disk

**Upgrade to Starter ($7/month) for:**
- No cold starts
- More CPU/memory
- More disk storage
- Better performance

---

## Next Steps

### Optional Enhancements:
1. **Add authentication** - Require API keys for uploads
2. **Add database** - Track upload history with PostgreSQL (free on Render)
3. **Add email notifications** - Get notified when processing completes
4. **Add file size limits** - Prevent abuse on free tier

### Production Checklist:
- [ ] Update CORS in `ply_upload.py` to only allow your app's domain
- [ ] Add rate limiting to prevent abuse
- [ ] Set up monitoring/alerts
- [ ] Add error tracking (e.g., Sentry)
- [ ] Add file cleanup cron job

---

## Support

Need help?
- Render docs: https://render.com/docs
- Render community: https://community.render.com
- FastAPI docs: https://fastapi.tiangolo.com

---

## Summary

✅ **You now have:**
- A cloud-hosted FastAPI backend with a fixed URL
- No more IP address matching issues
- Your app works from anywhere with internet
- Free hosting for personal/development use

🎉 **Your PLY Scanner app is now cloud-ready!**
