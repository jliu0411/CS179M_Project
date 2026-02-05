from src.logic.dataclean import dataclean

def main():
    dataclean("src/data/0000006.ply", False)
    dataclean("src/data/0000002.ply", False)

if __name__ == "__main__":
    main()
