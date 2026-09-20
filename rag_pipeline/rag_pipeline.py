from __future__ import annotations

from typing import Dict, List

from langchain.docstore.document import Document

from .config import PipelineConfig
from .document_loader import DocumentLoader
from .embedder import EmbeddingProvider
from .generator import Generator
from .retriever import VectorRetriever


class RAGPipeline:
    def __init__(self, config: PipelineConfig):
        self.config = config
        self.loader = DocumentLoader(config.data_dir)
        self.embedder = EmbeddingProvider(config.embedding_model)
        self.retriever = VectorRetriever(self.embedder, config.chunk_size, config.chunk_overlap, str(config.index_path))
        self.generator = Generator(config.llm_provider, config.llm_model)
        self._documents: List[Document] = []
        self._initialized = False

    def rebuild_index(self) -> None:
        documents = self.loader.load()
        if not documents:
            raise ValueError(f"No documents found in {self.config.data_path}. Add .txt, .md, .csv, or .pdf files there.")

        self._documents = documents
        self.retriever.build_index(documents)
        self._initialized = True

    def _prepare(self) -> None:
        if self._initialized:
            return

        documents = self.loader.load()
        if not documents:
            raise ValueError(f"No documents found in {self.config.data_path}. Add .txt, .md, .csv, or .pdf files there.")

        if self.config.index_path.exists() and not self.retriever.has_changed(documents):
            self.retriever.load_index()
            if self.retriever.vector_store is not None:
                self._documents = documents
                self._initialized = True
                return

        self.rebuild_index()

    def ask(self, question: str) -> Dict[str, object]:
        self._prepare()
        relevant_docs = self.retriever.retrieve(question, k=self.config.search_k)
        answer = self.generator.generate(question, relevant_docs)
        sources = [doc.metadata.get("source", "unknown") for doc in relevant_docs]
        return {"answer": answer, "sources": sources}
