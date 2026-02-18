Flask Backend - README

OVERVIEW
========

This Flask backend provides AI-powered disease detection for the AgroSetu app.
It uses deep learning models to identify crop diseases from leaf images.

QUICK START
===========

1. Install dependencies:
   pip install -r requirements.txt

2. Prepare dataset:
   python preprocess_dataset.py

3. Train models (takes 2-4 hours):
   python train_models.py

4. Generate visualizations (optional, for report):
   python gradcam.py
   python analyze_models.py

5. Start API server:
   python app.py

6. In another terminal, expose with ngrok:
   ngrok http 5000


FILE EXECUTION ORDER
====================

FIRST RUN SETUP (One time only)
--------------------------------

Step 1: preprocess_dataset.py
   What it does: Resizes all images to 224x224, organizes into train/valid folders
   Input: archive/idata/Image Dataset/ImageDataset/ (raw images)
   Output: data/train/, data/valid/ (preprocessed images)
   Time: 5-10 minutes
   Command: python preprocess_dataset.py
   
   Expected output:
   - data/train/potato_early/, data/train/potato_late/, etc.
   - data/valid/potato_early/, data/valid/potato_late/, etc.
   - data/dataset_summary.json (class counts)

Step 2: train_models.py
   What it does: Trains 3 AI models from scratch
   Input: Preprocessed images from Step 1
   Output: models/*.h5 (trained model weights)
   Time: 2-4 hours (GPU: 30 min - 1 hour)
   Command: python train_models.py
   
   Expected output:
   - models/mobilenet_scratch.h5 (2.3M params)
   - models/efficientnet_scratch.h5 (5.3M params)
   - models/custom_cnn.h5 (1.2M params)
   - *_history.json files (training logs)
   
   Note: This is the longest step. You can work on other things while it trains.
   GPU Tip: If you have NVIDIA GPU, TensorFlow will use it automatically.

--------------------------

Step 3: gradcam.py
   What it does: Generates heatmap visualizations showing where models focus
   Input: Trained models from Step 2
   Output: heatmaps/heatmap_0.jpg to heatmap_4.jpg
   Time: 5-10 minutes
   Command: python gradcam.py
   
   Why: Proves models learned to recognize leaf spots, not just backgrounds
   Use in report: Include 5-10 heatmap images to demonstrate model interpretability

Step 4: analyze_models.py
   What it does: Analyzes training and generates comparison metrics
   Input: Trained models and training history from Step 2
   Output: report_data/training_comparison.png, report_data/model_summary.txt
   Time: 2-3 minutes
   Command: python analyze_models.py
   
   Why: Creates charts and accuracy tables for FYP report
   Includes: Learning curves, accuracy metrics, model comparison

