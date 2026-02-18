import os
from flask import Flask, request, jsonify
from flask_cors import CORS
import torch
import torch.nn as nn
import cv2
import numpy as np
import json
from pathlib import Path
import base64
import io
from PIL import Image

app = Flask(__name__)
# Enable CORS for all routes, allow multipart form data
CORS(app, resources={r"/*": {"origins": "*", "methods": ["GET", "POST", "OPTIONS"]}})

# Additional CORS headers
@app.after_request
def after_request(response):
    response.headers.add('Access-Control-Allow-Origin', '*')
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type,Authorization')
    response.headers.add('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS')
    return response

# Configuration
MODEL_PATH = Path(__file__).parent / "models"
DISEASE_DB_PATH = Path(__file__).parent / "disease_solutions.json"

# Load disease solutions database
with open(DISEASE_DB_PATH, 'r') as f:
    DISEASE_DATABASE = json.load(f)

# Class mapping
CLASS_INDICES = {
    0: 'potato_early',
    1: 'potato_late',
    2: 'potato_healthy',
    3: 'tomato_early',
    4: 'tomato_late',
    5: 'tomato_healthy'
}

LOADED_MODELS = {}
DEVICE = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

# Model architectures (must match train_models.py)
class CustomCNN(nn.Module):
    def __init__(self):
        super(CustomCNN, self).__init__()
        self.features = nn.Sequential(
            nn.Conv2d(3, 32, kernel_size=3, padding=1),
            nn.BatchNorm2d(32),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(2, 2),
            
            nn.Conv2d(32, 64, kernel_size=3, padding=1),
            nn.BatchNorm2d(64),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(2, 2),
            
            nn.Conv2d(64, 128, kernel_size=3, padding=1),
            nn.BatchNorm2d(128),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(2, 2),
            
            nn.Conv2d(128, 256, kernel_size=3, padding=1),
            nn.BatchNorm2d(256),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(2, 2)
        )
        self.classifier = nn.Sequential(
            nn.Linear(256 * 10 * 10, 512),
            nn.ReLU(inplace=True),
            nn.Dropout(0.3),
            nn.Linear(512, 6)
        )
    
    def forward(self, x):
        x = self.features(x)
        x = x.view(x.size(0), -1)
        x = self.classifier(x)
        return x

def load_all_models():
    """Load all three trained PyTorch models"""
    global LOADED_MODELS
    
    # Import model builders from train_models
    import sys
    sys.path.insert(0, str(MODEL_PATH.parent))
    
    try:
        from train_models import build_mobilenet_model, build_efficientnet_model
    except ImportError:
        print("Could not import model builders from train_models.py")
        build_mobilenet_model = None
        build_efficientnet_model = None
    
    models_to_load = [
        ('mobilenet_scratch.pt', 'mobilenet', build_mobilenet_model),
        ('efficientnet_scratch.pt', 'efficientnet', build_efficientnet_model),
        ('custom_cnn.pt', 'custom_cnn', CustomCNN)
    ]
    
    for model_file, model_key, model_builder in models_to_load:
        model_path = MODEL_PATH / model_file
        if model_path.exists():
            try:
                # Build model architecture
                if model_key == 'custom_cnn':
                    model = CustomCNN()
                elif model_builder:
                    model = model_builder()
                else:
                    print(f"Could not build {model_key}, skipping")
                    continue
                
                # Load trained weights
                model.load_state_dict(torch.load(str(model_path), map_location=DEVICE))
                model = model.to(DEVICE)
                model.eval()
                
                LOADED_MODELS[model_key] = model
                print(f"Loaded model: {model_file}")
            except Exception as e:
                print(f"Error loading {model_file}: {str(e)}")
        else:
            print(f"Model file not found: {model_path}")

def preprocess_image(image_data, target_size=(160, 160)):
    """Preprocess image for PyTorch models (IMAGE_SIZE=160 from train_models.py)"""
    # Convert image data to numpy array
    if isinstance(image_data, bytes):
        image = Image.open(io.BytesIO(image_data))
        image_array = np.array(image)
    else:
        image_array = image_data
    
    # Handle different image formats
    if len(image_array.shape) == 2:  # Grayscale
        image_array = cv2.cvtColor(image_array, cv2.COLOR_GRAY2RGB)
    elif image_array.shape[2] == 4:  # RGBA
        image_array = cv2.cvtColor(image_array, cv2.COLOR_RGBA2RGB)
    
    # Resize and normalize
    image_resized = cv2.resize(image_array, target_size)
    image_float = image_resized.astype('float32') / 255.0

    # Apply the same normalization used during training (ImageNet mean/std)
    # Training pipeline used transforms.Normalize(mean=[0.485,0.456,0.406], std=[0.229,0.224,0.225])
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    std = np.array([0.229, 0.224, 0.225], dtype=np.float32)

    # Normalize per-channel
    image_normalized = (image_float - mean) / std

    # Convert to PyTorch tensor (C, H, W format)
    image_tensor = torch.from_numpy(image_normalized).permute(2, 0, 1).unsqueeze(0)
    
    return image_tensor

def ensemble_predict(image_tensor):
    """Get ensemble predictions from all loaded models"""
    predictions = []
    
    # Move tensor to device
    image_tensor = image_tensor.to(DEVICE)
    
    with torch.no_grad():
        for model_name, model in LOADED_MODELS.items():
            try:
                output = model(image_tensor)
                # Convert logits to probabilities
                probabilities = torch.softmax(output, dim=1)[0].cpu().numpy()
                predictions.append(probabilities)
                # Debug: log individual model predictions
                class_idx = np.argmax(probabilities)
                confidence = probabilities[class_idx] * 100
                print(f"  [{model_name}] {CLASS_INDICES[class_idx]} ({confidence:.1f}%)")
            except Exception as e:
                print(f"Error predicting with {model_name}: {str(e)}")
    
    if not predictions:
        return None, None
    
    # Average predictions from all models
    ensemble_pred = np.mean(predictions, axis=0)
    class_idx = np.argmax(ensemble_pred)
    confidence = float(ensemble_pred[class_idx]) * 100
    
    print(f"  [ENSEMBLE] {CLASS_INDICES[class_idx]} ({confidence:.1f}%)")
    return class_idx, confidence

def get_disease_info(class_idx):
    # Lookup disease information from database
    disease_key = CLASS_INDICES.get(class_idx)
    if disease_key in DISEASE_DATABASE:
        return DISEASE_DATABASE[disease_key]
    return None

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'online',
        'models_loaded': len(LOADED_MODELS),
        'available_models': list(LOADED_MODELS.keys()),
        'device': str(DEVICE)
    }), 200

@app.route('/predict', methods=['POST'])
def predict_disease():
    """Handle image upload and return disease prediction"""
    try:
        if 'image' not in request.files and 'image_data' not in request.form:
            return jsonify({'error': 'No image provided'}), 400
        
        # Get image data
        if 'image' in request.files:
            image_file = request.files['image']
            if image_file.filename == '':
                return jsonify({'error': 'No file selected'}), 400
            image_data = image_file.read()
        else:
            image_data = request.form.get('image_data')
            image_data = base64.b64decode(image_data)
        
        print(f"\n[PREDICTION REQUEST] Image size: {len(image_data)} bytes")
        
        # Preprocess image
        image_tensor = preprocess_image(image_data)
        
        # Get ensemble prediction
        class_idx, confidence = ensemble_predict(image_tensor)
        
        if class_idx is None:
            return jsonify({'error': 'Model prediction failed'}), 500
        
        # Get disease information
        disease_info = get_disease_info(class_idx)
        
        if disease_info is None:
            return jsonify({'error': 'Disease information not found'}), 500
        
        response = {
            'success': True,
            'disease_key': CLASS_INDICES[class_idx],
            'disease_name': disease_info['disease_name'],
            'confidence': round(confidence, 2),
            'description': disease_info['description'],
            'solutions': disease_info['solutions'],
            'pesticide': disease_info['pesticide'],
            'dosage': disease_info['dosage'],
            'frequency': disease_info['frequency'],
            'prevention': disease_info['prevention'],
            'stage': disease_info['stage']
        }
        
        return jsonify(response), 200
    
    except Exception as e:
        return jsonify({'error': f'Prediction error: {str(e)}'}), 500

@app.route('/model-info', methods=['GET'])
def model_info():
    """Return information about loaded models"""
    models_info = {}
    for model_name, model in LOADED_MODELS.items():
        # Count parameters
        total_params = sum(p.numel() for p in model.parameters())
        
        models_info[model_name] = {
            'parameters': int(total_params),
            'device': str(DEVICE),
            'type': 'PyTorch'
        }
    
    return jsonify({
        'total_models': len(LOADED_MODELS),
        'models': models_info,
        'classes': CLASS_INDICES,
        'ensemble_type': 'voting_average',
        'image_size': (160, 160)
    }), 200

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404

@app.errorhandler(500)
def server_error(error):
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    print("Loading models...")
    print(f"Using device: {DEVICE}")
    load_all_models()
    
    if not LOADED_MODELS:
        print("WARNING: No models loaded. Please train models first using train_models.py")
    else:
        print(f"Successfully loaded {len(LOADED_MODELS)} models")
    
    print("Starting Flask server on localhost:5000")
    app.run(host='0.0.0.0', port=8000, debug=True)
