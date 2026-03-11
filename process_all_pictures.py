import json
from pathlib import Path
from src.logic.dataclean import dataclean

def process_all_pictures():
    """Process all .ply files in src/data/pictures and save dimensions to JSON"""
    
    pictures_dir = Path("src/data/pictures")
    output_json = Path("output/dimensions.json")
    
    # Ensure output directory exists
    output_json.parent.mkdir(parents=True, exist_ok=True)
    
    # Get all .ply files
    ply_files = sorted(pictures_dir.glob("*.ply"))
    
    if not ply_files:
        print("No .ply files found in src/data/pictures")
        return
    
    results = {}
    
    print(f"Processing {len(ply_files)} files...")
    
    for i, ply_file in enumerate(ply_files, 1):
        print(f"\n[{i}/{len(ply_files)}] Processing {ply_file.name}...")
        
        try:
            # Run dataclean without visualization
            dimensions = dataclean(str(ply_file), visualize_flag=False)
            
            # Store results with filename as key
            results[ply_file.name] = dimensions
            
            print(f"  ✓ Width: {dimensions['width']:.3f}, "
                  f"Length: {dimensions['length']:.3f}, "
                  f"Height: {dimensions['height']:.3f}")
            
        except Exception as e:
            print(f"  ✗ Error processing {ply_file.name}: {e}")
            results[ply_file.name] = {"error": str(e)}
    
    # Save to JSON
    with open(output_json, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\n✓ Results saved to {output_json}")
    print(f"  Total files processed: {len(results)}")
    print(f"  Successful: {sum(1 for r in results.values() if 'error' not in r)}")
    print(f"  Failed: {sum(1 for r in results.values() if 'error' in r)}")

if __name__ == "__main__":
    process_all_pictures()
