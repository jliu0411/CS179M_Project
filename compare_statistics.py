import pandas as pd
import numpy as np
from pathlib import Path


def compute_metrics(pred, true):
    error = pred - true
    mae = np.mean(np.abs(error))
    rmse = np.sqrt(np.mean(error ** 2))
    bias = np.mean(error)
    std = np.std(error)
    return mae, rmse, bias, std


def evaluate_method(method_file, hand_df):

    df = pd.read_csv(method_file)

    # Convert meters → centimeters
    df[["Height", "Width", "Length"]] *= 100

    # Merge on box number
    merged = df.merge(hand_df, on="number", suffixes=("_pred", "_true"))

    all_pred = []
    all_true = []

    # Row-wise sorted matching
    for _, row in merged.iterrows():

        pred_dims = np.array([
            row["Height_pred"],
            row["Width_pred"],
            row["Length_pred"]
        ])

        true_dims = np.array([
            row["Height_true"],
            row["Width_true"],
            row["Length_true"]
        ])

        pred_sorted = np.sort(pred_dims)
        true_sorted = np.sort(true_dims)

        all_pred.extend(pred_sorted)
        all_true.extend(true_sorted)

    all_pred = np.array(all_pred)
    all_true = np.array(all_true)

    mae, rmse, bias, std = compute_metrics(all_pred, all_true)

    return mae, rmse, bias, std


def main():

    base_dir = Path("output/statistics")

    hand_df = pd.read_csv(base_dir / "hand_results.csv")

    methods = {
        "AABB": base_dir / "AABB_measurement_results.csv",
        "HULL": base_dir / "HULL_measurement_results.csv",
        "OBB":  base_dir / "OBB_measurement_results.csv"
    }

    print("\n===== SORTED DIMENSION COMPARISON =====")

    for method_name, method_file in methods.items():

        mae, rmse, bias, std = evaluate_method(method_file, hand_df)

        print(f"\n{method_name}:")
        print(f"  MAE (cm):  {mae:.3f}")
        print(f"  RMSE (cm): {rmse:.3f}")
        print(f"  Bias (cm): {bias:.3f}")
        print(f"  Std (cm):  {std:.3f}")


if __name__ == "__main__":
    main()