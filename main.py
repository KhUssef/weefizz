# main.py

from fastapi import FastAPI, UploadFile, File
from fastapi.responses import JSONResponse, Response
from typing import List
from PIL import Image
import io
import numpy as np

# from textile_identification.densenet import predict_image_grid
from gabarit_detection.opencv import process_image  # Import our gabarit detection model

app = FastAPI()


# def preprocess_image(image_bytes: bytes) -> np.ndarray:
#     """
#     Converts uploaded image bytes into preprocessed NumPy array.
#     """
#     image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
#     image = image.resize((224, 224))  # Adjust size to your model input
#     image_array = np.array(image) / 255.0  # Normalize
#     return image_array


# @app.post("/predict")
# async def predict(files: List[UploadFile] = File(...)):
#     results = []

#     for file in files:
#         contents = await file.read()
#         image = Image.open(io.BytesIO(contents)).convert("RGB")
#         prediction = predict_image_grid(image)
#         results.append({
#             "filename": file.filename,
#             "predictions": prediction["top_5_predictions"]
#         })

#     return JSONResponse(content={"results": results})


@app.post("/process-gabarit")
async def process_gabarit(file: UploadFile = File(...)):
    """
    Processes an image to detect gabarit parts and return the cleaned final image.
    """
    image_bytes = await file.read()
    try:
        result_bytes = process_image(image_bytes)
        return Response(content=result_bytes, media_type="image/png")
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=400)
