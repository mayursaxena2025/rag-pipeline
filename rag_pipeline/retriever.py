from __future__ import annotations

import json
from pathlib import Path
from typing import List, Sequence

from langchain.docstore.document import Document
from langchain_community.vectorstores import FAISS


class VectorRetriever:
    def __init__(self, embedding_provider, chunk_size: int = 800, chunk_overlap: int = 120, index_dir: str | None = None):
        self.embedding_provider = embedding_provider
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap
        self.index_dir = Path(index_dir).expanduser().resolve() if index_dir else None
        self.vector_store = None

    def _metadata_path(self) -> Path | None:
        if self.index_dir is None:
            return None
        return self.index_dir / "index_meta.json"

    def _snapshot_documents(self, documents: Sequence[Document]) -> dict[str, dict[str, int | None]]:
        snapshot: dict[str, dict[str, int | None]] = {}
        for document in documents:
            source = document.metadata.get("source")
            if not source:
                continue
            path = Path(source).expanduser().resolve()
            if path.exists():
                stat = path.stat()
                snapshot[str(path)] = {"mtime_ns": stat.st_mtime_ns, "size": stat.st_size}
            else:
                snapshot[str(path)] = {"mtime_ns": None, "size": None}
        return snapshot

    def save_metadata(self, documents: Sequence[Document]) -> None:
        if self.index_dir is None:
            return
        self.index_dir.mkdir(parents=True, exist_ok=True)
        metadata_path = self._metadata_path()
        if metadata_path is not None:
            metadata_path.write_text(json.dumps(self._snapshot_documents(documents), indent=2), encoding="utf-8")

    def has_changed(self, documents: Sequence[Document]) -> bool:
        if self.index_dir is None:
            return True
        metadata_path = self._metadata_path()
        if metadata_path is None or not metadata_path.exists():
            return True

        try:
            stored = json.loads(metadata_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return True

        return stored != self._snapshot_documents(documents)

    def build_index(self, documents: Sequence[Document]) -> None:
        text_splitter = __import__("langchain_text_splitters", fromlist=["RecursiveCharacterTextSplitter"]).RecursiveCharacterTextSplitter(
            chunk_size=self.chunk_size,
            chunk_overlap=self.chunk_overlap,
            length_function=len,
        )
        chunks = text_splitter.split_documents(list(documents))

        if self.index_dir is not None:
            self.index_dir.mkdir(parents=True, exist_ok=True)
            self.vector_store = FAISS.from_documents(chunks, self.embedding_provider.embeddings)
            self.vector_store.save_local(str(self.index_dir))
            self.save_metadata(documents)
            return

        self.vector_store = FAISS.from_documents(chunks, self.embedding_provider.embeddings)

    def load_index(self) -> None:
        if self.index_dir is None:
            return
        if self.index_dir.exists():
            self.vector_store = FAISS.load_local(str(self.index_dir), self.embedding_provider.embeddings, allow_dangerous_deserialization=True)

    def retrieve(self, query: str, k: int = 4) -> List[Document]:
        if self.vector_store is None:
            raise ValueError("Vector store has not been initialized. Call build_index() or load_index() first.")
        return self.vector_store.similarity_search(query, k=k)
