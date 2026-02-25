"""
Appwrite Function to process PLY files and extract dimensions
This function is triggered when called via the Appwrite API
"""
import json
import os
import tempfile
from pathlib import Path
from appwrite.client import Client
from appwrite.services.storage import Storage
from appwrite.services.databases import Databases

# Import the dataclean processing logic
# Note: We need to copy the relevant processing code here since Appwrite Functions
# run in isolated environments
import open3d as o3d
import numpy as np


def remove_large_planes(pcd, max_planes=3, distance_threshold=0.005):
    """Remove large planes from point cloud (simplified version)"""
    temp_pcd = pcd
    for i in range(max_planes):
        if len(temp_pcd.points) < 100:
            break
        
        plane_model, inliers = temp_pcd.segment_plane(
            distance_threshold=distance_threshold,
            ransac_n=3,
            num_iterations=1000
        )
        
        if len(inliers) < len(temp_pcd.points) * 0.1:
            break
        
        temp_pcd = temp_pcd.select_by_index(inliers, invert=True)
    
    return temp_pcd


def process_ply_file(file_path, method="AABB"):
    """
    Process PLY file and extract dimensions
    Returns dict with width, length, height
    """
    # Load point cloud
    pcd = o3d.io.read_point_cloud(file_path)
    
    # 1. Radius outlier removal
    pcd, _ = pcd.remove_radius_outlier(nb_points=10, radius=0.02)
    
    points = np.asarray(pcd.points)
    z = points[:, 2]
    
    # 2. Normalize Z to [0, 1]
    z_min, z_max = z.min(), z.max()
    z_norm = (z - z_min) / (z_max - z_min)
    
    # 3. Histogram equalization
    hist, bins = np.histogram(z_norm, bins=256, density=True)
    cdf = hist.cumsum()
    cdf = cdf / cdf[-1]
    z_eq = np.interp(z_norm, bins[:-1], cdf)
    
    low, high = np.percentile(z_eq, [2, 98])
    mask = (z_eq > low) & (z_eq < high)
    
    points_clean = points[mask]
    pcd_histogram = o3d.geometry.PointCloud()
    pcd_histogram.points = o3d.utility.Vector3dVector(points_clean)
    
    # 4. RANSAC floor removal
    plane_model, inliers = pcd_histogram.segment_plane(
        distance_threshold=0.005,
        ransac_n=3,
        num_iterations=1000
    )
    
    [a, b, c, d] = plane_model
    normal = np.array([a, b, c])
    normal /= np.linalg.norm(normal)
    
    # 5. Only accept near-horizontal planes
    if abs(normal @ np.array([0, 0, 1])) > 0.9:
        pcd_no_floor = pcd_histogram.select_by_index(inliers, invert=True)
    else:
        pcd_no_floor = pcd_histogram
    
    pcd_no_planes = remove_large_planes(pcd_no_floor, max_planes=3)
    
    # 6. DBSCAN clustering
    labels = np.array(pcd_no_planes.cluster_dbscan(eps=0.03, min_points=100))
    
    valid = labels >= 0
    largest_label = np.bincount(labels[valid]).argmax()
    
    pcd_target = pcd_no_planes.select_by_index(
        np.where(labels == largest_label)[0]
    )
    
    # Second clustering pass
    labels2 = np.array(pcd_target.cluster_dbscan(eps=0.015, min_points=50))
    
    valid = labels2 >= 0
    counts = np.bincount(labels2[valid])
    largest_label2 = np.argmax(counts)
    
    pcd_target = pcd_target.select_by_index(
        np.where(labels2 == largest_label2)[0]
    )
    
    # 7. Calculate dimensions based on method
    width = length = height = 0
    
    if method == "AABB":
        aabb = pcd_target.get_axis_aligned_bounding_box()
        extent = aabb.get_extent()
        width, length, height = extent
    
    elif method == "OBB":
        obb = pcd_target.get_oriented_bounding_box()
        extent = obb.extent
        dims = np.sort(extent)
        width, length, height = dims
    
    elif method == "PCA":
        points = np.asarray(pcd_target.points)
        centered = points - points.mean(axis=0)
        cov = np.cov(centered.T)
        eigvals, eigvecs = np.linalg.eigh(cov)
        order = np.argsort(eigvals)[::-1]
        eigvecs = eigvecs[:, order]
        proj = centered @ eigvecs
        low = np.percentile(proj, 2, axis=0)
        high = np.percentile(proj, 98, axis=0)
        dims = high - low
        dims = np.sort(dims)
        width, height, length = dims
    
    return {
        'width': float(width),
        'length': float(length),
        'height': float(height)
    }


def main(context):
    """
    Main Appwrite Function handler
    
    Expected payload:
    {
        "fileId": "string",
        "method": "AABB|OBB|PCA",
        "resultId": "string"  # Document ID to update with results
    }
    """
    try:
        # Parse request payload
        payload = json.loads(context.req.body) if context.req.body else {}
        
        file_id = payload.get('fileId')
        method = payload.get('method', 'AABB').upper()
        result_id = payload.get('resultId')
        
        if not file_id or not result_id:
            return context.res.json({
                'success': False,
                'error': 'Missing required parameters: fileId and resultId'
            }, status_code=400)
        
        if method not in ['AABB', 'OBB', 'PCA']:
            return context.res.json({
                'success': False,
                'error': 'Invalid method. Use AABB, OBB, or PCA'
            }, status_code=400)
        
        # Initialize Appwrite client
        client = Client()
        client.set_endpoint(os.environ.get('APPWRITE_ENDPOINT', 'https://cloud.appwrite.io/v1'))
        client.set_project(os.environ.get('APPWRITE_FUNCTION_PROJECT_ID'))
        client.set_key(os.environ.get('APPWRITE_API_KEY'))
        
        storage = Storage(client)
        databases = Databases(client)
        
        # Download file from Appwrite Storage
        file_content = storage.get_file_download('ply-files', file_id)
        
        # Save to temporary file
        with tempfile.NamedTemporaryFile(suffix='.ply', delete=False) as tmp_file:
            tmp_file.write(file_content)
            tmp_path = tmp_file.name
        
        try:
            # Process the PLY file
            dimensions = process_ply_file(tmp_path, method)
            
            # Update database with results
            databases.update_document(
                database_id='main',
                collection_id='results',
                document_id=result_id,
                data={
                    'width': dimensions['width'],
                    'length': dimensions['length'],
                    'height': dimensions['height'],
                    'status': 'completed'
                }
            )
            
            return context.res.json({
                'success': True,
                'dimensions': dimensions,
                'method': method,
                'fileId': file_id
            })
            
        finally:
            # Clean up temporary file
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
    
    except Exception as e:
        # Update database with error
        try:
            if 'result_id' in locals():
                databases.update_document(
                    database_id='main',
                    collection_id='results',
                    document_id=result_id,
                    data={
                        'status': 'failed',
                        'error': str(e)
                    }
                )
        except:
            pass
        
        return context.res.json({
            'success': False,
            'error': str(e)
        }, status_code=500)
