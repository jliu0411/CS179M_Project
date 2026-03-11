#!/usr/bin/env python3
"""
Test script for the PLY upload API
Tests the backend without needing the iOS app
"""

import requests
from pathlib import Path

# Configuration
API_URL = "http://localhost:8000"
TEST_FILE = "uploads/0000006.ply"  # Use existing test file

def test_health_check():
    """Test if the server is running"""
    print("Testing health check endpoint...")
    try:
        response = requests.get(f"{API_URL}/api/health")
        if response.status_code == 200:
            print(f"✅ Health check passed: {response.json()}")
            return True
        else:
            print(f"❌ Health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Server not reachable: {e}")
        print("\nMake sure the server is running:")
        print("  source venv310/bin/activate")
        print("  python -m uvicorn src.api.ply_upload:app --host 0.0.0.0 --port 8000 --reload")
        return False

def test_ply_upload():
    """Test PLY file upload and processing"""
    print(f"\nTesting PLY upload with {TEST_FILE}...")
    
    test_file_path = Path(TEST_FILE)
    if not test_file_path.exists():
        print(f"❌ Test file not found: {TEST_FILE}")
        return False
    
    try:
        with open(test_file_path, 'rb') as f:
            files = {'file': (test_file_path.name, f, 'application/octet-stream')}
            response = requests.post(f"{API_URL}/api/upload-ply", files=files)
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Upload and processing successful!")
            print(f"\nOriginal file: {result['original_filename']}")
            print(f"Cleaned file: {result['cleaned_filename']}")
            print(f"\nDimensions:")
            print(f"  Width:  {result['dimensions']['width']:.3f} m")
            print(f"  Length: {result['dimensions']['length']:.3f} m")
            print(f"  Height: {result['dimensions']['height']:.3f} m")
            
            if 'confidence' in result:
                print(f"\nConfidence: {result['confidence']:.1f}%")
                print("  (Based on reference measurements)")
            
            if 'quality_metrics' in result:
                print(f"\nQuality Metrics:")
                print(f"  Point count: {result['quality_metrics']['point_count']}")
                print(f"  RANSAC inlier ratio: {result['quality_metrics']['ransac_inlier_ratio']:.3f}")
                print(f"  Aspect ratio: {result['quality_metrics']['aspect_ratio']:.2f}")
            
            return True
        else:
            print(f"❌ Upload failed: {response.status_code}")
            print(f"Response: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Error during upload: {e}")
        return False

def main():
    print("=" * 60)
    print("PLY Upload API - Test Script")
    print("=" * 60)
    
    if not test_health_check():
        return
    
    if test_ply_upload():
        print("\n" + "=" * 60)
        print("✅ All tests passed! API is working correctly.")
        print("=" * 60)
        print("\nYou can now use the iOS app to upload PLY files.")
        print("Make sure to update NetworkService.swift with this machine's IP address.")
    else:
        print("\n" + "=" * 60)
        print("❌ Some tests failed. Check the errors above.")
        print("=" * 60)

if __name__ == "__main__":
    main()
