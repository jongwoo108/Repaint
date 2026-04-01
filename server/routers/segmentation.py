import io
from fastapi import APIRouter, UploadFile, File, HTTPException
from PIL import Image
from services.segment_service import run_segmentation
from models.schemas import SegmentationResponse

router = APIRouter(prefix="/segment", tags=["segmentation"])


@router.post("", response_model=SegmentationResponse)
async def segment_image(image: UploadFile = File(...)):
    if not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Image file required")
    data = await image.read()
    try:
        pil_image = Image.open(io.BytesIO(data))
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image file")
    return run_segmentation(pil_image)
