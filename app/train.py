"""Train the iris classifier and write it next to its metadata.

Runs at image build time, so the model is part of the image and its digest.
"""

import hashlib
import json
import sys
from pathlib import Path

import joblib
import sklearn
from sklearn.datasets import load_iris
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split

MIN_ACCURACY = 0.9


def train(out_dir: Path) -> dict:
    x, y = load_iris(return_X_y=True)
    x_train, x_test, y_train, y_test = train_test_split(x, y, test_size=0.2, random_state=42)
    model = LogisticRegression(max_iter=500).fit(x_train, y_train)
    accuracy = float(model.score(x_test, y_test))
    if accuracy < MIN_ACCURACY:
        raise SystemExit(f"accuracy {accuracy:.3f} below {MIN_ACCURACY}, refusing to ship")

    out_dir.mkdir(parents=True, exist_ok=True)
    model_path = out_dir / "model.joblib"
    joblib.dump(model, model_path)
    metadata = {
        "sha256": hashlib.sha256(model_path.read_bytes()).hexdigest(),
        "accuracy": round(accuracy, 4),
        "sklearn": sklearn.__version__,
        "classes": load_iris().target_names.tolist(),
    }
    (out_dir / "metadata.json").write_text(json.dumps(metadata, indent=2))
    return metadata


if __name__ == "__main__":
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("model")
    print(json.dumps(train(out)))
