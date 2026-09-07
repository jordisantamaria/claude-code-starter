# /new-llm-project

Scaffolds a new LLM-based project following consulting best practices.

## Usage
```
/new-llm-project <project-name> [--type rag|agent|chatbot|pipeline]
```

## Instructions

When the user invokes this skill, create a new project directory with the following structure.
Ask the user for the project name and type if not provided.

### Project Types

**RAG** (Retrieval Augmented Generation):
```
<project-name>/
├── src/
│   ├── __init__.py
│   ├── ingestion.py      # Document loading, chunking, embedding
│   ├── retriever.py      # Vector store search, reranking
│   ├── generator.py      # LLM call with retrieved context
│   ├── chain.py          # Full RAG chain orchestration
│   └── api.py            # FastAPI endpoints
├── tests/
│   ├── test_ingestion.py
│   ├── test_retriever.py
│   └── test_api.py
├── configs/
│   └── config.yaml       # Model, chunking, retriever settings
├── data/                  # .gitignored
├── Dockerfile
├── docker-compose.yml     # App + vector DB (ChromaDB/Qdrant)
├── requirements.txt
├── .env.example           # API keys template
├── .gitignore
├── CLAUDE.md
└── README.md
```

**Agent** (Tool-using agent):
```
<project-name>/
├── src/
│   ├── __init__.py
│   ├── agent.py           # Agent orchestration logic
│   ├── tools/             # Tool definitions
│   │   ├── __init__.py
│   │   └── example_tool.py
│   ├── prompts.py         # System prompts and templates
│   └── api.py             # FastAPI endpoints
├── tests/
├── configs/
│   └── config.yaml
├── Dockerfile
├── requirements.txt
├── .env.example
├── .gitignore
├── CLAUDE.md
└── README.md
```

**Chatbot** (Conversational):
```
<project-name>/
├── src/
│   ├── __init__.py
│   ├── chat.py            # Chat logic, history management
│   ├── prompts.py         # System prompts
│   ├── memory.py          # Conversation memory (buffer/summary)
│   └── api.py             # FastAPI with WebSocket support
├── tests/
├── configs/
│   └── config.yaml
├── Dockerfile
├── requirements.txt
├── .env.example
├── .gitignore
├── CLAUDE.md
└── README.md
```

**Pipeline** (Data processing with LLM):
```
<project-name>/
├── src/
│   ├── __init__.py
│   ├── extractor.py       # LLM-based data extraction
│   ├── classifier.py      # LLM-based classification
│   ├── pipeline.py        # Orchestrate extraction + classification
│   ├── validators.py      # Output validation with Pydantic
│   └── api.py             # FastAPI endpoints
├── tests/
├── configs/
│   └── config.yaml
├── Dockerfile
├── requirements.txt
├── .env.example
├── .gitignore
├── CLAUDE.md
└── README.md
```

### For ALL project types, always include:

**requirements.txt** with:
- anthropic or openai (ask user which LLM provider)
- fastapi, uvicorn
- pydantic, pydantic-settings
- python-dotenv
- Project-specific deps (chromadb for RAG, etc.)

**CLAUDE.md** with:
- Project description
- Stack and conventions (Python, FastAPI, chosen LLM provider)
- Project structure explanation
- How to run locally
- Environment variables needed

**README.md** with:
- Project name and description
- Architecture diagram (ASCII)
- Setup instructions
- API documentation
- Example requests

**.gitignore** with: data/, models/, .env, __pycache__/, .venv/

**.env.example** with: placeholder API keys

**All source files** with:
- Real, working code (not placeholders)
- Type hints on all functions
- Pydantic models for API request/response
- Error handling
- Logging setup
- Health check endpoint

### Code conventions
- Language: Python
- Documentation: Spanish (README, CLAUDE.md)
- Code comments: English
- API framework: FastAPI with async
- Validation: Pydantic v2
- Config: pydantic-settings + .env
- LLM calls: use structured outputs where possible
- Always include retry logic for LLM API calls
- Always include cost estimation logging
