#!/bin/bash
# Setup script for AgroSetu AI Disease Detection System (Linux/macOS)
# Run this from the Flask directory

echo ""
echo "========================================"
echo "AgroSetu AI Disease Detection Setup"
echo "========================================"
echo ""

# Check Python installation
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python3 is not installed"
    echo "Please install Python 3.8+ from https://www.python.org/"
    exit 1
fi

echo "[1] Checking Python installation... OK"
echo ""

# Create virtual environment
if [ ! -d "venv" ]; then
    echo "[2] Creating virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    echo "    Virtual environment created and activated"
else
    echo "[2] Virtual environment already exists"
    source venv/bin/activate
fi
echo ""

# Install requirements
echo "[3] Installing Python dependencies..."
pip install --upgrade pip > /dev/null 2>&1
pip install -r requirements.txt
echo "    Dependencies installed"
echo ""

# Create directories
echo "[4] Creating output directories..."
mkdir -p models
mkdir -p data
mkdir -p heatmaps
echo "    Directories created"
echo ""

echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Preprocess dataset:"
echo "   python preprocess_dataset.py"
echo ""
echo "2. Train models (this takes 2-4 hours):"
echo "   python train_models.py"
echo ""
echo "3. Start Flask server:"
echo "   python app.py"
echo ""
echo "4. In new terminal, start ngrok:"
echo "   ngrok http 5000"
echo ""
echo "5. Copy ngrok URL to Flutter api_service.dart"
echo ""
echo "For more details, see IMPLEMENTATION_GUIDE.md"
echo ""
