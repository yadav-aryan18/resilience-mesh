"""
Ingest PDF / DOCX / TXT emergency protocols into ChromaDB vector store.
Run once after adding new documents to rag/documents/.
"""

import os
import argparse
from pathlib import Path

from sentence_transformers import SentenceTransformer
import chromadb
from chromadb.config import Settings

DATA_DIR = Path(__file__).parent / "data" / "vector_db"
DOCS_DIR = Path(__file__).parent / "documents"


def chunk_text(text: str, max_chars: int = 800, overlap: int = 100) -> list:
    """Simple sliding-window chunking."""
    chunks = []
    start = 0
    while start < len(text):
        end = start + max_chars
        chunk = text[start:end]
        chunks.append(chunk.strip())
        start = end - overlap
    return [c for c in chunks if len(c) > 40]


def load_documents(docs_dir: Path) -> list:
    docs = []
    for path in docs_dir.iterdir():
        if path.suffix in {".txt", ".md"}:
            text = path.read_text(encoding="utf-8")
            for i, chunk in enumerate(chunk_text(text)):
                docs.append({
                    "text": chunk,
                    "source": f"{path.name}#chunk{i}",
                })
        elif path.suffix == ".pdf":
            try:
                import fitz  # PyMuPDF
                doc = fitz.open(path)
                full_text = "\n".join(page.get_text() for page in doc)
                for i, chunk in enumerate(chunk_text(full_text)):
                    docs.append({
                        "text": chunk,
                        "source": f"{path.name}#chunk{i}",
                    })
            except ImportError:
                print("PyMuPDF not installed. Skipping PDF.")
    return docs


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="all-MiniLM-L6-v2")
    parser.add_argument("--reset", action="store_true", help="Wipe existing DB")
    args = parser.parse_args()

    try:
        client = chromadb.PersistentClient(path=str(DATA_DIR))
    except Exception:
        client = chromadb.Client()

    if args.reset:
        try:
            client.delete_collection("emergency_protocols")
            print("🗑️  Existing collection deleted.")
        except Exception:
            pass

    collection = client.create_collection(
        name="emergency_protocols",
        metadata={"hnsw:space": "cosine"},
    )

    docs = load_documents(DOCS_DIR)
    if not docs:
        print("⚠️  No documents found in rag/documents/")
        return

    print(f"📥 Loading embedding model: {args.model}")
    embedder = SentenceTransformer(args.model)

    texts = [d["text"] for d in docs]
    embeddings = embedder.encode(texts, show_progress_bar=True).tolist()
    ids = [f"doc_{i}" for i in range(len(docs))]
    metadatas = [{"source": d["source"]} for d in docs]

    collection.add(
        embeddings=embeddings,
        documents=texts,
        metadatas=metadatas,
        ids=ids,
    )

    print(f"✅ Indexed {len(docs)} chunks into ChromaDB")
    print(f"   DB location: {DATA_DIR}")


if __name__ == "__main__":
    main()
