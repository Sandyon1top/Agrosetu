# AgroSetu — Flask ML Server

AI-powered crop disease detection backend using PyTorch ensemble models.

## Models
- **MobileNetV2** (scratch) — 95.86% accuracy
- **EfficientNetB0** (scratch) — 96.61% accuracy
- **Custom CNN** — 94.91% accuracy
- **Ensemble** — 96.73% accuracy (3-model average)

Supports **104 disease classes** across 27 crop types.

## Quick Start

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Start server
python app.py
```

Server runs on `http://0.0.0.0:8000`

## API Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/predict` | POST | Ensemble prediction |
| `/predict/compare` | POST | All 3 models with comparison |
| `/predict/mobilenet` | POST | MobileNetV2 only |
| `/predict/efficientnet` | POST | EfficientNetB0 only |
| `/predict/visualize` | POST | Grad-CAM heatmap |
| `/health` | GET | Server + model status |
| `/classes` | GET | All 104 disease classes |

## Training (one-time setup)

```bash
python preprocess_dataset.py   # ~10 min
python train_models.py         # ~2-4 hours
```

## File Structure

```
app.py              # Main Flask server
mobilenet.py        # MobileNetV2 architecture
Efficientnetb0.py   # EfficientNetB0 architecture
gradcam.py          # Grad-CAM explainability
models/             # Trained .pt weight files
data/               # Training dataset
```
