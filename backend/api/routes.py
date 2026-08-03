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

    # Run expert inference with reasoning + RAG
    result = await inference.expert_triage(
        text_query=triage_req.text_query,
        audio_transcript=triage_req.audio_transcript,
        image_base64=image_base64,
        sector_id=triage_req.sector_id,
        web_context=web_context,
    )

    # Record to activity store if available
    if hasattr(request.app.state, "activity_store"):
        request.app.state.activity_store.record_activity(
            text_query=triage_req.text_query,
            audio_transcript=triage_req.audio_transcript,
            image_base64=image_base64,
            sector_id=triage_req.sector_id,
            urgency_level=result.urgency_level,
            clinical_summary=result.clinical_summary,
            first_aid_steps=result.first_aid_steps,
            evacuation_target=result.evacuation_target,
            hazard_alerts=result.hazard_alerts,
            reasoning_trace=result.reasoning_trace,
            sources=result.sources,
            web_enhanced=result.web_enhanced,
            latency_ms=result.latency_ms,
        )

    return result


@router.get("/activities")
async def get_activities(
    request: Request,
    urgency: Optional[str] = None,
    sector: Optional[str] = None,
    limit: int = 50,
):
    """Retrieve recent field activities for dashboard."""
    if hasattr(request.app.state, "activity_store"):
        return request.app.state.activity_store.get_activities(
            urgency=urgency, sector=sector, limit=limit
        )
    return []


@router.get("/stats")
async def get_stats(request: Request):
    """Retrieve real-time command node summary metrics."""
    if hasattr(request.app.state, "activity_store"):
        return request.app.state.activity_store.get_stats()
    return {
        "total_requests": 0,
        "recent_requests_count": 0,
        "urgency_counts": {"red": 0, "yellow": 0, "green": 0},
        "active_sectors": [],
        "avg_latency_ms": 0.0,
    }


@router.get("/rag-docs")
async def get_rag_docs(request: Request):
    """Retrieve indexed document metadata from ChromaDB vector store."""
    if hasattr(request.app.state, "rag") and request.app.state.rag.collection:
        try:
            col = request.app.state.rag.collection
            count = col.count()
            peek = col.peek(limit=20)
            docs = []
            if peek and "documents" in peek and peek["documents"]:
                for i in range(len(peek["documents"])):
                    docs.append({
                        "id": peek["ids"][i] if "ids" in peek else f"doc_{i}",
                        "source": peek["metadatas"][i].get("source", "Unknown") if "metadatas" in peek and peek["metadatas"] else "Unknown",
                        "snippet": peek["documents"][i][:200] + "..." if len(peek["documents"][i]) > 200 else peek["documents"][i],
                    })
            return {"total_chunks": count, "sample_chunks": docs}
        except Exception as e:
            return {"total_chunks": 0, "sample_chunks": [], "error": str(e)}
    return {"total_chunks": 0, "sample_chunks": []}
