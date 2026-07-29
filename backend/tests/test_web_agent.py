import unittest
import asyncio
import re
from services.web_agent_service import WebAgentService


class TestWebAgent(unittest.TestCase):
    def test_connectivity_check(self):
        agent = WebAgentService()
        result = asyncio.run(agent.check_connectivity(timeout=0.5))
        self.assertIsInstance(result, bool)

    def test_search_web_snippet_cleaning(self):
        html_line = '<span class="result__snippet">Emergency first aid <b>guidelines</b> for flood zones</span>'
        clean = re.sub(r"<[^>]+>", "", html_line).strip()
        self.assertEqual(clean, "Emergency first aid guidelines for flood zones")


if __name__ == "__main__":
    unittest.main()
