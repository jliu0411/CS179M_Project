import numpy as np
from pathlib import Path
from src.logic.dataclean_hmasr import dataclean

# -----------------------------
# Ground Truth (cm)
# -----------------------------
GROUND_TRUTH = {
    1:  [8, 21.2, 15.9],
    2:  [8.7, 27.8, 22.1],
    3:  [10, 27.8, 25],
    4:  [5.1, 36.4, 36.6],
    5:  [11.7, 33.3, 26.1],
    6:  [22, 39, 29.5],
    7:  [11.5, 53, 32.2],
    8:  [24.4, 40.8, 32.7],
    9:  [24.4, 40.4, 33],
    10: [10.9, 49.5, 29.5],
    11: [12.3, 38.2, 27.9],
    12: [12.2, 38, 27.5],
    13: [27.6, 39.9, 29.8],
    14: [17, 40, 33],
    15: [21.7, 33.2, 23.4],
    16: [30.8, 34.9, 26],
    17: [34.7, 49.9, 37],
    18: [7.2, 36, 25.3],
    19: [19.7, 44.5, 29.7],
    20: [27.5, 40.5, 29.6],
    21: [23.8, 45, 32.4],
    22: [17, 49.3, 35.5],
    23: [31.5, 30.7, 20.4],
    24: [19.5, 40.2, 28.7],
    25: [24.7, 39.2, 29.1],
    26: [19.7, 50, 29.4],
}


def main():

    data_dir = Path("src/data/pictures")  # adjust if needed

    total_errors = []
    print("\nBOX |   GT (sorted)   |   Pred (sorted)   |  Mean Abs Error")
    print("-" * 70)

    for i in range(1, 2):

        file_path = data_dir / f"bottle.ply"

        result = dataclean(
            str(file_path),
            visualize_flag=True,
            verbose=True
        )

        pred_dims = sorted([
            result["height"],
            result["width"],
            result["length"]
        ])

        gt_dims = sorted(GROUND_TRUTH[i])

        errors = np.abs(np.array(pred_dims) - np.array(gt_dims))
        mae = np.mean(errors)

        total_errors.append(mae)

        print(f"{i:>3} | "
              f"{[round(x,1) for x in gt_dims]} | "
              f"{[round(x,1) for x in pred_dims]} | "
              f"{mae:6.2f} cm")

    overall_mae = np.mean(total_errors)

    print("\n" + "=" * 70)
    print(f"Overall Mean Absolute Error: {overall_mae:.2f} cm")
    print("=" * 70)


if __name__ == "__main__":
    main()