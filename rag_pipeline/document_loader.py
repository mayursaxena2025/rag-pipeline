from __future__ import annotations

from pathlib import Path
from typing import List

from langchain.docstore.document import Document
from langchain_community.document_loaders import PyPDFLoader


class DocumentLoader:
    def __init__(self, data_dir: str | Path):
        self.data_dir = Path(data_dir).expanduser().resolve()

    def load(self) -> List[Document]:
        docs: List[Document] = []

        if not self.data_dir.exists():
            return docs

        for file_path in sorted(self.data_dir.iterdir()):
            if file_path.is_dir():
                continue

            if file_path.suffix.lower() == ".pdf":
                loader = PyPDFLoader(str(file_path))
                docs.extend(loader.load())
            elif file_path.suffix.lower() in {".txt", ".md", ".csv"}:
                text = file_path.read_text(encoding="utf-8")
                docs.append(Document(page_content=text, metadata={"source": str(file_path)}))

        return docs
