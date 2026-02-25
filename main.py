import importlib.util
from pathlib import Path

from src.logic.dataclean import dataclean


def _run_cli():
    method = input("Choose the Method: (AABB / OBB / PCA)\n   -->  ")
    dataclean("src/data/sample2.ply", True, method, verbose=True)


def _load_appwrite_main():
    handler_path = (
        Path(__file__).resolve().parent
        / "appwrite_functions"
        / "process-ply"
        / "src"
        / "main.py"
    )

    spec = importlib.util.spec_from_file_location("process_ply_function", handler_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.main


def main(context=None):
    if context is None:
        return _run_cli()

    appwrite_main = _load_appwrite_main()
    return appwrite_main(context)


if __name__ == "__main__":
    main()
