from src.logic.dataclean import dataclean

def main():
    method = input("Choose the Method: (AABB / OBB / HULL)\n   -->  ")
    dataclean("src/data/pictures/1.ply", True, method, verbose=True)
    # dataclean("src/data/9.ply", True, method, verbose=True)
    # dataclean("src/data/sample2.ply", True, method, verbose=True)

if __name__ == "__main__":
    main()