from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    ollama_host: str = "http://localhost:11434"
    ollama_model: str = "gemma4:12b"
    num_ctx: int = 16384
    temperature: float = 0.3
    rag_chunk_size: int = 800
    rag_chunk_overlap: int = 100
    vector_db_path: str = "./data/vector_db"
    documents_path: str = "../rag/documents"

    class Config:
        env_file = ".env"

settings = Settings()
