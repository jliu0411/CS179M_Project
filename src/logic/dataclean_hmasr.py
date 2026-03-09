import open3d as o3d
import numpy as np
from pathlib import Path
from src.logic.remove_plain2 import remove_large_planes


def dataclean(dir: str,
              visualize_flag=True,
              output_dir="output",
              verbose=False):

    def show_step(title, pcd):
        if not verbose:
            return
        print(f"\n--- {title} ---")
        o3d.visualization.draw_geometries([pcd])

    pcd = o3d.io.read_point_cloud(dir)

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # -------------------------------------------------
    # 1. Initial Noise Removal (robust but not aggressive)
    # -------------------------------------------------
    pcd, _ = pcd.remove_statistical_outlier(nb_neighbors=20, std_ratio=2.0)
    pcd, _ = pcd.remove_radius_outlier(nb_points=10, radius=0.02)

    show_step("After Initial Outlier Removal", pcd)

    # -------------------------------------------------
    # 2. Smart Floor Removal (borrowed from Version 2)
    # -------------------------------------------------
    plane_model, inliers = pcd.segment_plane(
        distance_threshold=0.005,
        ransac_n=3,
        num_iterations=1000
    )

    [a, b, c, d] = plane_model
    normal = np.array([a, b, c])
    normal /= np.linalg.norm(normal)

    is_horizontal = abs(normal @ np.array([0, 0, 1])) > 0.9

    if is_horizontal:
        plane_cloud = pcd.select_by_index(inliers)
        plane_z = np.mean(np.asarray(plane_cloud.points)[:, 2])
        cloud_z = np.mean(np.asarray(pcd.points)[:, 2])

        # Only remove if below object
        if plane_z < cloud_z:
            pcd = pcd.select_by_index(inliers, invert=True)

    show_step("After Floor Removal", pcd)

    # -------------------------------------------------
    # 3. Remove other large planes
    # -------------------------------------------------
    pcd = remove_large_planes(pcd, max_planes=3)
    show_step("After Removing Large Planes", pcd)

    # -------------------------------------------------
    # 4. DBSCAN – isolate largest object
    # -------------------------------------------------
    labels = np.array(
        pcd.cluster_dbscan(eps=0.015, min_points=50)
    )

    valid = labels >= 0
    largest_label = np.bincount(labels[valid]).argmax()

    pcd = pcd.select_by_index(
        np.where(labels == largest_label)[0]
    )

    show_step("After DBSCAN", pcd)

    # -------------------------------------------------
    # 5. Light Cleanup (no aggressive percentile trimming)
    # -------------------------------------------------
    pcd, _ = pcd.remove_statistical_outlier(nb_neighbors=30, std_ratio=0.8)
    pcd, _ = pcd.remove_radius_outlier(nb_points=20, radius=0.01)

    # -------------------------------------------------
    # 6. PCA Alignment (stable orientation)
    # -------------------------------------------------
    points = np.asarray(pcd.points)
    center = points.mean(axis=0)
    centered = points - center

    U, S, Vt = np.linalg.svd(centered, full_matrices=False)
    aligned = centered @ Vt.T

    pcd.points = o3d.utility.Vector3dVector(aligned)

    # 6. Plane-based alignment - extract normals WITHOUT removing points
    normals = [] 
    temp_pcd = pcd # Work on a copy for plane detection 
    
    for _ in range(3): 
        plane_model, inliers = temp_pcd.segment_plane(
            distance_threshold=0.005, ransac_n=3, num_iterations=1000)
        [a, b, c, d] = plane_model
        normal = np.array([a, b, c])
        normal /= np.linalg.norm(normal)
        normals.append(normal) 
        
        # Remove points temporarily ONLY for finding next plane
        temp_pcd = temp_pcd.select_by_index(inliers, invert=True)
    
    if len(normals) >= 2:
        n1 = normals[0] 
        n2 = normals[1] - np.dot(normals[1], n1) * n1
        n2 /= np.linalg.norm(n2)
        n3 = np.cross(n1, n2)
        n3 /= np.linalg.norm(n3)
        R = np.vstack([n1, n2, n3]).T
        
        points = np.asarray(pcd.points)
        center = points.mean(axis=0)
        aligned = (points - center) @ R
        pcd.points = o3d.utility.Vector3dVector(aligned)


    # -------------------------------------------------
    # 7. OBB Measurement
    # -------------------------------------------------
    obb = pcd.get_axis_aligned_bounding_box()
    extent = obb.get_extent()

    # Sort dimensions smallest → largest
    dims = sorted(extent)

    height = dims[0] * 100  # convert to cm
    width  = dims[1] * 100
    length = dims[2] * 100

    # -------------------------------------------------
    # Save Output
    # -------------------------------------------------
    input_path = Path(dir)
    output_path = Path(output_dir) / f"{input_path.stem}_cleaned.ply"
    o3d.io.write_point_cloud(str(output_path), pcd)

    if visualize_flag:
        obb.color = (1, 0, 0)
        coordinate_frame = o3d.geometry.TriangleMesh.create_coordinate_frame(size=0.1)
        o3d.visualization.draw_geometries([pcd, obb, coordinate_frame])

    return {
        "height": float(height),
        "width": float(width),
        "length": float(length)
    }