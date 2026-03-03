from src.logic.dataclean import dataclean

def main():
    method = input("Choose the Method: (AABB / OBB / HULL)\n   -->  ")
    dataclean("src/data/8.ply", True, method, verbose=False)
    # dataclean("src/data/9.ply", True, method, verbose=True)
    # dataclean("src/data/sample2.ply", True, method, verbose=True)

if __name__ == "__main__":
    main()