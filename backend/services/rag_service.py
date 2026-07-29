"""
Local Vector RAG Engine using ChromaDB (or sqlite-vec fallback).
Indexes Red Cross / WHO emergency first-aid guidelines.
"""

import logging
import os
from typing import List, Dict

import chromadb
from chromadb.config import Settings
from sentence_transformers import SentenceTransformer

logger = logging.getLogger("resiliencemesh.rag")

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "vector_db")
DOCS_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "rag", "documents")


class RAGService:
    COLLECTION_NAME = "emergency_protocols"
    EMBED_MODEL = "all-MiniLM-L6-v2"  # ~80MB, runs on CPU fine

    def __init__(self):
        try:
            self.client = chromadb.PersistentClient(path=DATA_DIR)
        except Exception:
            self.client = chromadb.Client()
        self.embedder = SentenceTransformer(self.EMBED_MODEL)
        self.collection = self._get_or_create_collection()
        self._ensure_indexed()

    def _get_or_create_collection(self):
        try:
            return self.client.get_collection(self.COLLECTION_NAME)
        except Exception:
            return self.client.create_collection(
                name=self.COLLECTION_NAME,
                metadata={"hnsw:space": "cosine"},
            )

    def _ensure_indexed(self):
        """Ingest documents if collection is empty."""
        count = self.collection.count()
        if count > 0:
            logger.info(f"📚 Vector DB loaded: {count} chunks indexed")
            return

        logger.info("📥 Indexing emergency protocols...")
        docs = self._load_documents()
        if not docs:
            logger.warning("No documents found in rag/documents/. RAG will be empty.")
            return

        texts = [d["text"] for d in docs]
        embeddings = self.embedder.encode(texts, show_progress_bar=True).tolist()
        ids = [f"doc_{i}" for i in range(len(docs))]
        metadatas = [{"source": d["source"]} for d in docs]

        self.collection.add(
            embeddings=embeddings,
            documents=texts,
            metadatas=metadatas,
            ids=ids,
        )
        logger.info(f"✅ Indexed {len(docs)} chunks")

    def _load_documents(self) -> List[Dict]:
        """Load .txt and .md files from rag/documents/."""
        docs = []
        if not os.path.exists(DOCS_DIR):
            os.makedirs(DOCS_DIR, exist_ok=True)
            return docs

        for fname in os.listdir(DOCS_DIR):
            path = os.path.join(DOCS_DIR, fname)
            if fname.endswith((".txt", ".md")):
                with open(path, "r", encoding="utf-8") as f:
                    text = f.read()
                # Chunk by paragraphs
                for i, chunk in enumerate(text.split("\n\n")):
                    chunk = chunk.strip()
                    if len(chunk) > 40:
                        docs.append({
                            "text": chunk,
                            "source": f"{fname}#chunk{i}",
                        })
        return docs

    def query(self, query: str, k: int = 5) -> List[Dict]:
        """Retrieve top-k relevant chunks."""
        embedding = self.embedder.encode([query]).tolist()
        results = self.collection.query(
            query_embeddings=embedding,
            n_results=k,
        )
        output = []
        for i in range(len(results["documents"][0])):
            output.append({
                "text": results["documents"][0][i],
                "source": results["metadatas"][0][i]["source"],
                "distance": results["distances"][0][i],
            })
        return output
