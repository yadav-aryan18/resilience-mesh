"""
ResilienceMesh — Tier 2: Laptop Command Node
FastAPI server for expert triage, local RAG, and opportunistic web agents.
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.routes import router
from services.rag_service import RAGService
from services.inference_service import InferenceService

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger("resiliencemesh")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("🔧 Initializing ResilienceMesh Command Node...")
    # Warm up vector DB and Ollama connection
    app.state.rag = RAGService()
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


@app.get("/")
async def root():
    return {"status": "ResilienceMesh Command Node Online"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
