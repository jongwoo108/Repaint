import base64
import io
import numpy as np
from PIL import Image
from models.segmentation import load_model, ID_TO_LABEL
from models.schemas import RegionResult, BoundingBox, SegmentationResponse

_model = None


def get_model():
    global _model
    if _model is None:
        _model = load_model()
    return _model


def _mask_to_base64(mask: np.ndarray) -> str:
    img = Image.fromarray((mask * 255).astype(np.uint8), mode="L")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode()


def _bbox_from_mask(mask: np.ndarray, orig_w: int, orig_h: int) -> BoundingBox:
    rows = np.any(mask, axis=1)
    cols = np.any(mask, axis=0)
    rmin, rmax = np.where(rows)[0][[0, -1]]
    cmin, cmax = np.where(cols)[0][[0, -1]]
    scale_x = orig_w / mask.shape[1]
    scale_y = orig_h / mask.shape[0]
    return BoundingBox(
        x=float(cmin * scale_x),
        y=float(rmin * scale_y),
        width=float((cmax - cmin) * scale_x),
        height=float((rmax - rmin) * scale_y),
    )


def run_segmentation(image: Image.Image) -> SegmentationResponse:
    model = get_model()
    orig_w, orig_h = image.size
    seg_map = model.predict(image)  # (513, 513), class IDs 0-5

    regions: list[RegionResult] = []
    total_pixels = seg_map.size

    for class_id in range(1, 6):  # 0=background 제외
        binary_mask = (seg_map == class_id)
        if binary_mask.sum() < 100:  # 너무 작은 영역 무시
            continue
        label = ID_TO_LABEL[class_id]
        bbox = _bbox_from_mask(binary_mask, orig_w, orig_h)
        regions.append(RegionResult(
            id=f"{label}_{class_id}",
            label=label,
            mask_base64=_mask_to_base64(binary_mask),
            bbox=bbox,
            area_ratio=float(binary_mask.sum()) / total_pixels,
        ))

    return SegmentationResponse(regions=regions, image_width=orig_w, image_height=orig_h)
