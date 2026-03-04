import csv
from pathlib import Path
from src.logic.dataclean import dataclean

VALID_METHODS = {"AABB", "OBB", "HULL", "PCA", "HULL_PCA"}

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
    options = " / ".join(sorted(VALID_METHODS))
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
                truncate(dims["length"], 3)
            ])
        except Exception as exc:  # Keep batch run alive if one file fails.
            print(f"Failed to process {file.name}: {exc}")
            failures.append(file.name)

    output_csv.parent.mkdir(parents=True, exist_ok=True)

    # Save to CSV
    with open(output_csv, mode="w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["number", "Height", "Width", "Length"])
        writer.writerows(results)

    print(f"\nSaved results to {output_csv}")
    if failures:
        print(f"Skipped {len(failures)} files due to processing errors: {', '.join(failures)}")

if __name__ == "__main__":
    main()