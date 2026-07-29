import unittest
from services.rag_service import RAGService


class TestRAG(unittest.TestCase):
    def test_rag_service_initialization(self):
        rag = RAGService()
        self.assertIsNotNone(rag.collection)
        self.assertEqual(rag.collection.name, "emergency_protocols")

    def test_rag_query(self):
        rag = RAGService()
        results = rag.query("bleeding", k=2)
        self.assertIsInstance(results, list)
        if results:
            self.assertIn("text", results[0])
            self.assertIn("source", results[0])


if __name__ == "__main__":
    unittest.main()
