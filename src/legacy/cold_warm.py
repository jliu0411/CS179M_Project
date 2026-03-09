import open3d as o3d
import numpy as np
import colorsys


pcd = o3d.io.read_point_cloud("src/data/0000006.ply")

# 1. Radius-based noise removal
pcd, _ = pcd.remove_radius_outlier(
    nb_points=10,
    radius=0.02
)

points = np.asarray(pcd.points)
z = points[:, 2]

#####
# Histogram equalization on Z
z_norm = (z - z.min()) / (z.max() - z.min())
hist, bins = np.histogram(z_norm, bins=256, density=True)
cdf = hist.cumsum()
cdf /= cdf[-1]
z_eq = np.interp(z_norm, bins[:-1], cdf)

colors = np.zeros((len(z_eq), 3))

for i, v in enumerate(z_eq):
    hue = (1 - v) * 240 / 360.0
    colors[i] = colorsys.hsv_to_rgb(hue, 1.0, 1.0)

pcd.colors = o3d.utility.Vector3dVector(colors)
o3d.visualization.draw_geometries([pcd])



