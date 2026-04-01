import json
from pathlib import Path
from models.schemas import (
    RegionResult, PaintingGuide, RegionGuide,
    PaletteColor, BrushPreset, StrokeGuide
)

RECIPES_DIR = Path(__file__).parent.parent / "recipes"


def load_recipe(style_id: str) -> dict:
    path = RECIPES_DIR / f"{style_id}.json"
    if not path.exists():
        raise FileNotFoundError(f"Recipe not found: {style_id}")
    return json.loads(path.read_text())


def generate_guide(regions: list[RegionResult], style_id: str) -> PaintingGuide:
    recipe = load_recipe(style_id)
    region_recipes = recipe["region_recipes"]
    painting_order = recipe["painting_order"]

    # painting_order 레이어 순서에 따라 region 정렬
    layer_priority = {layer: i for i, layer in enumerate(painting_order)}

    region_guides: list[RegionGuide] = []
    for region in regions:
        label = region.label
        if label not in region_recipes:
            continue
        r = region_recipes[label]
        region_guides.append(RegionGuide(
            region_id=region.id,
            label=label,
            layer=r["layer"],
            palette=[PaletteColor(**c) for c in r["palette"]],
            brush=BrushPreset(**r["brush"]),
            stroke_guide=StrokeGuide(**r["stroke_guide"]),
            tips=r["tips"],
        ))

    region_guides.sort(key=lambda g: layer_priority.get(g.layer, 99))

    return PaintingGuide(
        style_id=style_id,
        painting_order=painting_order,
        region_guides=region_guides,
    )
