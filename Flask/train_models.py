import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset
from torchvision import transforms
import numpy as np
from pathlib import Path
import json
from PIL import Image

# ── No torchvision pretrained weights — import our own scratch implementations ──
from mobilenet import MobileNetV2Scratch
from Efficientnetb0 import EfficientNetB0Scratch

IMAGE_SIZE    = 224
BATCH_SIZE    = 32
EPOCHS        = 50       # More epochs needed when training from scratch
LEARNING_RATE = 0.001    # Higher LR is fine for training from scratch
DEVICE = torch.device(
    "mps"  if torch.backends.mps.is_available() else
    "cuda" if torch.cuda.is_available()          else
    "cpu"
)

DATA_PATH  = Path(__file__).parent / "data"
MODEL_PATH = Path(__file__).parent / "models"
MODEL_PATH.mkdir(exist_ok=True)

DISEASE_CLASSES = [
    "Apple_Black_Rot",
    "Apple_Healthy",
    "Apple_Rotten",
    "Apple_Rust",
    "Apple_Scab",
    "Banana_Healthy",
    "Banana_Rotten",
    "BellPepper_Bacterial_Spot",
    "BellPepper_Healthy",
    "BellPepper_Rotten",
    "Carrot_Healthy",
    "Carrot_Rotten",
    "Cassava_Bacterial_Blight",
    "Cassava_Brown_Streak",
    "Cassava_Green_Mottle",
    "Cassava_Healthy",
    "Cassava_Mosaic",
    "Cherry_Healthy",
    "Cherry_Powdery_Mildew",
    "Chili_Healthy",
    "Chili_Leaf_Curl",
    "Chili_Leaf_Spot",
    "Chili_Whitefly",
    "Chili_Yellowish",
    "Coffee_Cercospora_Leaf_Spot",
    "Coffee_Healthy",
    "Coffee_Red_Spider_Mite",
    "Coffee_Rust",
    "Corn_Common_Rust",
    "Corn_Gray_Leaf_Spot",
    "Corn_Healthy",
    "Corn_Northern_Leaf_Blight",
    "Cucumber_Diseased",
    "Cucumber_Healthy",
    "Cucumber_Rotten",
    "Grape_Black_Measles",
    "Grape_Black_Rot",
    "Grape_Healthy",
    "Grape_Leaf_Blight",
    "Grape_Rotten",
    "Guava_Diseased",
    "Guava_Healthy",
    "Guava_Rotten",
    "Jamun_Diseased",
    "Jamun_Healthy",
    "Jujube_Healthy",
    "Jujube_Rotten",
    "Lemon_Diseased",
    "Lemon_Healthy",
    "Mango_Diseased",
    "Mango_Healthy",
    "Mango_Rotten",
    "Orange_Healthy",
    "Orange_Rotten",
    "Peach_Bacterial_Spot",
    "Peach_Healthy",
    "Pomegranate_Diseased",
    "Pomegranate_Healthy",
    "Pomegranate_Rotten",
    "Potato_Early_Blight",
    "Potato_Late_Blight",
    "Potato_Rotten",
    "Rice_Brown_Spot",
    "Rice_Healthy",
    "Rice_Hispa",
    "Rice_Leaf_Blast",
    "Rice_Neck_Blast",
    "Soybean_Bacterial_Blight",
    "Soybean_Caterpillar",
    "Soybean_Diabrotica",
    "Soybean_Downy_Mildew",
    "Soybean_Healthy",
    "Soybean_Mosaic_Virus",
    "Soybean_Powdery_Mildew",
    "Soybean_Rust",
    "Soybean_Southern_Blight",
    "Strawberry_Healthy",
    "Strawberry_Leaf_Scorch",
    "Strawberry_Rotten",
    "Sugarcane_Bacterial_Blight",
    "Sugarcane_Healthy",
    "Sugarcane_Red_Rot",
    "Sugarcane_Red_Stripe",
    "Sugarcane_Rust",
    "Tea_Algal_Leaf",
    "Tea_Anthracnose",
    "Tea_Bird_Eye_Spot",
    "Tea_Brown_Blight",
    "Tea_Healthy",
    "Tea_Red_Leaf_Spot",
    "Tomato_Bacterial_Spot",
    "Tomato_Early_Blight",
    "Tomato_Late_Blight",
    "Tomato_Leaf_Mold",
    "Tomato_Mosaic_Virus",
    "Tomato_Rotten",
    "Tomato_Septoria_Leaf_Spot",
    "Tomato_Spider_Mites",
    "Tomato_Target_Spot",
    "Tomato_Yellow_Leaf_Curl",
    "Wheat_Brown_Rust",
    "Wheat_Healthy",
    "Wheat_Septoria",
    "Wheat_Yellow_Rust",
]

NUM_CLASSES = len(DISEASE_CLASSES)  # 104


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

        loaded = 0
        for class_name, class_idx in self.class_to_idx.items():
            class_path = self.root_dir / class_name
            if not class_path.exists():
                print(f"  ⚠️  Missing folder: {class_name}")
                continue
            img_files = (
                list(class_path.glob('*.jpg'))   + list(class_path.glob('*.JPG'))
                + list(class_path.glob('*.jpeg'))+ list(class_path.glob('*.JPEG'))
                + list(class_path.glob('*.png')) + list(class_path.glob('*.PNG'))
            )
            for img_file in img_files:
                self.images.append(str(img_file))
                self.labels.append(class_idx)
            loaded += len(img_files)
        print(f"  Loaded {loaded} images from {self.root_dir.name}/")

    def __len__(self):
        return len(self.images)

    def __getitem__(self, idx):
        image = Image.open(self.images[idx]).convert('RGB')
        if self.transform:
            image = self.transform(image)
        return image, self.labels[idx]


def create_data_loaders():
    # ImageNet stats — standard normalization even when training from scratch
    mean = [0.485, 0.456, 0.406]
    std  = [0.229, 0.224, 0.225]

    train_transform = transforms.Compose([
        transforms.RandomResizedCrop(IMAGE_SIZE, scale=(0.7, 1.0)),
        transforms.RandomHorizontalFlip(),
        transforms.RandomVerticalFlip(p=0.1),
        transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.2, hue=0.05),
        transforms.RandomRotation(20),
        transforms.ToTensor(),
        transforms.Normalize(mean=mean, std=std),
    ])
    val_transform = transforms.Compose([
        transforms.Resize((IMAGE_SIZE, IMAGE_SIZE)),
        transforms.ToTensor(),
        transforms.Normalize(mean=mean, std=std),
    ])

    train_dataset = DiseaseDataset(DATA_PATH / 'train', transform=train_transform)
    val_dataset   = DiseaseDataset(DATA_PATH / 'valid', transform=val_transform)

    if len(train_dataset) == 0:
        raise RuntimeError("No training images found. Check your data/train/ folder.")

    # FIX: num_workers=0 and pin_memory=False — required on Mac (MPS/permission issue)
    train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True,
                              num_workers=0, pin_memory=False)
    val_loader   = DataLoader(val_dataset,   batch_size=BATCH_SIZE, shuffle=False,
                              num_workers=0, pin_memory=False)
    return train_loader, val_loader


# ──────────────────────────────────────────────────────────────────
#  MODELS — all from scratch, no pretrained weights
#  Uses your own mobilenet.py and Efficientnetb0.py files
# ──────────────────────────────────────────────────────────────────

def build_mobilenet_model():
    """MobileNetV2 from scratch using your mobilenet.py"""
    return MobileNetV2Scratch(num_classes=NUM_CLASSES)


def build_efficientnet_model():
    """EfficientNet-B0 from scratch using your Efficientnetb0.py"""
    return EfficientNetB0Scratch(num_classes=NUM_CLASSES)


class CustomCNN(nn.Module):
    """Simple CNN from scratch — matches app.py exactly"""
    def __init__(self):
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv2d(3, 32, 3, padding=1), nn.ReLU(True), nn.MaxPool2d(2, 2),
            nn.Conv2d(32, 64, 3, padding=1), nn.ReLU(True), nn.MaxPool2d(2, 2),
            nn.AdaptiveAvgPool2d((4, 4))
        )
        self.classifier = nn.Sequential(
            nn.Flatten(),
            nn.Linear(64 * 4 * 4, 512),
            nn.ReLU(True),
            nn.Linear(512, NUM_CLASSES)
        )
    def forward(self, x):
        return self.classifier(self.features(x))


def build_custom_cnn_model():
    return CustomCNN()


# ──────────────────────────────────────────────────────────────────
#  TRAINING
# ──────────────────────────────────────────────────────────────────

def train_model(model, model_name, train_loader, val_loader):
    model = model.to(DEVICE)

    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(
        optimizer, mode='min', factor=0.3, patience=5)

    history = {'loss': [], 'val_loss': [], 'accuracy': [], 'val_accuracy': []}
    best_val_acc     = 0.0
    patience_counter = 0
    patience_limit   = 8   # More patience when training from scratch

    for epoch in range(EPOCHS):
        # ── Train ──
        model.train()
        train_loss, correct, total = 0.0, 0, 0
        for images, labels in train_loader:
            images, labels = images.to(DEVICE), labels.to(DEVICE)
            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()
            train_loss += loss.item()
            _, predicted = torch.max(outputs, 1)
            total   += labels.size(0)
            correct += (predicted == labels).sum().item()

        train_loss /= len(train_loader)
        train_acc   = 100 * correct / total

        # ── Validate ──
        model.eval()
        val_loss, val_correct, val_total = 0.0, 0, 0
        with torch.no_grad():
            for images, labels in val_loader:
                images, labels = images.to(DEVICE), labels.to(DEVICE)
                outputs = model(images)
                loss = criterion(outputs, labels)
                val_loss    += loss.item()
                _, predicted = torch.max(outputs, 1)
                val_total   += labels.size(0)
                val_correct += (predicted == labels).sum().item()

        val_loss /= len(val_loader)
        val_acc   = 100 * val_correct / val_total

        history['loss'].append(train_loss)
        history['val_loss'].append(val_loss)
        history['accuracy'].append(train_acc)
        history['val_accuracy'].append(val_acc)

        print(f"E[{epoch+1:2d}/{EPOCHS}] "
              f"Loss: {train_loss:.3f} | Val Loss: {val_loss:.3f} | "
              f"Acc: {train_acc:.1f}% | Val Acc: {val_acc:.1f}%")

        scheduler.step(val_loss)

        if val_acc > best_val_acc:
            best_val_acc     = val_acc
            patience_counter = 0
            torch.save(model.state_dict(), MODEL_PATH / f'{model_name}_best.pt')
            print(f"  → ✅ Best saved ({val_acc:.1f}%)")
        else:
            patience_counter += 1
            if patience_counter >= patience_limit:
                print(f"  → Early stop at epoch {epoch+1}")
                break

    torch.save(model.state_dict(), MODEL_PATH / f'{model_name}_final.pt')
    with open(MODEL_PATH / f'{model_name}_history.json', 'w') as f:
        json.dump(history, f, indent=4)

    return model, history


def save_class_indices():
    idx_to_class = {str(idx): cls for idx, cls in enumerate(DISEASE_CLASSES)}
    out = MODEL_PATH / "class_indices.json"
    with open(out, 'w') as f:
        json.dump(idx_to_class, f, indent=2)
    print(f"Saved class_indices.json → {out}")


def main():
    print(f"Device     : {DEVICE}")
    print(f"Num classes: {NUM_CLASSES}")
    print(f"Image size : {IMAGE_SIZE}x{IMAGE_SIZE}")
    print(f"Training   : FROM SCRATCH (no pretrained weights)")

    save_class_indices()

    print("\nLoading data...")
    train_loader, val_loader = create_data_loaders()
    print(f"Train: {len(train_loader.dataset)} images")
    print(f"Valid: {len(val_loader.dataset)} images")

    models_to_train = [
        ('mobilenet_scratch',    build_mobilenet_model()),
        ('efficientnet_scratch', build_efficientnet_model()),
        ('custom_cnn',           build_custom_cnn_model()),
    ]

    for model_name, model in models_to_train:
        params = sum(p.numel() for p in model.parameters() if p.requires_grad)
        print(f"\n{'='*50}")
        print(f"Training : {model_name}")
        print(f"Params   : {params:,}")
        print(f"{'='*50}")
        _, history = train_model(model, model_name, train_loader, val_loader)
        print(f"Best val accuracy: {max(history['val_accuracy']):.2f}%")

    print("\n✅ All models trained from scratch!")
    print(f"Models saved in: {MODEL_PATH}")


if __name__ == '__main__':
    main()