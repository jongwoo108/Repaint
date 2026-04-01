from pydantic import BaseModel
from typing import List, Optional


class BoundingBox(BaseModel):
    x: float
    y: float
    width: float
    height: float


class RegionResult(BaseModel):
    id: str
    label: str  # sky | water | vegetation | flower | ground
    mask_base64: str  # PNG mask encoded as base64
    bbox: BoundingBox
    area_ratio: float  # 전체 이미지 대비 영역 비율


class SegmentationResponse(BaseModel):
    regions: List[RegionResult]
    image_width: int
    image_height: int


class GuideRequest(BaseModel):
    regions: List[RegionResult]
    style_id: str = "monet_water_lilies"


class StrokeGuide(BaseModel):
    direction: str
    pattern: str
    description: str


class BrushPreset(BaseModel):
    type: str
    size_range: dict
    opacity: float


class PaletteColor(BaseModel):
    hex: str
    name: str
    usage: str


class RegionGuide(BaseModel):
    region_id: str
    label: str
    layer: str
    palette: List[PaletteColor]
    brush: BrushPreset
    stroke_guide: StrokeGuide
    tips: List[str]


class PaintingGuide(BaseModel):
    style_id: str
    painting_order: List[str]
    region_guides: List[RegionGuide]
