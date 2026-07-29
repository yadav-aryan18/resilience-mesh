import json
import logging
from typing import Optional

from fastapi import APIRouter, Request, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse

from models.schemas import TriageRequest, TriageResponse, HealthCheck
from services.inference_service import InferenceService
from services.web_agent_service import WebAgentService

logger = logging.getLogger("resiliencemesh.api")
router = APIRouter()


@router.get("/health", response_model=HealthCheck)
async def health_check(request: Request):
    """Health endpoint for mesh discovery & diagnostics."""
    rag_count = 0
    try:
        if hasattr(request.app.state, "rag") and request.app.state.rag.collection:
            rag_count = request.app.state.rag.collection.count()
    except Exception:
        pass

    agent = WebAgentService()
    is_online = await agent.check_connectivity()

    model_name = "gemma4:12b"
    if hasattr(request.app.state, "inference"):
        model_name = getattr(request.app.state.inference, "MODEL_NAME", "gemma4:12b")

    return HealthCheck(
        status="ok",
        node_type="command",
        model_loaded=request.app.state.inference.is_ready if hasattr(request.app.state, "inference") else False,
        vector_db_chunks=rag_count,
        ollama_model=model_name,
        web_connectivity=is_online,
    )


@router.post("/expert-triage", response_model=TriageResponse)
async def expert_triage(
    request: Request,
    payload: str = Form(..., description="JSON-serialized FieldPayload"),
    image_base64: Optional[str] = Form(None),
):
    """
    Receive field data from mobile edge node, run expert inference
    with local RAG + optional web agent, return structured triage.
    """
    try:
        data = json.loads(payload)
        triage_req = TriageRequest(**data)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid payload: {e}")

    inference: InferenceService = request.app.state.inference

    # Check internet for opportunistic web agent
    web_context = ""
    agent = WebAgentService()
    if await agent.check_connectivity():
        logger.info("🌐 Internet available — triggering opportunistic web agent")
        web_context = await agent.gather_context(
            sector=triage_req.sector_id,
            query=triage_req.text_query,
        )

    # Run expert inference with <|think|> reasoning + RAG
    result = await inference.expert_triage(
        text_query=triage_req.text_query,
        audio_transcript=triage_req.audio_transcript,
        image_base64=image_base64,
        sector_id=triage_req.sector_id,
        web_context=web_context,
    )

    return result
