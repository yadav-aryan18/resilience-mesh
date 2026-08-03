"""
Thread-safe in-memory ring buffer for storing recent triage transactions
and computing real-time node telemetry for the Command Dashboard.
"""

import time
import threading
from typing import List, Dict, Optional
from datetime import datetime


class ActivityService:
    def __init__(self, max_entries: int = 100):
        self.max_entries = max_entries
        self._lock = threading.Lock()
        self._activities: List[Dict] = []
        self._counter = 0

    def record_activity(
        self,
        text_query: str,
        audio_transcript: Optional[str],
        image_base64: Optional[str],
        sector_id: Optional[str],
        urgency_level: str,
        clinical_summary: str,
        first_aid_steps: List[str],
        evacuation_target: Optional[str],
        hazard_alerts: List[str],
        reasoning_trace: Optional[str],
        sources: List[str],
        web_enhanced: bool,
        latency_ms: float,
    ) -> Dict:
        with self._lock:
            self._counter += 1
            entry = {
                "id": f"TR-{self._counter:05d}",
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "text_query": text_query,
                "audio_transcript": audio_transcript,
                "has_image": bool(image_base64),
                "image_base64": image_base64,
                "sector_id": sector_id or "Unassigned",
                "urgency_level": urgency_level.lower(),
                "clinical_summary": clinical_summary,
                "first_aid_steps": first_aid_steps,
                "evacuation_target": evacuation_target,
                "hazard_alerts": hazard_alerts,
                "reasoning_trace": reasoning_trace,
                "sources": sources,
                "web_enhanced": web_enhanced,
                "latency_ms": round(latency_ms, 2),
            }

            self._activities.insert(0, entry)
            if len(self._activities) > self.max_entries:
                self._activities.pop()

            return entry

    def get_activities(
        self,
        urgency: Optional[str] = None,
        sector: Optional[str] = None,
        limit: int = 50,
    ) -> List[Dict]:
        with self._lock:
            results = self._activities
            if urgency:
                results = [a for a in results if a["urgency_level"] == urgency.lower()]
            if sector:
                results = [a for a in results if a["sector_id"].lower() == sector.lower()]
            return results[:limit]

    def get_stats(self) -> Dict:
        with self._lock:
            total = self._counter
            active_recent = self._activities
            red_count = sum(1 for a in active_recent if a["urgency_level"] == "red")
            yellow_count = sum(1 for a in active_recent if a["urgency_level"] == "yellow")
            green_count = sum(1 for a in active_recent if a["urgency_level"] == "green")
            sectors = list(set(a["sector_id"] for a in active_recent if a["sector_id"] != "Unassigned"))

            avg_latency = (
                sum(a["latency_ms"] for a in active_recent) / len(active_recent)
                if active_recent
                else 0.0
            )

            return {
                "total_requests": total,
                "recent_requests_count": len(active_recent),
                "urgency_counts": {
                    "red": red_count,
                    "yellow": yellow_count,
                    "green": green_count,
                },
                "active_sectors": sectors,
                "avg_latency_ms": round(avg_latency, 2),
            }
