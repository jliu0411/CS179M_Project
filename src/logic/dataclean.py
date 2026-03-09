import open3d as o3d
import numpy as np
from pathlib import Path
from src.logic.remove_plain import remove_large_planes

# Load point cloud (works for .ply and .xyz)
def dataclean(dir:str, 
              visualize_flag=True, 
              method="AABB", 
              output_dir="output",
              verbose=False):


    ####
    # Verbose Flag helper function to display each steps
    def show_step(title, pcd, color=None):
        if not verbose:
            return
        print(f"\n--- {title} ---")
        temp = pcd
        if color is not None:
            temp = pcd.clone()
            temp.paint_uniform_color(color)
        o3d.visualization.draw_geometries([temp])
    ####
    
    pcd = o3d.io.read_point_cloud(dir)
    show_step("Original Point Cloud", pcd)

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    ###
    # 1. Radius outlier removal (your first layer)
    pcd, _ = pcd.remove_radius_outlier(
        nb_points=10,
        radius=0.02
    )

    points = np.asarray(pcd.points)
    z = points[:, 2]
    show_step("After Radius Outlier Removal", pcd)

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

    show_step("After Histogram Z Filtering(Equalization)", pcd_histogram)

    ###
    # 4. RANSAC
    plane_model, inliers = pcd_histogram.segment_plane(
        distance_threshold=0.005,
        ransac_n=3,
        num_iterations=1000
    )

    [a, b, c, d] = plane_model
    normal = np.array([a, b, c])
    normal /= np.linalg.norm(normal)

    ###
    # 5. Only accept near-horizontal planes
    if abs(normal @ np.array([0, 0, 1])) > 0.9:
        pcd_no_floor = pcd_histogram.select_by_index(inliers, invert=True)
    else:
        pcd_no_floor = pcd_histogram

    show_step("After Floor Removal (RANSAC)", pcd_no_floor)

    pcd_no_planes = remove_large_planes(pcd_no_floor, max_planes=3)

    show_step("After Removing Large Planes", pcd_no_planes)


    ###
    # 6. DBSCAN
    labels = np.array(
        pcd_no_planes.cluster_dbscan(
            eps = 0.02,
            min_points=100
        )
    )

    valid = labels >= 0
    largest_label = np.bincount(labels[valid]).argmax()

    pcd_target = pcd_no_planes.select_by_index(
        np.where(labels == largest_label)[0]
    )

    pcd_target.paint_uniform_color([0, 1, 0])
    show_step("After First DBSCAN (Largest Cluster)", pcd_target)


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

    pcd_target, _ = pcd_target.remove_statistical_outlier(
       nb_neighbors=30,
       std_ratio=1.0
    )

    show_step("After Fine Tuning", pcd_target)
    #####################################

    width = length = height = 0
    geometry_to_show = []

    # Always show cleaned target in gray
    pcd_vis = o3d.geometry.PointCloud(pcd_target)
    pcd_vis.paint_uniform_color([0.6, 0.6, 0.6])
    geometry_to_show.append(pcd_vis)

    #### 
    # Axis-Aligned Bounding Box (AABB)
    if method == "AABB":
        aabb = pcd_target.get_axis_aligned_bounding_box()
        extent = aabb.get_extent()
        width, length, height = extent

        aabb.color = (1, 0, 0)  # red
        geometry_to_show.append(aabb)

    ####
    # Oriented Bounding Box (OBB)
    elif method == "OBB":
        obb = pcd_target.get_oriented_bounding_box()
        extent = obb.extent
        dims = np.sort(extent)
        width, length, height = dims

        obb.color = (0, 1, 0)  # green
        geometry_to_show.append(obb)

    ####
    # PCA Bounding Box (manual)
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
        dims_sorted = np.sort(dims)
        width, length, height = dims_sorted

        # Create bounding box from PCA frame
        box = o3d.geometry.OrientedBoundingBox()
        box.center = points.mean(axis=0)
        box.R = eigvecs
        box.extent = dims
        box.color = (0, 0, 1)  # blue

        geometry_to_show.append(box)

    ####
    # Convex Hull (AABB from hull vertices)
    elif method == "HULL":
        hull, _ = pcd_target.compute_convex_hull()
        hull.compute_vertex_normals()
        hull.paint_uniform_color([1, 0, 0])  # red

        hull_points = np.asarray(hull.vertices)
        mins = hull_points.min(axis=0)
        maxs = hull_points.max(axis=0)

        dims = maxs - mins
        dims_sorted = np.sort(dims)
        width, length, height = dims_sorted

        geometry_to_show.append(hull)

    ####
    # Convex Hull + PCA
    elif method == "HULL_PCA":
        hull, _ = pcd_target.compute_convex_hull()
        hull.compute_vertex_normals()
        hull.paint_uniform_color([1, 0, 0])

        hull_points = np.asarray(hull.vertices)
        centered = hull_points - hull_points.mean(axis=0)

        U, S, Vt = np.linalg.svd(centered, full_matrices=False)
        aligned = centered @ Vt.T

        low = aligned.min(axis=0)
        high = aligned.max(axis=0)

        dims = high - low
        dims_sorted = np.sort(dims)
        width, length, height = dims_sorted

        geometry_to_show.append(hull)

    ############################################

    
    filename = dir.split('/')[-1]

    if verbose:
        print(f"{method} dimensions of {filename}:")
        print(f"Width:  {width:.3f}")
        print(f"Length: {length:.3f}")
        print(f"Height: {height:.3f}")

    input_path = Path(dir)
    output_path = output_dir / f"{input_path.stem}_cleaned.ply"

    o3d.io.write_point_cloud(str(output_path), pcd_target)  
      
    if visualize_flag:
        o3d.visualization.draw_geometries(geometry_to_show)

    # Return dimensions for batch processing
    return {
        'width': float(width),
        'length': float(length),
        'height': float(height)
    }