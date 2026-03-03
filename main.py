import csv
import pandas as pd
from pathlib import Path
from src.logic.dataclean import dataclean
from src.model.mlmodel import load_data_from_csv, train_logistic_regression, train_decision_tree, train_kmeans, train_mlp

def truncate(f, n):
    """Truncates a float f to n decimal places without rounding"""
    factor = 10**n
    return int(f * factor) / factor

def main():

    # Choose method
    method = input("Choose the Method: (AABB / OBB / HULL / PCA)\n   -->  ").strip().upper()
    visualization = input("Would you like to visualize each result? (Y/N)\n   -->  ").strip().upper()
    visualization_flag = False
    if visualization == "Y":
        visualization_flag = True
    verbose = input("Would you like to execute with verbose mode? (Y/N)\n   -->  ").strip().upper()
    verbose_flag = False
    if verbose == "Y":
        verbose_flag = True


    data_dir = Path("src/data/pictures")
    output_csv = Path(f"output/statistics/{method}_measurement_results.csv")

    if not data_dir.exists():
        print("Data directory does not exist.")
        return

    ply_files = sorted(
        data_dir.glob("*.ply"),
        key=lambda x: int(x.stem)
    )

    if not ply_files:
        print("No .ply files found.")
        return

    results = []

    for file in ply_files:
        print(f"\nProcessing: {file.name}")

        dims = dataclean(
            str(file),
            visualize_flag=visualization_flag,
            method=method,
            verbose=verbose_flag
        )

        results.append([
            file.stem,  # index                
            truncate(dims["height"], 3),
            truncate(dims["width"], 3),
            truncate(dims["length"], 3)
        ])

    # Save to CSV
    with open(output_csv, mode="w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["number", "Height", "Width", "Length"])
        writer.writerows(results)

    print(f"\nSaved results to {output_csv}")

def run_ml_benchmark():
    csv_path = input("Enter the path to your hand-labeled CSV file:\n --> ").strip()

    X, y = load_data_from_csv(csv_path, target_column="is_accurate")
    
    if X is not None and y is not None:
        print("\n" + "="*40)
        print("  STARTING MODEL BENCHMARKS")
        print("="*40)
        
        # Dictionary to keep track of the scores
        scores = {}
        
        # 1. Run Logistic Regression
        _, _, acc_lr = train_logistic_regression(X, y, verbose=False)
        scores["Logistic Regression"] = acc_lr
        
        # 2. Run Decision Tree
        _, _, acc_dt = train_decision_tree(X, y, verbose=False)
        scores["Decision Tree"] = acc_dt
        
        # 3. Run Multilayer Perceptron (Neural Network)
        _, _, acc_mlp = train_mlp(X, y, verbose=False)
        scores["Neural Network (MLP)"] = acc_mlp

        # 4. Run K-Means Clustering
        _, _, acc_kmeans = train_kmeans(X, num_clusters=2, verbose=False)
        scores["K-Means Clustering"] = acc_kmeans
        
        # --- THE RESULTS ---
        print("\n" + "="*40)
        print("  FINAL LEADERBOARD")
        print("="*40)
        
        # Sort the dictionary by highest score
        sorted_scores = sorted(scores.items(), key=lambda item: item[1], reverse=True)
        
        for rank, (model_name, score) in enumerate(sorted_scores, 1):
            print(f"{rank}. {model_name}: {score * 100:.2f}%")


def compare_between_csv(created_csv: Path, reference_csv: Path):
    ACCURACY_THRESHOLD = 0.80
    if not created_csv.exists():
        print(f"Created CSV file {created_csv} does not exist.")
        return

    if not reference_csv.exists():
        print(f"Reference CSV file {reference_csv} does not exist.")
        return

    created_df = pd.read_csv(created_csv)
    reference_df = pd.read_csv(reference_csv)

    created_df.columns = created_df.columns.str.strip()
    reference_df.columns = reference_df.columns.str.strip()

    merged_df = created_df.merge(reference_df, on="number", suffixes=("_created", "_ref"))

    dims = ['Height', 'Width', 'Length']
    accurate_flags = []

    for _, row in merged_df.iterrows():
        all_accurate = True
        for dim in dims:
            created_value = row[f"{dim}_created"]
            reference_value = row[f"{dim}_ref"]
            
            if reference_value == 0:
                all_accurate = False
                break

            ratio = min(created_value, reference_value) / max(created_value, reference_value)
            if ratio < ACCURACY_THRESHOLD:
                all_accurate = False
                break

        accurate_flags.append(1 if all_accurate else 0)

    merged_df["is_accurate"] = accurate_flags

    output_cols = ["number", "Height_created", "Width_created", "Length_created", "Height_ref", "Width_ref", "Length_ref", "is_accurate"]
    result_df = merged_df[output_cols].rename(columns={
        "Height_created": "Height",
        "Width_created": "Width",
        "Length_created": "Length"
    })
    result_df.to_csv(created_csv, index=False)

if __name__ == "__main__":
    main()