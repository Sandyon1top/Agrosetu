@echo off
REM Setup script for AgroSetu AI Disease Detection System (Windows)
REM Run this from the Flask directory

echo.
echo ========================================
echo AgroSetu AI Disease Detection Setup
echo ========================================
echo.

REM Check Python installation
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.8+ from https://www.python.org/
    pause
    exit /b 1
)

echo [1] Checking Python installation... OK
echo.

REM Create virtual environment (optional but recommended)
if not exist venv (
    echo [2] Creating virtual environment...
    python -m venv venv
    call venv\Scripts\activate.bat
    echo     Virtual environment created and activated
) else (
    echo [2] Virtual environment already exists
    call venv\Scripts\activate.bat
)
echo.

REM Install requirements
echo [3] Installing Python dependencies...
pip install --upgrade pip >nul 2>&1
pip install -r requirements.txt
echo     Dependencies installed
echo.

REM Create directories
echo [4] Creating output directories...
if not exist "models" mkdir models
if not exist "data" mkdir data
if not exist "heatmaps" mkdir heatmaps
echo     Directories created
echo.

echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo Next steps:
echo.
echo 1. Preprocess dataset:
echo    python preprocess_dataset.py
echo.
echo 2. Train models (this takes 2-4 hours):
echo    python train_models.py
echo.
echo 3. Start Flask server:
echo    python app.py
echo.
echo 4. In new terminal, start ngrok:
echo    ngrok http 5000
echo.
echo 5. Copy ngrok URL to Flutter api_service.dart
echo.
echo For more details, see IMPLEMENTATION_GUIDE.md
echo.
pause
