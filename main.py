# main.py

from fastapi import FastAPI, UploadFile, File
from fastapi.responses import JSONResponse, Response
from typing import List
from PIL import Image
import io
import numpy as np
import base64
import tempfile
import os
import cv2
from gabarit_detection.opencv import detect_external_boxes, Box  # Import the existing function and Box class
from dataclasses import asdict  # Import asdict to convert Box instances to dictionaries

# from textile_identification.densenet import predict_image_grid
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



@app.post("/gabarit-full")
async def gabarit_full(file: UploadFile = File(...)):
    """
    Processes an image and returns both the segmented image (base64) and gabarit piece information.
    """
    image_bytes = await file.read()
    
    # Create a temporary file for the image
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as temp_file:
        temp_file.write(image_bytes)
        temp_path = temp_file.name
    
    try:
        # Call the existing detect_external_boxes function
        boxes, overlay, cleaned = detect_external_boxes(
            temp_path, min_area=4000, closing=7, debug=False, force_invert=False
        )
        
        # Convert overlay to base64
        success, encoded_img = cv2.imencode('.png', overlay)
        if success:
            image_b64 = base64.b64encode(encoded_img.tobytes()).decode()
        else:
            return JSONResponse(content={"error": "Failed to encode image"}, status_code=400)
        
        # Format boxes as gabarit_pieces
        gabarit_pieces = [asdict(box) for box in boxes]
        
        # Get image dimensions from overlay
        height, width = overlay.shape[:2]
        image_dimensions = {"width": width, "height": height}
        
        return JSONResponse(content={
            "message": "Gabarit segmentation and analysis successful",
            "processed_image": f"data:image/png;base64,{image_b64}",
            "gabarit_pieces": gabarit_pieces,
            "total_pieces": len(gabarit_pieces),
            "image_dimensions": image_dimensions,
            "file_info": {
                "filename": file.filename,
                "content_type": file.content_type,
                "size_bytes": len(image_bytes)
            },
            "processing_info": {
                "function_used": "detect_external_boxes",
                "output_format": "segmented_image_with_pieces_info"
            }
        })
        
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=400)
    finally:
        # Clean up temp file
        if os.path.exists(temp_path):
            os.remove(temp_path)


@app.post("/gabarit-image")
async def gabarit_image(file: UploadFile = File(...)):
    """
    Processes an image and returns the segmented overlay image directly as PNG.
    """
    image_bytes = await file.read()
    
    # Create a temporary file for the image
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as temp_file:
        temp_file.write(image_bytes)
        temp_path = temp_file.name
    
    try:
        # Call the existing detect_external_boxes function
        boxes, overlay, cleaned = detect_external_boxes(
            temp_path, min_area=4000, closing=7, debug=False, force_invert=False
        )
        
        # Encode overlay to PNG bytes
        success, encoded_img = cv2.imencode('.png', overlay)
        if success:
            return Response(content=encoded_img.tobytes(), media_type="image/png")
        else:
            return JSONResponse(content={"error": "Failed to encode image"}, status_code=400)
        
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=400)
    finally:
        # Clean up temp file
        if os.path.exists(temp_path):
            os.remove(temp_path)
