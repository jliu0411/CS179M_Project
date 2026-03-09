import csv
import pandas as pd
from pathlib import Path
from src.logic.dataclean import dataclean
from src.model.mlmodel import load_data_from_csv, train_logistic_regression, train_decision_tree, train_mlp
import joblib

VALID_METHODS = ("AABB", "OBB", "HULL", "PCA", "HULL_PCA")

def truncate(f, n):
    """Truncates a float f to n decimal places without rounding"""
    factor = 10**n
    return int(f * factor) / factor

def ask_yes_no(prompt):
    #Prompt user for Y/N returns a bool 
    while True:
        answer = input(prompt).strip().upper()
        if answer in {"Y", "N"}:
            return answer == "Y"
        print("Invalid input. Please enter Y or N")

def ask_method():
    #prompt user for which dimension extraction method 
    options = " / ".join(VALID_METHODS)
    while True:
        method = input(f"Choose the Method: ({options})\n  -->  ").strip().upper()
        if method in VALID_METHODS:
            return method
        print(f"Invalid Method. Please choose one of {options}")


def main():

    # Choose method
    method = ask_method()
    visualization_flag = ask_yes_no("Would you like to visualize each result? (Y/N)\n   -->  ")
    verbose_flag = ask_yes_no("Would you like to execute with verbose mode? (Y/N)\n   -->  ")

    data_dir = Path("src/data/pictures")
    output_csv = Path(f"output/statistics/{method}_measurement_results.csv")

    if not data_dir.exists():
        print("Data directory does not exist.")
        return

    numeric_stem_files = [f for f in data_dir.glob("*.ply") if f.stem.isdigit()]
    non_numeric_stem_files = [f for f in data_dir.glob("*.ply") if not f.stem.isdigit()]

    ply_files = sorted(numeric_stem_files, key=lambda x: int(x.stem)) + sorted(non_numeric_stem_files)

    if not ply_files:
        print("No .ply files found.")
        return

    results = []
    failures = []

    for file in ply_files:
        print(f"\nProcessing: {file.name}")

        try:
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
                truncate(dims["length"], 3),

                dims["point_count"],
                dims["ransac_inlier_ratio"],
                dims["std_x"],
                dims["std_y"],
                dims["std_z"],
                dims["aspect_ratio"]
            ])
        except Exception as exc:  # Keep batch run alive if one file fails.
            print(f"Failed to process {file.name}: {exc}")
            failures.append(file.name)

    output_csv.parent.mkdir(parents=True, exist_ok=True)

    # Save to CSV
    output_csv.parent.mkdir(parents=True, exist_ok=True)
    with open(output_csv, mode="w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["number", "Height", "Width", "Length", "point_count", "ransac_inlier_ratio", "std_x", "std_y", "std_z", "aspect_ratio"])
        writer.writerows(results)

    print(f"\nSaved results to {output_csv}")
    
    if failures:
        print(f"Skipped {len(failures)} files due to processing errors: {', '.join(failures)}")

    run_comparison = input("Would you like to compare against a reference CSV? (Y/N)\n   -->  ").strip().upper()
    if run_comparison == "Y":
        reference_csv = Path(r"Measurements_clean - Sheet1.csv")
        compare_between_csv(output_csv, reference_csv)
        print(f"Comparison complete. Results saved to {output_csv}")

        run_benchmark = input("Would you like to run an ML benchmark on the results? (Y/N)\n   -->  ").strip().upper()
        if run_benchmark == "Y":
            run_ml_benchmark(output_csv)

def run_ml_benchmark(csv_path: Path):
    # csv_path = Path(r"output\statistics\AABB_measurement_results.csv")

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

        best_model_name = sorted_scores[0][0]
        if best_model_name == "Logistic Regression":
            model, _, _ = train_logistic_regression(X, y, verbose=False)
        elif best_model_name == "Decision Tree":
            model, _, _ = train_decision_tree(X, y, verbose=False)
        else:
            model, _, _ = train_mlp(X, y, verbose=False)

        joblib.dump(model, 'output/models/best_model.joblib')
        print(f"Saved best model: {best_model_name}")


def compare_between_csv(created_csv: Path, reference_csv: Path):
    ACCURACY_THRESHOLD = 0.85
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
    accurate_flags = []

    for _, row in merged_df.iterrows():
        ratios = []
        all_accurate = True

        for dim in dims:
            created_value = row[f"{dim}_created"] * 100
            reference_value = row[f"{dim}_ref"]

            if reference_value == 0:
                ratios.append(0)
                all_accurate = False
                continue

            ratio = min(created_value, reference_value) / max(created_value, reference_value)
            ratios.append(ratio)

            if ratio < ACCURACY_THRESHOLD:
                all_accurate = False

        confidence = sum(ratios) / len(ratios)
        confidence_scores.append(round(confidence * 100, 2))
        accurate_flags.append(1 if all_accurate else 0)

    merged_df["confidence"] = confidence_scores
    merged_df["is_accurate"] = accurate_flags

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

    output_cols = ["number", "Height_created", "Width_created", "Length_created", "Height_ref", "Width_ref", "Length_ref", "confidence", "is_accurate", "point_count", "ransac_inlier_ratio", "std_x", "std_y", "std_z", "aspect_ratio"]
    result_df = merged_df[output_cols].rename(columns={
        "Height_created": "Height",
        "Width_created": "Width",
        "Length_created": "Length"
    })
    result_df.to_csv(created_csv, index=False)

if __name__ == "__main__":
    main()