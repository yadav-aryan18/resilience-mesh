import unittest
from datetime import datetime
from models.schemas import HealthCheck, TriageRequest, TriageResponse


class TestSchemas(unittest.TestCase):
    def test_health_check_schema(self):
        health = HealthCheck(
            status="ok",
            node_type="command",
            model_loaded=True,
            vector_db_chunks=15,
            ollama_model="gemma4:12b",
            web_connectivity=False,
        )
        self.assertEqual(health.status, "ok")
        self.assertEqual(health.vector_db_chunks, 15)
        self.assertEqual(health.ollama_model, "gemma4:12b")

    def test_triage_request_schema(self):
        req = TriageRequest(
            text_query="Victim bleeding profusely",
            sector_id="Sector 4",
        )
        self.assertEqual(req.text_query, "Victim bleeding profusely")
        self.assertEqual(req.sector_id, "Sector 4")
        self.assertIsInstance(req.timestamp, datetime)

    def test_triage_response_schema(self):
        resp = TriageResponse(
            urgency_level="red",
            clinical_summary="Hemorrhage detected",
            first_aid_steps=["Apply pressure", "Elevate legs"],
            evacuation_target="Safe point A",
            hazard_alerts=["Rising water"],
            sources=["red_cross_first_aid.txt"],
            web_enhanced=False,
            latency_ms=120.5,
        )
        self.assertEqual(resp.urgency_level, "red")
        self.assertEqual(len(resp.first_aid_steps), 2)
        self.assertEqual(resp.latency_ms, 120.5)


if __name__ == "__main__":
    unittest.main()
