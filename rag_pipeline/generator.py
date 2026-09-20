from __future__ import annotations

import os
from typing import List

from langchain.docstore.document import Document


class Generator:
    def __init__(self, llm_provider: str = "openai", model_name: str = "gpt-4o-mini"):
        self.llm_provider = llm_provider
        self.model_name = model_name
        self._llm = self._build_llm()

    def _build_llm(self):
        if self.llm_provider == "mock":
            return MockLLM()

        if self.llm_provider == "auto":
            provider = "openai" if os.getenv("OPENAI_API_KEY") else "mock"
        else:
            provider = self.llm_provider

        if provider == "mock":
            return MockLLM()

        try:
            from langchain_openai import ChatOpenAI
            return ChatOpenAI(model=self.model_name, temperature=0)
        except Exception:
            return MockLLM()

    def generate(self, question: str, context_docs: List[Document]) -> str:
        context = "\n\n".join(doc.page_content for doc in context_docs)
        prompt = (
            "Use the following retrieved context to answer the user's question. "
            "If the answer is not in the context, say so clearly.\n\n"
            f"Question: {question}\n\nContext:\n{context}"
        )

        try:
            if hasattr(self._llm, "invoke"):
                response = self._llm.invoke(prompt)
                if hasattr(response, "content"):
                    return response.content
                return str(response)

            return str(self._llm(prompt))
        except Exception:
            return MockLLM().generate(question, context_docs)


class MockLLM:
    def __call__(self, prompt: str) -> str:
        return (
            "This is a mock answer generated from the provided context. "
            "The exact result depends on the indexed documents and the retrieved passages."
        )

    def invoke(self, prompt: str):
        return type("Response", (), {"content": self.__call__(prompt)})()
