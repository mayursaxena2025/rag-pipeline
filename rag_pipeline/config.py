from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass
class PipelineConfig:
    data_dir: str = "./data"
    chunk_size: int = 800
    chunk_overlap: int = 120
    search_k: int = 4
    embedding_model: str = "sentence-transformers/all-MiniLM-L6-v2"
    llm_model: str = "gpt-4o-mini"
    llm_provider: str = "auto"
    index_dir: str = "./vector_store"

    @property
    def data_path(self) -> Path:
        return Path(self.data_dir).expanduser().resolve()

    @property
    def index_path(self) -> Path:
        return Path(self.index_dir).expanduser().resolve()
