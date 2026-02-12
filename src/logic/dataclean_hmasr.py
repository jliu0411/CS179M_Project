import open3d as o3d
import numpy as np
from pathlib import Path
from src.logic.remove_plain import remove_large_planes

# Load point cloud (works for .ply and .xyz)
def dataclean(dir:str, visualize_flag=True, output_dir="output"):
    pcd = o3d.io.read_point_cloud(dir)

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # 1. Radius outlier removal (your first layer)
    pcd, _ = pcd.remove_radius_outlier(
        nb_points=10,
        radius=0.02
    )

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


    # 4. RANSAC
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


    ###
    #DBSCAN
    labels = np.array(
        pcd_no_planes.cluster_dbscan(
            eps=0.02,
            min_points=100
        )
    )

    valid = labels >= 0
    largest_label = np.bincount(labels[valid]).argmax()

    pcd_target = pcd_no_planes.select_by_index(
        np.where(labels == largest_label)[0]
    )

    pcd_target.paint_uniform_color([0, 1, 0])

#####################################

     # --- 6. Optional: voxel downsampling ---
    pcd_target = pcd_target.voxel_down_sample(voxel_size=0.002)

    # --- 7. PCA alignment ---
    points = np.asarray(pcd_target.points)
    centered = points - points.mean(axis=0)

    U, S, Vt = np.linalg.svd(centered, full_matrices=False)
    aligned_points = centered @ Vt.T
    pcd_target.points = o3d.utility.Vector3dVector(aligned_points)

    pts = np.asarray(pcd_target.points)

    #z_floor = np.min(pts[:, 2])
    #mask = pts[:, 2] > z_floor + 0.003

    z_floor = np.percentile(pts[:, 2], 0.5)  # Use percentile instead of min
    z_ceiling = np.percentile(pts[:, 2], 99.5)
    mask_z = (pts[:, 2] > z_floor) & (pts[:, 2] < z_ceiling)


    # Remove X and Y outliers
    x_min, x_max = np.percentile(pts[:, 0], [1, 97.5])
    y_min, y_max = np.percentile(pts[:, 1], [1, 97.5])
    mask_x = (pts[:, 0] > x_min) & (pts[:, 0] < x_max)
    mask_y = (pts[:, 1] > y_min) & (pts[:, 1] < y_max)

    mask = mask_z & mask_x & mask_y
    pcd_target = pcd_target.select_by_index(np.where(mask)[0])
#####################################

    pcd_target, _ = pcd_target.remove_statistical_outlier(
       nb_neighbors=30,
       std_ratio=1.0
    )

    #### 
    # AABB
    aabb = pcd_target.get_axis_aligned_bounding_box()
    extent = aabb.get_extent()  # (dx, dy, dz)
    
    #obb = pcd_target.get_oriented_bounding_box()
    #extent = obb.extent

    # Before calculating OBB, visualize with coordinate frame
    #coordinate_frame = o3d.geometry.TriangleMesh.create_coordinate_frame(size=0.1)
    #o3d.visualization.draw_geometries([pcd_target, aabb, coordinate_frame])

    width, length, height = extent
#    print(f"Box #{dir} dimensions:")
#    print(f"Width:  {width:.3f}")
#    print(f"Length: {length:.3f}")
#    print(f"Height: {height:.3f}")

    input_path = Path(dir)
    output_path = output_dir / f"{input_path.stem}_cleaned.ply"

    o3d.io.write_point_cloud(str(output_path), pcd_target)


    if visualize_flag:
        o3d.visualization.draw_geometries([pcd_target])       

    return height, width, length

# dataclean("src/data/0000006.ply")