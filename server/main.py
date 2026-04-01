from fastapi import FastAPI
from routers import segmentation, guide

app = FastAPI(
    title="Repaint API",
    version="0.1.0",
    description="AI Painting Coach — segmentation and guide generation server",
)

app.include_router(segmentation.router)
app.include_router(guide.router)


@app.get("/health")
async def health():
    return {"status": "ok"}
