import csv
from pathlib import Path
from src.logic.dataclean import dataclean

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


if __name__ == "__main__":
    main()