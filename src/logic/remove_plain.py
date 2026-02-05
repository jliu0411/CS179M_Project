def remove_large_planes(pcd, max_planes=3):
    remaining = pcd
    for _ in range(max_planes):
        plane_model, inliers = remaining.segment_plane(
            distance_threshold=0.005,
            ransac_n=3,
            num_iterations=1000
        )

        if len(inliers) < 5000:
            break  # stop if plane is small

        remaining = remaining.select_by_index(inliers, invert=True)

    return remaining
