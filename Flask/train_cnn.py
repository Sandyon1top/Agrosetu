import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset
from torchvision import transforms
from PIL import Image
import os
import json
import time
from pathlib import Path

# ──────────────────────────────────────────────────────────────────
#  CONFIG
# ──────────────────────────────────────────────────────────────────
IMAGE_SIZE    = 224
BATCH_SIZE    = 64       
EPOCHS        = 25       
LEARNING_RATE = 0.001
DEVICE = torch.device(
    "mps"  if torch.backends.mps.is_available() else
    "cuda" if torch.cuda.is_available()          else
    "cpu"
)

BASE_DIR     = Path(__file__).parent
DATA_PATH    = BASE_DIR / "data"
MODEL_PATH   = BASE_DIR / "models"
MODEL_PATH.mkdir(parents=True, exist_ok=True)

# THE AUTHORITATIVE 104 CLASSES
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
#  ROBUST DATASET CLASS (Skips empty folders)
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
                + list(class_path.glob('*.webp'))
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
            return torch.zeros((3, IMAGE_SIZE, IMAGE_SIZE)), self.labels[idx]

# ──────────────────────────────────────────────────────────────────
#  BEST FROM SCRATCH ARCHITECTURE (3-Layer + BN)
# ──────────────────────────────────────────────────────────────────
class CustomCNN(nn.Module):
    def __init__(self, num_classes=104):
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv2d(3, 32, 3, padding=1),
            nn.BatchNorm2d(32),
            nn.ReLU(True),
            nn.MaxPool2d(2, 2),

            nn.Conv2d(32, 64, 3, padding=1),
            nn.BatchNorm2d(64),
            nn.ReLU(True),
            nn.MaxPool2d(2, 2),

            nn.Conv2d(64, 128, 3, padding=1),
            nn.BatchNorm2d(128),
            nn.ReLU(True),
            nn.AdaptiveAvgPool2d((4, 4))
        )
        self.classifier = nn.Sequential(
            nn.Flatten(),
            nn.Linear(128 * 4 * 4, 512),
            nn.ReLU(True),
            nn.Dropout(0.5),
            nn.Linear(512, num_classes)
        )

    def forward(self, x):
        return self.classifier(self.features(x))

# ──────────────────────────────────────────────────────────────────
#  TRAINING PIPELINE
# ──────────────────────────────────────────────────────────────────
def train():
    print(f"🚀 Starting ROBUST Custom CNN Training (SCRATCH) on {DEVICE}")
    print(f"📊 Mode: Manual Loading, No Cheating, 104 Classes")

    transform = transforms.Compose([
        transforms.Resize((IMAGE_SIZE, IMAGE_SIZE)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
    ])

    train_ds = DiseaseDataset(DATA_PATH / 'train', transform)
    val_ds   = DiseaseDataset(DATA_PATH / 'valid', transform)

    # num_workers=0 is safer for Mac MPS/Stability
    train_loader = DataLoader(train_ds, batch_size=BATCH_SIZE, shuffle=True,  num_workers=0)
    val_loader   = DataLoader(val_ds,   batch_size=BATCH_SIZE, shuffle=False, num_workers=0)

    model = CustomCNN(num_classes=NUM_CLASSES).to(DEVICE)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)

    history = {"train_loss": [], "val_loss": [], "accuracy": [], "val_accuracy": []}
    best_acc = 0.0

    for epoch in range(EPOCHS):
        model.train()
        running_loss = 0.0
        correct = 0
        total = 0
        start_time = time.time()

        for batch_idx, (inputs, labels) in enumerate(train_loader):
            inputs, labels = inputs.to(DEVICE), labels.to(DEVICE)
            optimizer.zero_grad()
            outputs = model(inputs)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()

            running_loss += loss.item()
            _, predicted = outputs.max(1)
            total += labels.size(0)
            correct += predicted.eq(labels).sum().item()

            if batch_idx % 200 == 0:
                print(f"Epoch {epoch+1}/{EPOCHS} | Batch {batch_idx}/{len(train_loader)} | Loss: {loss.item():.4f}")

        train_loss = running_loss / len(train_loader)
        train_acc  = 100. * correct / total

        # Validation
        model.eval()
        val_correct = 0
        val_total = 0
        with torch.no_grad():
            for inputs, labels in val_loader:
                inputs, labels = inputs.to(DEVICE), labels.to(DEVICE)
                outputs = model(inputs)
                _, predicted = outputs.max(1)
                val_total += labels.size(0)
                val_correct += predicted.eq(labels).sum().item()

        v_acc  = 100. * val_correct / val_total
        print(f"🏁 Epoch {epoch+1} Done | Val Acc: {v_acc:.2f}% | Time: {time.time()-start_time:.1f}s")

        history["train_loss"].append(train_loss)
        history["accuracy"].append(train_acc)
        history["val_accuracy"].append(v_acc)

        if v_acc > best_acc:
            best_acc = v_acc
            torch.save(model.state_dict(), MODEL_PATH / "custom_cnn_best.pt")
            print(f"🌟 Best model saved! ({best_acc:.2f}%)")

        with open(MODEL_PATH / "custom_cnn_history.json", 'w') as f:
            json.dump(history, f, indent=2)

    print(f"✨ Training Complete! Peak Accuracy: {best_acc:.2f}%")

if __name__ == "__main__":
    train()
