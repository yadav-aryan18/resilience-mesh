"""
Expert inference using Ollama + Gemma 4 (12B / 26B / 31B / A4B)
with <|think|> reasoning, local RAG grounding, and web context.
"""

import logging
import time
import base64
from typing import Optional, List

import ollama

from models.schemas import TriageResponse
from services.rag_service import RAGService

logger = logging.getLogger("resiliencemesh.inference")

SYSTEM_PROMPT = """You are ResilienceMesh — an expert tactical triage AI for disaster response.
Your role is to analyze field reports (text, audio transcripts, images) and produce structured,
prioritized medical and logistical guidance grounded in Red Cross / WHO protocols.

RULES:
1. Always classify urgency: red (critical), yellow (urgent), green (stable).
2. Output FIRST-AID STEPS as a numbered list.
3. If flood / fire / structural hazard detected, include EVACUATION_TARGET.
4. Cite which document sources you used.
5. Be concise — field responders need actionable data fast.
6. Provide your step-by-step reasoning inside the "reasoning_trace" field.

Output valid JSON strictly matching the expected schema."""


class InferenceService:
    MODEL_NAME = "gemma4:12b"  # Configurable: 12b, 26b, 31b, a4b

    def __init__(self, rag_service: RAGService):
        self.rag = rag_service
        self._ready = False
        self._warmup()

    def _warmup(self):
        try:
            ollama.list()
            self._ready = True
            logger.info(f"🧠 Ollama ready. Model target: {self.MODEL_NAME}")
        except Exception as e:
            logger.warning(f"Ollama not reachable: {e}. Will retry on first request.")

    @property
    def is_ready(self) -> bool:
        return self._ready

    async def expert_triage(
        self,
        text_query: str,
        audio_transcript: Optional[str] = None,
        image_base64: Optional[str] = None,
        sector_id: Optional[str] = None,
        web_context: str = "",
    ) -> TriageResponse:
        start = time.time()

        # 1. Retrieve local RAG context
        rag_context = self.rag.query(text_query, k=5)
        rag_text = "\n\n".join([doc["text"] for doc in rag_context])
        sources = [doc["source"] for doc in rag_context]

        # 2. Build multimodal prompt
        user_content = self._build_prompt(
            text=text_query,
            audio=audio_transcript,
            sector=sector_id,
            rag=rag_text,
            web=web_context,
        )

        images = []
        if image_base64:
            images.append(image_base64)

        user_msg = {"role": "user", "content": user_content}
        if images:
            user_msg["images"] = images

        # 3. Call Ollama with Gemma 4
        try:
            response = ollama.chat(
                model=self.MODEL_NAME,
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    user_msg,
                ],
                options={
                    "num_ctx": 4096,
                    "temperature": 0.2,
                    "num_predict": 1024,
                },
                format="json",
            )
        except Exception as e:
            logger.error(f"Ollama inference failed: {e}")
            # Fallback: structured response without model
            return self._fallback_response(text_query, sector_id)

        raw = response["message"]["content"]
        logger.debug(f"Raw model output:\n{raw}")

        # 4. Parse JSON output
        import json
        try:
            parsed = json.loads(raw)
        except Exception:
            parsed = self._extract_json(raw)

        latency = (time.time() - start) * 1000

        steps = self._to_list(parsed.get("first_aid_steps") or parsed.get("steps"))
        alerts = self._to_list(parsed.get("hazard_alerts"))

        return TriageResponse(
            urgency_level=str(parsed.get("urgency_level", "green")),
            clinical_summary=str(parsed.get("clinical_summary") or parsed.get("summary") or "Assessment complete."),
            first_aid_steps=steps if steps else ["Follow standard first-aid protocols", "Assess scene safety"],
            evacuation_target=parsed.get("evacuation_target") or parsed.get("evacuation_route"),
            hazard_alerts=alerts,
            reasoning_trace=parsed.get("reasoning_trace"),
            sources=list(set(sources)),
            web_enhanced=bool(web_context),
            latency_ms=latency,
        )

    def _to_list(self, val) -> List[str]:
        if val is None:
            return []
        if isinstance(val, list):
            return [str(i).strip() for i in val if str(i).strip()]
        if isinstance(val, str):
            return [line.strip() for line in val.split("\n") if line.strip()]
        return [str(val)]

    def _build_prompt(
        self,
        text: str,
        audio: Optional[str],
        sector: Optional[str],
        rag: str,
        web: str,
    ) -> str:
        parts = [
            "=== FIELD REPORT ===",
            f"Text: {text}",
        ]
        if audio:
            parts.append(f"Audio Transcript: {audio}")
        if sector:
            parts.append(f"Sector: {sector}")
        parts.append("\n=== LOCAL RAG CONTEXT (Red Cross / WHO) ===")
        parts.append(rag if rag else "[No relevant local documents found]")
        if web:
            parts.append("\n=== LIVE WEB CONTEXT ===")
            parts.append(web)
        parts.append("\n=== INSTRUCTION ===")
        parts.append(
            "Return valid JSON with keys: "
            "urgency_level ('red'|'yellow'|'green'), clinical_summary, first_aid_steps (list), "
            "evacuation_target (optional string), hazard_alerts (list), reasoning_trace (string), sources (list)."
        )
        return "\n".join(parts)

    def _extract_json(self, text: str) -> dict:
        import json, re
        # 1. Clean out thinking tags <|think|>...</|think|> or <think>...</think>
        cleaned = re.sub(r"<(?:\|)?think(?:\|)?>.*?</(?:\|)?think(?:\|)?>", "", text, flags=re.DOTALL).strip()
        
        # 2. Try parsing cleaned text directly
        try:
            return json.loads(cleaned)
        except Exception:
            pass

        # 3. Find JSON block inside ```json ... ``` codeblocks
        cb_match = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", cleaned, re.DOTALL)
        if cb_match:
            try:
                return json.loads(cb_match.group(1))
            except Exception:
                pass

        # 4. Find all JSON objects using balanced brace patterns
        matches = re.findall(r"\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}", cleaned, re.DOTALL)
        for m in reversed(matches):
            try:
                d = json.loads(m)
                if "urgency_level" in d or "clinical_summary" in d or "steps" in d or "first_aid_steps" in d:
                    return d
            except Exception:
                pass

        # 5. Greedy fallback on cleaned text
        g_match = re.search(r"\{.*\}", cleaned, re.DOTALL)
        if g_match:
            try:
                return json.loads(g_match.group())
            except Exception:
                pass

        return {
            "urgency_level": "yellow",
            "clinical_summary": "Unable to parse model output. Manual review required.",
            "first_aid_steps": ["Ensure scene safety", "Assess ABCs", "Request backup"],
        }

    def _fallback_response(self, query: str, sector: Optional[str]) -> TriageResponse:
        return TriageResponse(
            urgency_level="yellow",
            clinical_summary="Model inference failed. Fallback protocol activated.",
            first_aid_steps=[
                "Ensure personal and scene safety",
                "Assess airway, breathing, circulation",
                "Control bleeding with direct pressure",
                "Immobilize suspected fractures",
                "Evacuate to nearest safe point if hazard present",
            ],
            evacuation_target=f"Nearest safe elevation from {sector}" if sector else None,
            hazard_alerts=["Model offline — using fallback protocols"],
            latency_ms=0.0,
        )
