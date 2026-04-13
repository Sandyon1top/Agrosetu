import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset
from torchvision import transforms
import numpy as np
from pathlib import Path
import json
import time
from PIL import Image

# Import scratch implementation
from Efficientnetb0 import EfficientNetB0Scratch

# ──────────────────────────────────────────────────────────────────
#  CONFIG
# ──────────────────────────────────────────────────────────────────
IMAGE_SIZE    = 224
BATCH_SIZE    = 32       # Standard for B0
EPOCHS        = 80       # Increased for scratch training
LEARNING_RATE = 0.001
DEVICE = torch.device(
    "mps"  if torch.backends.mps.is_available() else
    "cuda" if torch.cuda.is_available()          else
    "cpu"
)

DATA_PATH  = Path(__file__).parent / "data"
MODEL_PATH = Path(__file__).parent / "models"
MODEL_PATH.mkdir(exist_ok=True)

# Full disease class list from train_models.py
DISEASE_CLASSES = [
    "Apple_Black_Rot", "Apple_Healthy", "Apple_Rotten", "Apple_Rust", "Apple_Scab",
    "Banana_Healthy", "Banana_Rotten", "BellPepper_Bacterial_Spot", "BellPepper_Healthy",
    "BellPepper_Rotten", "Carrot_Healthy", "Carrot_Rotten", "Cassava_Bacterial_Blight",
    "Cassava_Brown_Streak", "Cassava_Green_Mottle", "Cassava_Healthy", "Cassava_Mosaic",
    "Cherry_Healthy", "Cherry_Powdery_Mildew", "Chili_Healthy", "Chili_Leaf_Curl",
    "Chili_Leaf_Spot", "Chili_Whitefly", "Chili_Yellowish", "Coffee_Cercospora_Leaf_Spot",
    "Coffee_Healthy", "Coffee_Red_Spider_Mite", "Coffee_Rust", "Corn_Common_Rust",
    "Corn_Gray_Leaf_Spot", "Corn_Healthy", "Corn_Northern_Leaf_Blight", "Cucumber_Diseased",
    "Cucumber_Healthy", "Cucumber_Rotten", "Grape_Black_Measles", "Grape_Black_Rot",
    "Grape_Healthy", "Grape_Leaf_Blight", "Grape_Rotten", "Guava_Diseased", "Guava_Healthy",
    "Guava_Rotten", "Jamun_Diseased", "Jamun_Healthy", "Jujube_Healthy", "Jujube_Rotten",
    "Lemon_Diseased", "Lemon_Healthy", "Mango_Diseased", "Mango_Healthy", "Mango_Rotten",
    "Orange_Healthy", "Orange_Rotten", "Peach_Bacterial_Spot", "Peach_Healthy",
    "Pomegranate_Diseased", "Pomegranate_Healthy", "Pomegranate_Rotten", "Potato_Early_Blight",
    "Potato_Late_Blight", "Potato_Rotten", "Rice_Brown_Spot", "Rice_Healthy", "Rice_Hispa",
    "Rice_Leaf_Blast", "Rice_Neck_Blast", "Soybean_Bacterial_Blight", "Soybean_Caterpillar",
    "Soybean_Diabrotica", "Soybean_Downy_Mildew", "Soybean_Healthy", "Soybean_Mosaic_Virus",
    "Soybean_Powdery_Mildew", "Soybean_Rust", "Soybean_Southern_Blight", "Strawberry_Healthy",
    "Strawberry_Leaf_Scorch", "Strawberry_Rotten", "Sugarcane_Bacterial_Blight",
    "Sugarcane_Healthy", "Sugarcane_Red_Rot", "Sugarcane_Red_Stripe", "Sugarcane_Rust",
    "Tea_Algal_Leaf", "Tea_Anthracnose", "Tea_Bird_Eye_Spot", "Tea_Brown_Blight",
    "Tea_Healthy", "Tea_Red_Leaf_Spot", "Tomato_Bacterial_Spot", "Tomato_Early_Blight",
    "Tomato_Late_Blight", "Tomato_Leaf_Mold", "Tomato_Mosaic_Virus", "Tomato_Rotten",
    "Tomato_Septoria_Leaf_Spot", "Tomato_Spider_Mites", "Tomato_Target_Spot",
    "Tomato_Yellow_Leaf_Curl", "Wheat_Brown_Rust", "Wheat_Healthy", "Wheat_Septoria",
    "Wheat_Yellow_Rust"
]

NUM_CLASSES = len(DISEASE_CLASSES)

# ──────────────────────────────────────────────────────────────────
#  DATASET
# ──────────────────────────────────────────────────────────────────

class DiseaseDataset(Dataset):
    def __init__(self, root_dir, transform=None):
        self.root_dir     = Path(root_dir)
        self.transform    = transform
        self.images       = []
        self.labels       = []
        self.class_to_idx = {cls: idx for idx, cls in enumerate(DISEASE_CLASSES)}

        print(f"  Searching in {self.root_dir}...")
        for class_name, class_idx in self.class_to_idx.items():
            class_path = self.root_dir / class_name
            if not class_path.exists():
                continue
            
            img_files = (
                list(class_path.glob('*.jpg'))   + list(class_path.glob('*.JPG'))
                + list(class_path.glob('*.jpeg'))+ list(class_path.glob('*.JPEG'))
                + list(class_path.glob('*.png')) + list(class_path.glob('*.PNG'))
            )
            for img_file in img_files:
                self.images.append(str(img_file))
                self.labels.append(class_idx)
        
        print(f"  Loaded {len(self.images)} images for {self.root_dir.name}")

    def __len__(self):
        return len(self.images)

    def __getitem__(self, idx):
        try:
            image = Image.open(self.images[idx]).convert('RGB')
            if self.transform:
                image = self.transform(image)
            return image, self.labels[idx]
        except Exception as e:
            print(f"Error loading {self.images[idx]}: {e}")
            # Return a dummy image if one fails to avoid crashing long training
            return torch.zeros((3, IMAGE_SIZE, IMAGE_SIZE)), self.labels[idx]

def get_loaders():
    mean = [0.485, 0.456, 0.406]
    std  = [0.229, 0.224, 0.225]

    train_tf = transforms.Compose([
        transforms.RandomResizedCrop(IMAGE_SIZE, scale=(0.8, 1.0)),
        transforms.RandomHorizontalFlip(),
        transforms.RandomRotation(15),
        transforms.ColorJitter(0.2, 0.2, 0.2),
        transforms.ToTensor(),
        transforms.Normalize(mean, std)
    ])
    
    val_tf = transforms.Compose([
        transforms.Resize((IMAGE_SIZE, IMAGE_SIZE)),
        transforms.ToTensor(),
        transforms.Normalize(mean, std)
    ])

    train_ds = DiseaseDataset(DATA_PATH / 'train', train_tf)
    val_ds   = DiseaseDataset(DATA_PATH / 'valid', val_tf)

    # Note: num_workers=0 is safer for Mac MPS
    train_loader = DataLoader(train_ds, BATCH_SIZE, shuffle=True, num_workers=0)
    val_loader   = DataLoader(val_ds, BATCH_SIZE, shuffle=False, num_workers=0)
    
    return train_loader, val_loader

# ──────────────────────────────────────────────────────────────────
#  TRAINING LOOP
# ──────────────────────────────────────────────────────────────────

def train():
    print(f"🚀 Starting EfficientNet-B0 Scratch Training")
    print(f"📍 Device: {DEVICE}")
    print(f"📍 Classes: {NUM_CLASSES}")

    train_loader, val_loader = get_loaders()
    
    model = EfficientNetB0Scratch(num_classes=NUM_CLASSES).to(DEVICE)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='min', factor=0.5, patience=5)

    history = {'loss': [], 'val_loss': [], 'accuracy': [], 'val_accuracy': []}
    best_acc = 0.0
    patience = 12  # Higher patience for scratch training
    no_improve = 0

    for epoch in range(EPOCHS):
        start_time = time.time()
        
        # Train
        model.train()
        total_loss, correct, total = 0, 0, 0
        for i, (imgs, lbls) in enumerate(train_loader):
            imgs, lbls = imgs.to(DEVICE), lbls.to(DEVICE)
            
            optimizer.zero_grad()
            outputs = model(imgs)
            loss = criterion(outputs, lbls)
            loss.backward()
            optimizer.step()
            
            total_loss += loss.item()
            _, pred = outputs.max(1)
            total += lbls.size(0)
            correct += pred.eq(lbls).sum().item()
            
            if (i+1) % 100 == 0:
                print(f"  Batch {i+1}/{len(train_loader)} | Loss: {loss.item():.4f}")

        train_acc = 100 * correct / total
        avg_loss = total_loss / len(train_loader)

        # Val
        model.eval()
        v_loss, v_correct, v_total = 0, 0, 0
        with torch.no_grad():
            for imgs, lbls in val_loader:
                imgs, lbls = imgs.to(DEVICE), lbls.to(DEVICE)
                outputs = model(imgs)
                v_loss += criterion(outputs, lbls).item()
                _, pred = outputs.max(1)
                v_total += lbls.size(0)
                v_correct += pred.eq(lbls).sum().item()

        val_acc = 100 * v_correct / v_total
        avg_v_loss = v_loss / len(val_loader)
        
        history['loss'].append(avg_loss)
        history['val_loss'].append(avg_v_loss)
        history['accuracy'].append(train_acc)
        history['val_accuracy'].append(val_acc)

        duration = time.time() - start_time
        print(f"Epoch {epoch+1}/{EPOCHS} | {duration:.1f}s")
        print(f"  Train Loss: {avg_loss:.4f} | Acc: {train_acc:.2f}%")
        print(f"  Val Loss  : {avg_v_loss:.4f} | Acc: {val_acc:.2f}%")

        scheduler.step(avg_v_loss)

        if val_acc > best_acc:
            best_acc = val_acc
            torch.save(model.state_dict(), MODEL_PATH / "efficientnet_scratch_best.pt")
            print(f"  ⭐ New Best Accuracy: {best_acc:.2f}% (Saved)")
            no_improve = 0
        else:
            no_improve += 1
            if no_improve >= patience:
                print(f"Early stopping at epoch {epoch+1}")
                break

    torch.save(model.state_dict(), MODEL_PATH / "efficientnet_scratch_final.pt")
    with open(MODEL_PATH / "efficientnet_scratch_history.json", 'w') as f:
        json.dump(history, f, indent=2)
    
    print("✅ Training Complete!")

if __name__ == "__main__":
    train()
