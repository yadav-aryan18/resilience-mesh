import json
import unittest
from fastapi.testclient import TestClient
from main import app


class TestRoutes(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)

    def test_root_endpoint(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ResilienceMesh Command Node Online")

    def test_health_endpoint(self):
        response = self.client.get("/api/health")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["status"], "ok")
        self.assertEqual(data["node_type"], "command")
        self.assertIn("vector_db_chunks", data)

    def test_expert_triage_fallback_endpoint(self):
        payload = {
            "text_query": "Severe leg bleeding, victim unconscious",
            "sector_id": "Sector 4",
        }
        response = self.client.post(
            "/api/expert-triage",
            data={"payload": json.dumps(payload)},
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn(data["urgency_level"], ["red", "yellow", "green", "critical", "urgent", "stable"])
        self.assertGreater(len(data["first_aid_steps"]), 0)


if __name__ == "__main__":
    unittest.main()
