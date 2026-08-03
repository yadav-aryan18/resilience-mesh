import os
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from api.routes import router
from services.rag_service import RAGService
from services.inference_service import InferenceService
from services.activity_service import ActivityService

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger("resiliencemesh")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("🔧 Initializing ResilienceMesh Command Node...")
    # Warm up vector DB, activity ring buffer, and Ollama connection
    app.state.rag = RAGService()
    app.state.activity_store = ActivityService()
    app.state.inference = InferenceService(rag_service=app.state.rag)
    logger.info("✅ Command Node ready. Listening on 0.0.0.0:8000")
    yield
    logger.info("🛑 Shutting down Command Node...")


app = FastAPI(
    title="ResilienceMesh Command Node",
    description="Tactical First-Aid & Disaster Response — Tier 2 Expert Triage",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router, prefix="/api")

# Mount Vite compiled frontend static files if available
FRONTEND_DIST = os.path.join(os.path.dirname(__file__), "frontend", "dist")
STATIC_FALLBACK = os.path.join(os.path.dirname(__file__), "static")

if os.path.exists(FRONTEND_DIST):
    app.mount("/", StaticFiles(directory=FRONTEND_DIST, html=True), name="frontend")
elif os.path.exists(STATIC_FALLBACK):
    app.mount("/", StaticFiles(directory=STATIC_FALLBACK, html=True), name="static")
else:
    @app.get("/")
    async def root():
        return {
            "status": "ResilienceMesh Command Node Online",
            "dashboard": "Frontend build not found. Run 'npm run build' inside backend/frontend/.",
        }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
