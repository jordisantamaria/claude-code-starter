# /new-ai-project

Scaffolds a new pure AI/ML project following consulting best practices.

## Usage
```
/new-ai-project <project-name> [--type cv|nlp|tabular|multimodal]
```

## Instructions

When the user invokes this skill, create a new ML project directory.
Ask the user for the project name and type if not provided.

### Project Types

**CV** (Computer Vision):
```
<project-name>/
├── src/
│   ├── __init__.py
│   ├── dataset.py         # Custom Dataset class, transforms
│   ├── model.py           # Model architecture (transfer learning base)
│   ├── train.py           # Training script with argparse
│   ├── evaluate.py        # Evaluation metrics, confusion matrix
│   ├── predict.py         # Single image prediction
│   └── api.py             # FastAPI image classification/detection endpoint
├── notebooks/
│   └── eda.ipynb          # Data exploration and visualization
├── configs/
│   └── config.yaml        # Model, training, augmentation settings
├── data/                  # .gitignored
├── models/                # .gitignored
├── tests/
│   ├── test_model.py
│   └── test_api.py
├── Dockerfile
├── requirements.txt
├── .gitignore
├── CLAUDE.md
└── README.md
```

**NLP** (Natural Language Processing):
```
<project-name>/
├── src/
│   ├── __init__.py
│   ├── dataset.py         # HuggingFace dataset loading/processing
│   ├── model.py           # Model wrapper (classification/NER/etc)
│   ├── train.py           # Fine-tuning script with Trainer
│   ├── evaluate.py        # Task-specific metrics
│   ├── predict.py         # Inference on new text
│   └── api.py             # FastAPI text endpoint
├── notebooks/
│   └── eda.ipynb
├── configs/
│   └── config.yaml
├── data/
├── models/
├── tests/
├── Dockerfile
├── requirements.txt
├── .gitignore
├── CLAUDE.md
└── README.md
```

**Tabular** (Business ML):
```
<project-name>/
├── src/
│   ├── __init__.py
│   ├── data_processing.py # Load, clean, feature engineering
│   ├── model.py           # Model class (XGBoost/LightGBM wrapper)
│   ├── train.py           # Training with Optuna tuning
│   ├── evaluate.py        # Metrics, SHAP analysis, plots
│   ├── predict.py         # Batch/single prediction
│   └── api.py             # FastAPI prediction endpoint
├── notebooks/
│   ├── 01-eda.ipynb       # Exploratory data analysis
│   └── 02-modeling.ipynb  # Experimentation notebook
├── configs/
│   └── config.yaml
├── data/
├── models/
├── tests/
├── Dockerfile
├── requirements.txt
├── .gitignore
├── CLAUDE.md
└── README.md
```

### For ALL project types, always include:

**requirements.txt** based on type:
- CV: torch, torchvision, albumentations, opencv-python, fastapi, uvicorn, pillow, onnxruntime
- NLP: torch, transformers, datasets, sentence-transformers, fastapi, uvicorn
- Tabular: scikit-learn, xgboost, lightgbm, shap, optuna, pandas, numpy, fastapi, uvicorn, joblib
- All: matplotlib, seaborn, pydantic, python-dotenv, mlflow

**CLAUDE.md** with:
- Project description and business problem
- Stack: PyTorch (CV/NLP) or XGBoost/LightGBM (tabular)
- Conventions from ai-engineering-lab
- How to train, evaluate, serve

**README.md** with:
- Business problem (in Spanish)
- Solution architecture (ASCII diagram)
- Results and metrics
- How to run (train + serve)
- Client pitch section with ROI estimation

**All source files** with real, working code:
- Type hints on all functions
- Proper Dataset/DataLoader (CV/NLP) or Pipeline (tabular)
- Training with early stopping and checkpointing
- MLflow experiment tracking
- SHAP interpretability (tabular projects)
- FastAPI with Pydantic models, health check, error handling
- Device detection: CUDA → MPS → CPU

### ML conventions
- Always start with a baseline model
- Transfer learning before training from scratch (CV/NLP)
- Cross-validation for tabular
- Data augmentation for CV
- Save best model checkpoint based on validation metric
- Log all experiments with MLflow
- Reproducibility: set all random seeds
- ONNX export for production inference

### Code conventions
- Language: Python
- Documentation: Spanish (README, CLAUDE.md)
- Code comments: English
- Imports: stdlib → third-party → local
- Use pathlib for paths
- Logging module, not print()
- Type hints on public functions
