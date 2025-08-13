import tensorflow as tf
import numpy as np
import pickle
import os
import joblib
from PIL import Image
from keras.models import load_model
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, 'densenet_classifier.h5')
ENCODER_PATH = os.path.join(BASE_DIR, 'label_encoder.pkl')
# Load trained model (.h5)
model = load_model(MODEL_PATH)
label_encoder = joblib.load(ENCODER_PATH)

def preprocess_patch(patch):
    patch = patch.resize((224, 224))
    arr = np.array(patch) / 255.0
    return np.expand_dims(arr, axis=0)

def predict_image_grid(image: Image.Image):
    width, height = image.size
    patch_w, patch_h = width // 3, height // 3

    # Collect predictions for all 9 patches
    predictions = []
    for i in range(3):
        for j in range(3):
            left = j * patch_w
            upper = i * patch_h
            right = (j + 1) * patch_w
            lower = (i + 1) * patch_h
            patch = image.crop((left, upper, right, lower))
            processed = preprocess_patch(patch)
            pred = model.predict(processed, verbose=0)[0]
            predictions.append(pred)

    # Average all 9 prediction vectors
    avg_prediction = np.mean(predictions, axis=0)
    top_5_indices = avg_prediction.argsort()[-5:][::-1]
    top_5 = [
        {"label": label_encoder.classes_[i], "confidence": float(avg_prediction[i])}
        for i in top_5_indices
    ]

    return {"top_5_predictions": top_5}
