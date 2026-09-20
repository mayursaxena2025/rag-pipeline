from __future__ import annotations

from fastapi import FastAPI
from pydantic import BaseModel

from rag_pipeline.config import PipelineConfig
from rag_pipeline.rag_pipeline import RAGPipeline

app = FastAPI(title="RAG Pipeline API", version="1.0.0")


class AskRequest(BaseModel):
    question: str
    data_dir: str = "./data"
    chunk_size: int = 800
    chunk_overlap: int = 120
    search_k: int = 4
    embedding_model: str = "sentence-transformers/all-MiniLM-L6-v2"
    llm_model: str = "gpt-4o-mini"
    llm_provider: str = "auto"


class RebuildRequest(BaseModel):
    data_dir: str = "./data"
    chunk_size: int = 800
    chunk_overlap: int = 120
    embedding_model: str = "sentence-transformers/all-MiniLM-L6-v2"
    llm_model: str = "gpt-4o-mini"
    llm_provider: str = "auto"


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/ask")
def ask(request: AskRequest) -> dict[str, object]:
    config = PipelineConfig(
        data_dir=request.data_dir,
        chunk_size=request.chunk_size,
        chunk_overlap=request.chunk_overlap,
        search_k=request.search_k,
        embedding_model=request.embedding_model,
        llm_model=request.llm_model,
        llm_provider=request.llm_provider,
    )

    pipeline = RAGPipeline(config)
    result = pipeline.ask(request.question)
    return {
        "answer": result["answer"],
        "sources": result["sources"],
    }


@app.post("/admin/rebuild-index")
def rebuild_index(request: RebuildRequest) -> dict[str, object]:
    config = PipelineConfig(
        data_dir=request.data_dir,
        chunk_size=request.chunk_size,
        chunk_overlap=request.chunk_overlap,
        embedding_model=request.embedding_model,
        llm_model=request.llm_model,
        llm_provider=request.llm_provider,
    )

    pipeline = RAGPipeline(config)
    pipeline.rebuild_index()
    return {
        "status": "ok",
        "documents_loaded": len(pipeline._documents),
        "index_dir": str(config.index_path),
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
