from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field


class HealthCheck(BaseModel):
    status: str
    node_type: str
    model_loaded: bool
    vector_db_chunks: int = 0
    ollama_model: str = "gemma4:12b"
    web_connectivity: bool = False


class TriageRequest(BaseModel):
    image_base64: Optional[str] = None
    audio_transcript: Optional[str] = None
    text_query: str
    sector_id: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class TriageResponse(BaseModel):
    urgency_level: str = Field(..., pattern="^(red|yellow|green|critical|urgent|stable)$")
    clinical_summary: str
    first_aid_steps: List[str]
    evacuation_target: Optional[str] = None
    hazard_alerts: List[str] = Field(default_factory=list)
    reasoning_trace: Optional[str] = None
    sources: List[str] = Field(default_factory=list)
    web_enhanced: bool = False
    latency_ms: float
    timestamp: datetime = Field(default_factory=datetime.utcnow)
