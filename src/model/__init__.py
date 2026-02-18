from __future__ import annotations
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Tuple

import numpy as np

#TODO: fully implement this later once yk how dataset is exactly formatted 
#load the data 
def load_dataset_csv(csv_path: str) -> Tuple[np.ndarray, np.ndarray]:
    """
    Expected CSV shape (example):
        feature_1, feature_2, ... feature_D, gt_w, gt_l, gt_h

    Returns:
        X: (N, D)
        Y: (N, 3)  where columns are [gt_w, gt_l, gt_h]
    """
    # Skeleton: adapt parsing to your real schema.
    data = np.genfromtxt(csv_path, delimiter=",", skip_header=1)
    X = data[:, :-3]
    Y = data[:, -3:]
    return X, Y


def train_val_test_split(
    X: np.ndarray,
    Y: np.ndarray,
    val_ratio: float = 0.15,
    test_ratio: float = 0.15,
    seed: int = 42,
) -> Dict[str, Tuple[np.ndarray, np.ndarray]]:
    assert X.shape[0] == Y.shape[0]
    N = X.shape[0]
    rng = np.random.default_rng(seed)
    idx = np.arange(N)
    rng.shuffle(idx)

    n_test = int(N * test_ratio)
    n_val = int(N * val_ratio)

    test_idx = idx[:n_test]
    val_idx = idx[n_test : n_test + n_val]
    train_idx = idx[n_test + n_val :]

    return {
        "train": (X[train_idx], Y[train_idx]),
        "val": (X[val_idx], Y[val_idx]),
        "test": (X[test_idx], Y[test_idx]),
    }


#linear regression (GD) learned gd in 171
@dataclass
class LinearRegressionGD:
    lr: float = 1e-2
    max_iter: int = 5000
    tol: float = 1e-8
    w_: np.ndarray | None = None  # (D,)
    b_: float = 0.0

    def fit(self, X: np.ndarray, y: np.ndarray) -> "LinearRegressionGD":
        """
        X: (N, D)
        y: (N,)
        """
        N, D = X.shape
        self.w_ = np.zeros(D, dtype=float)
        self.b_ = 0.0

        prev_loss = None
        for it in range(self.max_iter):
            yhat = X @ self.w_ + self.b_
            err = yhat - y

            loss = (err @ err) / (2.0 * N)  # MSE/2
            if prev_loss is not None and abs(prev_loss - loss) < self.tol:
                break
            prev_loss = loss

            # Gradients
            grad_w = (X.T @ err) / N
            grad_b = err.mean()

            # Update
            self.w_ -= self.lr * grad_w
            self.b_ -= self.lr * grad_b

        return self

    def predict(self, X: np.ndarray) -> np.ndarray:
        assert self.w_ is not None
        return X @ self.w_ + self.b_






