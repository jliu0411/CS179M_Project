import csv
import pandas as pd
from pathlib import Path
from src.logic.dataclean import dataclean
from src.model.mlmodel import load_data_from_csv, train_logistic_regression, train_decision_tree, train_mlp

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
    output_csv.parent.mkdir(parents=True, exist_ok=True)
    with open(output_csv, mode="w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["number", "Height", "Width", "Length"])
        writer.writerows(results)

    print(f"\nSaved results to {output_csv}")

    run_comparison = input("Would you like to compare against a reference CSV? (Y/N)\n   -->  ").strip().upper()
    if run_comparison == "Y":
        reference_csv = Path(r"Measurements_clean - Sheet1.csv")
        compare_between_csv(output_csv, reference_csv)
        print(f"Comparison complete. Results saved to {output_csv}")

def run_ml_benchmark():
    csv_path = Path(r"output\statistics\AABB_measurement_results.csv")

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
        
        # --- THE RESULTS ---
        print("\n" + "="*40)
        print("  FINAL LEADERBOARD")
        print("="*40)
        
        # Sort the dictionary by highest score
        sorted_scores = sorted(scores.items(), key=lambda item: item[1], reverse=True)
        
        for rank, (model_name, score) in enumerate(sorted_scores, 1):
            print(f"{rank}. {model_name}: {score * 100:.2f}%")


def compare_between_csv(created_csv: Path, reference_csv: Path):
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
    confidence_scores = []

    for _, row in merged_df.iterrows():
        ratios = []
        for dim in dims:
            created_value = row[f"{dim}_created"] * 100
            reference_value = row[f"{dim}_ref"]
            
            if reference_value == 0:
                ratios.append(0)
                continue

            ratio = min(created_value, reference_value) / max(created_value, reference_value)
            ratios.append(ratio)

        confidence = sum(ratios) / len(ratios)
        confidence_scores.append(round(confidence * 100, 2))

    merged_df["confidence"] = confidence_scores

    print(f"\nAverage Confidence: {sum(confidence_scores) / len(confidence_scores):.2f}%")
    print(f"Best:  {max(confidence_scores):.2f}% (object {merged_df.loc[merged_df['confidence'].idxmax(), 'number']})")
    print(f"Worst: {min(confidence_scores):.2f}% (object {merged_df.loc[merged_df['confidence'].idxmin(), 'number']})")

    for dim in dims:
        dim_ratios = []
        for _, row in merged_df.iterrows():
            created = row[f"{dim}_created"] * 100
            ref = row[f"{dim}_ref"]
            if ref != 0:
                dim_ratios.append(min(created, ref) / max(created, ref))
        print(f"{dim} avg confidence: {sum(dim_ratios)/len(dim_ratios)*100:.2f}%")

    output_cols = ["number", "Height_created", "Width_created", "Length_created", "Height_ref", "Width_ref", "Length_ref", "confidence"]
    result_df = merged_df[output_cols].rename(columns={
        "Height_created": "Height",
        "Width_created": "Width",
        "Length_created": "Length"
    })
    result_df.to_csv(created_csv, index=False)

if __name__ == "__main__":
    main()