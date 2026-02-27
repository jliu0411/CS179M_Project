import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.tree import DecisionTreeClassifier
from sklearn.cluster import KMeans
from sklearn.neural_network import MLPClassifier
from sklearn.metrics import silhouette_score
from sklearn.metrics import accuracy_score, classification_report

def load_data_from_csv(csv_path, target_column):
    df = pd.read_csv(csv_path)
    print(f"Loaded data with columns: {list(df.columns)}")

    # Ensure the target column exists
    if target_column not in df.columns:
        raise ValueError(f"Target column '{target_column}' not found in the CSV.")
        
    # Separate features (X) and the label we want to predict (y)
    X = df[['Height', 'Length', 'Width']]

    y = df[target_column]

    return X, y


def train_logistic_regression(X, y, verbose=True):
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    model = LogisticRegression()
    model.fit(X_train_scaled, y_train)
    
    y_pred = model.predict(X_test_scaled)
    accuracy = accuracy_score(y_test, y_pred)

    print("Classification Report:")
    print(classification_report(y_test, y_pred))

    if verbose:
        print("\n--- Logistic Regression ---")
        print(f"Accuracy: {accuracy * 100:.2f}%")
        print("Classification Report:")
        print(classification_report(y_test, y_pred))

    return model, scaler, accuracy

def train_decision_tree(X, y, verbose=True):

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    model = DecisionTreeClassifier(random_state=42)
    model.fit(X_train_scaled, y_train)

    y_pred = model.predict(X_test_scaled)
    accuracy = accuracy_score(y_test, y_pred)

    if verbose:
        print("\n--- Decision Tree ---")
        print(f"Accuracy: {accuracy * 100:.2f}%")
        print("Classification Report:")
        print(classification_report(y_test, y_pred))
    
    return model, scaler, accuracy

def train_kmeans(X, num_clusters=2, verbose=True):

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    model = KMeans(n_clusters=num_clusters, random_state=42)
    model.fit(X_scaled)

    assigned_clusters = model.labels_
    sil_score = silhouette_score(X_scaled, assigned_clusters)

    if verbose:
        print(f"\n--- K-Means Clustering ({num_clusters} Clusters) ---")
        print(f"Silhouette Score: {sil_score:.4f} (Ranges from -1 to 1)")
        print("(Note: Unsupervised models do not use Accuracy or Classification Reports)")

    return model, scaler, assigned_clusters, sil_score

def train_mlp(X, y, verbose=True):
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    model = MLPClassifier(hidden_layer_sizes=(64, 32), max_iter=1000, random_state=42)
    model.fit(X_train_scaled, y_train)

    y_pred = model.predict(X_test_scaled)
    accuracy = accuracy_score(y_test, y_pred)

    print("Classification Report:")
    print(classification_report(y_test, y_pred))

    if verbose:
        print("\n--- MLP Neural Network ---")
        print(f"Accuracy: {accuracy * 100:.2f}%")
        print("Classification Report:")
        print(classification_report(y_test, y_pred))
    
    return model, scaler, accuracy