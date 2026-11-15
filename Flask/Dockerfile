# ── Flask ML Backend Dockerfile (CPU-only PyTorch) ──
# Uses CPU-only PyTorch to drastically reduce image size (~1.2GB vs ~4GB)

FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for OpenCV
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Install CPU-only PyTorch first (much smaller than full torch)
RUN pip install --no-cache-dir \
    torch==2.2.0+cpu \
    torchvision==0.17.0+cpu \
    torchaudio==2.2.0+cpu \
    --index-url https://download.pytorch.org/whl/cpu

# Copy and install remaining requirements
COPY requirements.txt .
# Install everything except torch/torchvision/torchaudio (already installed above)
RUN grep -viE '^(torch|torchvision|torchaudio)' requirements.txt > requirements_filtered.txt && \
    pip install --no-cache-dir -r requirements_filtered.txt && \
    pip install --no-cache-dir groq flask-cors gunicorn

# Copy application code
COPY app.py .
COPY Efficientnetb0.py .
COPY mobilenet.py .
COPY gradcam.py .
COPY disease_solutions.json .

# Copy model weights
COPY models/ ./models/

EXPOSE 8000

# Use gunicorn for production with proper timeout for ML inference
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--timeout", "120", "--workers", "1", "--threads", "2", "app:app"]
