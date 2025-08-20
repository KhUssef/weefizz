# main.py

from fastapi import FastAPI, UploadFile, File
from fastapi.responses import JSONResponse, Response
from typing import List
from PIL import Image
import io
import numpy as np
import base64

# from textile_identification.densenet import predict_image_grid
from gabarit_detection.opencv import process_image, process_image_with_gabarit_info  # Import our gabarit detection model

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


@app.post("/gabarit-pieces-info")
async def gabarit_pieces_info(file: UploadFile = File(...)):
    """
    Analyzes an image and returns detailed information about each gabarit piece.
    """
    image_bytes = await file.read()
    try:
        result = process_image_with_gabarit_info(image_bytes)
        
        return JSONResponse(content={
            "gabarit_pieces": result["gabarit_pieces"],
            "total_pieces": result["total_pieces"],
            "image_dimensions": result["image_dimensions"]
        })
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=400)


@app.post("/gabarit-full")
async def gabarit_full(file: UploadFile = File(...)):
    """
    Processes an image and returns both the processed image and gabarit piece information.
    """
    image_bytes = await file.read()
    try:
        result = process_image_with_gabarit_info(image_bytes)
        
        # Convert image bytes to base64 for JSON response
        image_b64 = base64.b64encode(result["image_bytes"]).decode()
        
        return JSONResponse(content={
            "processed_image": f"data:image/png;base64,{image_b64}",
            "gabarit_pieces": result["gabarit_pieces"],
            "total_pieces": result["total_pieces"],
            "image_dimensions": result["image_dimensions"]
        })
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=400)


@app.get("/")
async def root():
    """
    API documentation and available endpoints.
    """
    return JSONResponse(content={
        "message": "Gabarit Detection API",
        "endpoints": {
            "/process-gabarit": "POST - Upload image, get processed image (PNG)",
            "/gabarit-pieces-info": "POST - Upload image, get gabarit pieces information (JSON)",
            "/gabarit-full": "POST - Upload image, get both processed image and pieces info (JSON)",
            "/docs": "GET - Interactive API documentation"
        }
    })