import json
from pathlib import Path
from fastapi import APIRouter, HTTPException
from services.guide_generator import generate_guide, load_recipe
from models.schemas import GuideRequest, PaintingGuide

router = APIRouter(tags=["guide"])

RECIPES_DIR = Path(__file__).parent.parent / "recipes"


@router.post("/generate-guide", response_model=PaintingGuide)
async def generate_painting_guide(request: GuideRequest):
    try:
        return generate_guide(request.regions, request.style_id)
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/recipes", response_model=list[dict])
async def list_recipes():
    recipes = []
    for path in RECIPES_DIR.glob("*.json"):
        data = json.loads(path.read_text())
        recipes.append({"style_id": data["style_id"], "style_name": data["style_name"]})
    return recipes


@router.get("/recipes/{style_id}", response_model=dict)
async def get_recipe(style_id: str):
    try:
        return load_recipe(style_id)
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail=f"Recipe '{style_id}' not found")
