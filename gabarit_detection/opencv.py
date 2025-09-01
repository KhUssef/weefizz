#!/usr/bin/env python3
"""
Detect outer garment pattern piece contours in a sewing pattern image and
produce bounding boxes, cropped masks, and an overlay visualization.

Approach
- Load as grayscale and color.
- Denoise slightly and enhance edges.
- Adaptive threshold to binary (works on dark lines on light or vice versa).
- Morphological closing to connect contour gaps.
- Remove thin internal graphics like grainline arrows by eliminating long thin components and by contour filtering on solidity.
- Keep only external contours via hierarchy (no parents) and size/area filters.
- Output: boxes.json, overlay.png, and per-piece crop masks.

Usage:
  python detect_pattern_bounds.py --image image.png

Optional flags:
  --min-area 4000           Minimum contour area to keep (pixels)
  --debug                   Save intermediate images
  --invert                  Force invert binary (if pieces are light on dark)
  --blur 3                  Gaussian blur kernel size (odd)
  --closing 7               Morph closing kernel size
"""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass, asdict
from typing import List, Tuple

import cv2
import numpy as np


@dataclass
class Box:
    x: int
    y: int
    w: int
    h: int
    area: int
    index: int = 0  # 1-based piece number for labeling
    width: int = 0  # explicit duplicate of w for clarity in JSON
    height: int = 0 # explicit duplicate of h for clarity in JSON
    perimeter: List[Tuple[int, int]] = None  # List of (x, y) coordinates for the perimeter pixels


def _adaptive_binarize(gray: np.ndarray, force_invert: bool = False) -> np.ndarray:
    # Normalize and blur to suppress noise
    blur = cv2.GaussianBlur(gray, (3, 3), 0)
    # Adaptive threshold handles uneven illumination
    th = cv2.adaptiveThreshold(
        blur,
        255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY_INV if not force_invert else cv2.THRESH_BINARY,
        35,
        8,
    )
    return th


def _morph_connect(bin_img: np.ndarray, closing_size: int) -> np.ndarray:
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (closing_size, closing_size))
    closed = cv2.morphologyEx(bin_img, cv2.MORPH_CLOSE, kernel, iterations=1)
    # Remove very small specks
    kernel_open = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
    opened = cv2.morphologyEx(closed, cv2.MORPH_OPEN, kernel_open, iterations=1)
    return opened


def _remove_thin_arrows(bin_img: np.ndarray) -> np.ndarray:
    """Remove long thin elements (e.g., arrows) using morphological thinning criteria.

    Strategy:
    - Erode with a 1x7 and 7x1 kernel and reconstruct via hit-miss to suppress
      stroke-like elements.
    - Filter connected components by aspect ratio and solidity.
    """
    img = bin_img.copy()

    # Component analysis to drop thin elongated components
    num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(img, 8)
    kept = np.zeros_like(img)

    for i in range(1, num_labels):  # skip background
        x, y, w, h, area = stats[i]
        if area < 150:  # noise
            continue
        aspect = max(w, h) / (min(w, h) + 1e-5)
        # Very elongated thin shapes (arrows/lines) likely have high aspect and small thickness
        if aspect > 10 and area < 0.02 * img.size:
            continue  # drop
        component_mask = (labels == i).astype(np.uint8) * 255
        # Compute solidity: area / convex hull area
        contours, _ = cv2.findContours(component_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if not contours:
            continue
        cnt = contours[0]
        hull = cv2.convexHull(cnt)
        hull_area = cv2.contourArea(hull)
        contour_area = cv2.contourArea(cnt)
        solidity = contour_area / (hull_area + 1e-5)
        if aspect > 6 and solidity < 0.6:
            # thin with cutouts -> likely arrow shaft + head
            continue
        kept[labels == i] = 255

    return kept


def detect_external_boxes(
    image_path: str,
    min_area: int = 4000,
    closing: int = 7,
    debug: bool = False,
    force_invert: bool = False,
):
    color = cv2.imread(image_path, cv2.IMREAD_COLOR)
    if color is None:
        raise FileNotFoundError(f"Cannot read image: {image_path}")
    gray = cv2.cvtColor(color, cv2.COLOR_BGR2GRAY)

    bin_img = _adaptive_binarize(gray, force_invert)
    connected = _morph_connect(bin_img, closing)
    cleaned = _remove_thin_arrows(connected)

    # Find external contours with hierarchy and filter by area
    contours, hierarchy = cv2.findContours(cleaned, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE)

    boxes: List[Box] = []
    external_indices: List[int] = []
    if hierarchy is not None:
        hierarchy = hierarchy[0]
        for i, h in enumerate(hierarchy):
            parent = h[3]
            if parent == -1:  # external
                area = int(cv2.contourArea(contours[i]))
                if area >= min_area:
                    external_indices.append(i)

    # Fallback if hierarchy is missing
    if not external_indices:
        for i, cnt in enumerate(contours):
            area = int(cv2.contourArea(cnt))
            if area >= min_area:
                external_indices.append(i)

    overlay = color.copy()
    vis = color.copy()
    tmp: List[Tuple[int, np.ndarray, Tuple[int, int, int, int], int]] = []
    for idx in external_indices:
        cnt = contours[idx]
        x, y, w, h = cv2.boundingRect(cnt)
        area = int(cv2.contourArea(cnt))
        tmp.append((idx, cnt, (x, y, w, h), area))

    # Sort pieces top-to-bottom, then left-to-right for stable numbering
    tmp.sort(key=lambda t: (t[2][1], t[2][0]))

    for i, (_, cnt, (x, y, w, h), area) in enumerate(tmp, start=1):
        perimeter = [(int(p[0][0]), int(p[0][1])) for p in cnt]
        box = Box(x=x, y=y, w=w, h=h, area=area, index=i, width=w, height=h, perimeter=perimeter)
        boxes.append(box)
        # Green contour
        cv2.drawContours(overlay, [cnt], -1, (0, 255, 0), 2)
        # Red bounding rectangle
        cv2.rectangle(overlay, (x, y), (x + w, y + h), (0, 0, 255), 2)
        # Number label near top-left corner of the box with slight padding
        label = str(i)
        org = (x + 10, max(0, y - 10))
        # Draw a contrasting background for legibility
        cv2.putText(overlay, label, org, cv2.FONT_HERSHEY_SIMPLEX, 1.1, (0, 0, 0), 4, cv2.LINE_AA)
        cv2.putText(overlay, label, org, cv2.FONT_HERSHEY_SIMPLEX, 1.1, (255, 255, 255), 2, cv2.LINE_AA)

    return boxes, overlay, cleaned


def save_results(
    image_path: str,
    boxes: List[Box],
    overlay: np.ndarray,
    cleaned: np.ndarray,
    out_dir: str,
    debug: bool,
):
    os.makedirs(out_dir, exist_ok=True)
    base = os.path.splitext(os.path.basename(image_path))[0]

    # Overlay
    overlay_path = os.path.join(out_dir, f"{base}_overlay.png")
    cv2.imwrite(overlay_path, overlay)

    # Boxes JSON
    boxes_path = os.path.join(out_dir, f"{base}_boxes.json")
    with open(boxes_path, "w", encoding="utf-8") as f:
        json.dump([asdict(b) for b in boxes], f, indent=2)

    # Debug cleaned mask
    if debug:
        cleaned_path = os.path.join(out_dir, f"{base}_cleaned.png")
        cv2.imwrite(cleaned_path, cleaned)

    # Save individual crops
    color = cv2.imread(image_path, cv2.IMREAD_COLOR)
    for i, b in enumerate(boxes):
        crop = color[b.y : b.y + b.h, b.x : b.x + b.w]
        cv2.imwrite(os.path.join(out_dir, f"{base}_piece_{i+1}.png"), crop)

    return overlay_path, boxes_path


def main():
    parser = argparse.ArgumentParser(description="Detect pattern piece bounds")
    parser.add_argument("--image", required=True, help="Path to input image")
    parser.add_argument("--min-area", type=int, default=4000)
    parser.add_argument("--closing", type=int, default=7)
    parser.add_argument("--invert", action="store_true")
    parser.add_argument("--debug", action="store_true")
    parser.add_argument("--out", default="outputs")
    args = parser.parse_args()

    boxes, overlay, cleaned = detect_external_boxes(
        args.image, min_area=args.min_area, closing=args.closing, debug=args.debug, force_invert=args.invert
    )

    overlay_path, boxes_path = save_results(
        args.image, boxes, overlay, cleaned, out_dir=args.out, debug=args.debug
    )

    print(f"Saved overlay to: {overlay_path}")
    print(f"Saved boxes to:   {boxes_path}")
    print("Detected boxes:")
    for i, b in enumerate(boxes, 1):
        print(f"  {i}: x={b.x} y={b.y} w={b.w} h={b.h} area={b.area}")


if __name__ == "__main__":
    main()


