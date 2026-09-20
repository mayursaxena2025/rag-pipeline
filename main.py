from __future__ import annotations

import argparse
import os
from pathlib import Path

from dotenv import load_dotenv

from rag_pipeline.config import PipelineConfig
from rag_pipeline.rag_pipeline import RAGPipeline

load_dotenv()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run a Retrieval-Augmented Generation (RAG) pipeline.")
    parser.add_argument("--data-dir", type=str, default="./data", help="Directory containing source documents.")
    parser.add_argument("--question", type=str, default="What is the purpose of this project?", help="Question to ask the RAG system.")
    parser.add_argument("--chunk-size", type=int, default=800, help="Maximum size of each text chunk.")
    parser.add_argument("--chunk-overlap", type=int, default=120, help="Overlap between text chunks.")
    parser.add_argument("--search-k", type=int, default=4, help="Number of relevant chunks to retrieve.")
    parser.add_argument("--embedding-model", type=str, default="sentence-transformers/all-MiniLM-L6-v2", help="Sentence-transformer model used for embeddings.")
    parser.add_argument("--llm-model", type=str, default="gpt-4o-mini", help="OpenAI model name when using an API-backed LLM.")
    parser.add_argument("--llm-provider", type=str, default="auto", choices=["auto", "openai", "mock"], help="LLM provider to use. 'auto' falls back to mock when credentials are unavailable or quota is exhausted.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    config = PipelineConfig(
        data_dir=args.data_dir,
        chunk_size=args.chunk_size,
        chunk_overlap=args.chunk_overlap,
        search_k=args.search_k,
        embedding_model=args.embedding_model,
        llm_model=args.llm_model,
        llm_provider=args.llm_provider,
    )

    pipeline = RAGPipeline(config)
    response = pipeline.ask(args.question)

    print("\n=== Answer ===")
    print(response["answer"])

    if response["sources"]:
        print("\n=== Sources ===")
        for index, source in enumerate(response["sources"], start=1):
            print(f"{index}. {source}")


if __name__ == "__main__":
    main()
