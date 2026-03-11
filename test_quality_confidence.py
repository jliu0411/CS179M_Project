#!/usr/bin/env python3
"""
Test quality-based confidence calculation
"""

def calculate_quality_confidence(dimensions):
    """
    Calculate confidence score based on scan quality metrics alone.
    """
    scores = []
    
    # 1. Point density score (20k-50k is optimal)
    point_count = dimensions.get('point_count', 0)
    if point_count >= 20000:
        point_score = min(point_count / 30000, 1.5) * 0.67
    else:
        point_score = point_count / 20000
    scores.append(min(point_score, 1.0))
    
    # 2. RANSAC quality (lower ratio = cleaner object extraction)
    ransac_ratio = dimensions.get('ransac_inlier_ratio', 0)
    ransac_score = 1.0 - min(ransac_ratio, 1.0)
    scores.append(ransac_score)
    
    # 3. Aspect ratio (1.0-3.0 is typical)
    aspect = dimensions.get('aspect_ratio', 0)
    if 1.0 <= aspect <= 3.0:
        aspect_score = 1.0
    elif aspect < 1.0:
        aspect_score = aspect
    else:
        aspect_score = max(0, 1.0 - (aspect - 3.0) / 5.0)
    scores.append(aspect_score)
    
    # 4. Point spread consistency
    std_x = dimensions.get('std_x', 0.05)
    std_y = dimensions.get('std_y', 0.05)
    std_z = dimensions.get('std_z', 0.05)
    avg_std = (std_x + std_y + std_z) / 3
    if avg_std <= 0.03:
        spread_score = 1.0
    else:
        spread_score = max(0, 1.0 - (avg_std - 0.03) / 0.05)
    scores.append(spread_score)
    
    # Weighted average
    weights = [0.25, 0.35, 0.20, 0.20]
    confidence = sum(s * w for s, w in zip(scores, weights)) * 100
    
    print(f"  Point score: {scores[0]:.2f} (count: {dimensions.get('point_count')})")
    print(f"  RANSAC score: {scores[1]:.2f} (ratio: {dimensions.get('ransac_inlier_ratio'):.3f})")
    print(f"  Aspect score: {scores[2]:.2f} (ratio: {dimensions.get('aspect_ratio'):.2f})")
    print(f"  Spread score: {scores[3]:.2f} (avg std: {avg_std:.4f})")
    print(f"  → Confidence: {confidence:.1f}%")
    
    return round(confidence, 2)

# Test cases
print("=== Test Case 1: Excellent scan ===")
excellent = {
    'point_count': 30000,
    'ransac_inlier_ratio': 0.15,  # Low = clean floor removal
    'std_x': 0.02,
    'std_y': 0.02,
    'std_z': 0.02,
    'aspect_ratio': 1.8
}
calculate_quality_confidence(excellent)

print("\n=== Test Case 2: Good scan (typical) ===")
good = {
    'point_count': 25000,
    'ransac_inlier_ratio': 0.20,
    'std_x': 0.025,
    'std_y': 0.022,
    'std_z': 0.018,
    'aspect_ratio': 2.1
}
calculate_quality_confidence(good)

print("\n=== Test Case 3: Poor scan ===")
poor = {
    'point_count': 15000,
    'ransac_inlier_ratio': 0.40,  # High = lots of floor/background
    'std_x': 0.05,
    'std_y': 0.06,
    'std_z': 0.04,
    'aspect_ratio': 5.2  # Extreme aspect ratio
}
calculate_quality_confidence(poor)

print("\n=== Test Case 4: Sparse scan ===")
sparse = {
    'point_count': 10000,
    'ransac_inlier_ratio': 0.35,
    'std_x': 0.04,
    'std_y': 0.03,
    'std_z': 0.05,
    'aspect_ratio': 2.5
}
calculate_quality_confidence(sparse)
