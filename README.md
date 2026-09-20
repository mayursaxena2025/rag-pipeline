# RAG Pipeline

This project implements a Retrieval-Augmented Generation (RAG) pipeline using a modern stack based on LangChain, FAISS, and Hugging Face embeddings.

## Features

- Loads documents from a folder
- Splits long text into chunks
- Embeds chunks with a fast sentence-transformer model
- Stores vectors in a FAISS index
- Retrieves top-k relevant text
- Uses an LLM to answer questions using retrieved context

## Quick start

1. Create a virtual environment.
2. Install dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

3. Start with sample data:

```bash
python main.py --data-dir ./data --question "What is the purpose of this project?"
```

4. Optional: configure OpenAI by copying `.env.example` to `.env`.

```bash
cp .env.example .env
```

## Structure

- `main.py`: entry point
- `rag_pipeline/`: project modules
- `data/`: sample knowledge base
