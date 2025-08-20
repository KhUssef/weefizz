# model.py
import cv2
import numpy as np
import pytesseract
from typing import Dict, Any

pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'

def is_contour_really_closed(cnt, threshold=15):
    return cv2.norm(cnt[0][0], cnt[-1][0]) < threshold

def detect_and_close_edges(gray):
    edges = cv2.Canny(gray, 50, 150)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (7, 7))
    closed_edges = cv2.morphologyEx(edges, cv2.MORPH_CLOSE, kernel, iterations=2)
    return closed_edges

def is_shape_solid(cnt):
    area = cv2.contourArea(cnt)
    hull = cv2.convexHull(cnt)
    hull_area = cv2.contourArea(hull)
    if hull_area == 0:
        return False
    solidity = float(area) / hull_area
    return solidity > 0.8


def detect_closed_shapes(closed_edges, image, gray):
    # Fix for different OpenCV versions
    contours_result = cv2.findContours(closed_edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    if len(contours_result) == 3:
        _, contours, _ = contours_result
    else:
        contours, _ = contours_result
    
    kept_contours = []
    gabarit_pieces = []
    
    piece_id = 1
    for cnt in contours:
        if cv2.contourArea(cnt) < 1000:
            continue
        if not is_contour_really_closed(cnt, threshold=10):
            continue
        if not is_shape_solid(cnt):
            continue
        
        kept_contours.append(cnt)
        piece_info = extract_gabarit_piece_info(cnt, piece_id)
        gabarit_pieces.append(piece_info)
        piece_id += 1
    
    outline_image = image.copy()
    cv2.drawContours(outline_image, kept_contours, -1, (0, 255, 0), 2)
    
    # Add piece IDs as labels on the image
    for piece in gabarit_pieces:
        cx, cy = piece["centroid"]["x"], piece["centroid"]["y"]
        cv2.putText(outline_image, f"P{piece['piece_id']}", (cx-15, cy), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 0, 0), 2)
    
    return kept_contours, outline_image, gabarit_pieces

def find_strict_small_convoluted_candidates(gray, img_shape):
    img_h, img_w = img_shape[:2]
    thresh = cv2.threshold(gray, 180, 255, cv2.THRESH_BINARY_INV)[1]
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
    dilated = cv2.dilate(thresh, kernel, iterations=1)
    
    # Fix for different OpenCV versions
    contours_result = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if len(contours_result) == 3:
        _, contours, _ = contours_result
    else:
        contours, _ = contours_result
    
    candidate_boxes = []
    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        area = cv2.contourArea(cnt)
        peri = cv2.arcLength(cnt, True)
        if 20 < area < 8000:
            w_ratio = w / img_w
            h_ratio = h / img_h
            if w_ratio < 0.20 and h_ratio < 0.20:
                if peri / (area + 1) > 0.05:
                    candidate_boxes.append((x, y, w, h))
    return candidate_boxes

def extract_gabarit_piece_info(cnt, piece_id: int) -> Dict[str, Any]:
    """Extract detailed information about a gabarit piece contour"""
    # Basic properties
    area = cv2.contourArea(cnt)
    perimeter = cv2.arcLength(cnt, True)
    
    # Bounding rectangle
    x, y, w, h = cv2.boundingRect(cnt)
    
    # Centroid
    M = cv2.moments(cnt)
    if M["m00"] != 0:
        cx = int(M["m10"] / M["m00"])
        cy = int(M["m01"] / M["m00"])
    else:
        cx, cy = x + w//2, y + h//2
    
    # Convex hull and solidity
    hull = cv2.convexHull(cnt)
    hull_area = cv2.contourArea(hull)
    solidity = float(area) / hull_area if hull_area > 0 else 0
    
    # Aspect ratio
    aspect_ratio = float(w) / h if h > 0 else 0
    
    # Approximate polygon
    epsilon = 0.02 * perimeter
    approx = cv2.approxPolyDP(cnt, epsilon, True)
    
    # Convert contour points to list for JSON serialization
    contour_points = cnt.reshape(-1, 2).tolist()
    hull_points = hull.reshape(-1, 2).tolist()
    approx_points = approx.reshape(-1, 2).tolist()
    
    return {
        "piece_id": piece_id,
        "area": float(area),
        "perimeter": float(perimeter),
        "bounding_box": {
            "x": int(x),
            "y": int(y),
            "width": int(w),
            "height": int(h)
        },
        "centroid": {
            "x": int(cx),
            "y": int(cy)
        },
        "solidity": float(solidity),
        "aspect_ratio": float(aspect_ratio),
        "vertices_count": len(approx_points),
        "contour_points": contour_points,
        "hull_points": hull_points,
        "approximate_polygon": approx_points
    }
def validate_text_regions(gray, candidate_boxes):
    valid_texts = []
    img_h, img_w = gray.shape
    for (x, y, w, h) in candidate_boxes:
        pad = 5
        x1 = max(0, x - pad)
        y1 = max(0, y - pad)
        x2 = min(img_w, x + w + pad)
        y2 = min(img_h, y + h + pad)
        roi = gray[y1:y2, x1:x2]
        config = '--oem 3 --psm 6 outputbase digits'
        text = pytesseract.image_to_string(roi, config=config).strip()
        if len(text) > 0 and any(c.isdigit() for c in text):
            valid_texts.append((x1, y1, x2 - x1, y2 - y1, text))
    return valid_texts

def create_mask(img_shape, text_boxes):
    mask = np.zeros(img_shape[:2], dtype=np.uint8)
    for (x, y, w, h, _) in text_boxes:
        cv2.rectangle(mask, (x, y), (x+w, y+h), 255, -1)
    return mask

def find_strict_small_convoluted_candidates(gray, img_shape):
    img_h, img_w = img_shape[:2]
    thresh = cv2.threshold(gray, 180, 255, cv2.THRESH_BINARY_INV)[1]
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
    dilated = cv2.dilate(thresh, kernel, iterations=1)
    contours, _ = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    candidate_boxes = []
    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        area = cv2.contourArea(cnt)
        peri = cv2.arcLength(cnt, True)
        if 20 < area < 8000:
            w_ratio = w / img_w
            h_ratio = h / img_h
            if w_ratio < 0.20 and h_ratio < 0.20:
                if peri / (area + 1) > 0.05:
                    candidate_boxes.append((x, y, w, h))
    return candidate_boxes

def remove_elements(image, mask):
    result = image.copy()
    green_color = (0, 128, 0)
    result[mask == 255] = green_color
    return result

def process_image_with_gabarit_info(image_bytes):
    """Process image and return both the final image and gabarit piece information"""
    # Convert bytes to OpenCV image
    nparr = np.frombuffer(image_bytes, np.uint8)
    image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("Invalid image data.")

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    closed_edges = detect_and_close_edges(gray)
    kept_contours, outline_image, gabarit_pieces = detect_closed_shapes(closed_edges, image, gray)
    candidate_boxes = find_strict_small_convoluted_candidates(gray, image.shape)
    text_boxes = validate_text_regions(gray, candidate_boxes)
    mask = create_mask(image.shape, text_boxes)
    final_image = remove_elements(outline_image, mask)

    # Encode result to bytes
    _, img_encoded = cv2.imencode('.png', final_image)
    return {
        "image_bytes": img_encoded.tobytes(),
        "gabarit_pieces": gabarit_pieces,
        "total_pieces": len(gabarit_pieces),
        "image_dimensions": {"width": image.shape[1], "height": image.shape[0]}
    }

def process_image(image_bytes):
    """Original function - returns only the processed image bytes"""
    result = process_image_with_gabarit_info(image_bytes)
    return result["image_bytes"]