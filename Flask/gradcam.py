import torch
import torch.nn as nn
import torch.nn.functional as F
import cv2
import numpy as np
from PIL import Image
from torchvision import models as tv_models, transforms
from pathlib import Path

# PyTorch Grad-CAM implementation for model interpretability 
class GradCAM:
    def __init__(self, model, target_layer):
        self.model = model
        self.target_layer = target_layer
        self.gradients = None
        self.activations = None
        
        # Register hooks
        self.target_layer.register_forward_hook(self.save_activation)
        self.target_layer.register_full_backward_hook(self.save_gradient)

    def save_activation(self, module, input, output):
        self.activations = output

    def save_gradient(self, module, grad_input, grad_output):
        self.gradients = grad_output[0]

    def generate_heatmap(self, input_tensor, class_idx=None):
        # Forward pass
        output = self.model(input_tensor)
        
        if class_idx is None:
            class_idx = torch.argmax(output, dim=1).item()
            
        # Backward pass
        self.model.zero_grad()
        loss = output[0, class_idx]
        loss.backward()
        
        # Calculate weights (Global Average Pooling of gradients)
        weights = torch.mean(self.gradients, dim=(2, 3), keepdim=True)
        
        # Weighted sum of activations
        cam = torch.sum(weights * self.activations, dim=1, keepdim=True)
        cam = F.relu(cam) # Apply ReLU
        
        # Normalize to [0, 1]
        cam = cam.detach().cpu().numpy()[0, 0]
        cam = (cam - cam.min()) / (cam.max() - cam.min() + 1e-8)
        
        return cam

def overlay_heatmap(image_path, heatmap, alpha=0.5):
    # Load original image
    img = cv2.imread(image_path)
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    height, width, _ = img.shape
    
    # Resize heatmap to match image size
    heatmap = cv2.resize(heatmap, (width, height))
    heatmap = np.uint8(255 * heatmap)
    heatmap = cv2.applyColorMap(heatmap, cv2.COLORMAP_JET)
    
    # Overlay
    superimposed = cv2.addWeighted(img, 1 - alpha, heatmap, alpha, 0)
    return superimposed

def generate_visual_report(model_path, image_path, output_path, model_type="mobilenet"):
    # 1. Setup transform (Standard PyTorch normalize)
    transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
    ])
    
    # 2. Load model architecture
    # Assuming class size is 38 (PlantVillage) or 91 (Agrosetu)
    # This logic detects number of classes from model weight size if possible
    # For now we use the architecture code from train_models.py
    
    device = torch.device("mps" if torch.backends.mps.is_available() else ("cuda" if torch.cuda.is_available() else "cpu"))
    checkpoint = torch.load(model_path, map_location=device)
    
    # Detect num_classes from classifier weight size
    if "classifier.1.weight" in checkpoint:
        num_classes = checkpoint["classifier.1.weight"].shape[0]
    elif "classifier.3.weight" in checkpoint: # some old models might have different layer index
        num_classes = checkpoint["classifier.3.weight"].shape[0]
    else:
        num_classes = 38 # Fallback to 38 if not found
    
    if model_type == "mobilenet":
        model = tv_models.mobilenet_v2(weights=None)
        model.classifier[1] = nn.Linear(model.last_channel, num_classes)
        target_layer = model.features[18]
    elif model_type == "efficientnet":
        model = tv_models.efficientnet_b0(weights=None)
        in_features = model.classifier[1].in_features
        model.classifier[1] = nn.Linear(in_features, num_classes)
        target_layer = model.features[8]
    else: # Custom CNN
        class SimpleCNN(nn.Module):
            def __init__(self, n):
                super().__init__()
                self.features = nn.Sequential(
                    nn.Conv2d(3,32,3,padding=1), nn.ReLU(True), nn.MaxPool2d(2,2),
                    nn.Conv2d(32,64,3,padding=1), nn.ReLU(True), nn.MaxPool2d(2,2),
                    nn.AdaptiveAvgPool2d((4,4)))
                self.classifier = nn.Sequential(nn.Flatten(), nn.Linear(64*4*4, 512), nn.ReLU(True), nn.Linear(512, n))
            def forward(self, x): return self.classifier(self.features(x))
        model = SimpleCNN(num_classes)
        target_layer = model.features[3] # Second conv layer

    model.load_state_dict(checkpoint)
    model.eval()
    
    # 3. Process image
    img = Image.open(image_path).convert("RGB")
    input_tensor = transform(img).unsqueeze(0)
    
    # 4. Generate Grad-CAM
    cam_generator = GradCAM(model, target_layer)
    heatmap = cam_generator.generate_heatmap(input_tensor)
    
    # 5. Save report image
    result = overlay_heatmap(image_path, heatmap)
    cv2.imwrite(output_path, cv2.cvtColor(result, cv2.COLOR_RGB2BGR))
    print(f"✅ Grad-CAM report saved to: {output_path}")

if __name__ == "__main__":
    # Create output directory
    heatmaps_dir = Path("heatmaps")
    heatmaps_dir.mkdir(parents=True, exist_ok=True)
    
    # Example paths (adjust to your local setup)
    MODELS_DIR = Path("models")
    DATA_DIR = Path("data/valid")
    
    # Check for existing models
    model_file = list(MODELS_DIR.glob("*.pt"))
    if model_file:
        best_model = model_file[0]
        # Find first image in validation set
        image_file = list(DATA_DIR.rglob("*.jpg")) + list(DATA_DIR.rglob("*.png"))
        if image_file:
            print(f"🚀 Running Grad-CAM on {image_file[0].name} using {best_model.name}")
            generate_visual_report(
                str(best_model), 
                str(image_file[0]), 
                str(heatmaps_dir / "viva_demo_heatmap.jpg"),
                model_type="mobilenet" if "mobilenet" in best_model.name.lower() else "efficientnet"
            )
        else:
            print("❌ No images found in data/valid. Please add sample images to test.")
    else:
        print("❌ No .pt models found in models/ directory. Train models first.")
