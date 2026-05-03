"""Read-only test-set evaluator.

Loads the 3 saved best checkpoints exactly like production (`app.py`),
runs forward-pass only on `data/test/`, and reports per-model
top-1 / top-5 accuracy + macro precision/recall/F1.

NOTHING is trained, saved, or modified. Pure inference.
"""

import json
import time
from pathlib import Path

import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from torchvision import datasets, transforms

from Efficientnetb0 import EfficientNetB0Scratch
from mobilenet import MobileNetV2Scratch

ROOT = Path(__file__).parent
MODEL_PATH = ROOT / "models"
_TEST_DIR = ROOT / "data" / "test"
_VAL_DIR = ROOT / "data" / "valid"
# Prefer test split if populated, else fall back to validation split
TEST_PATH = _TEST_DIR if any(_TEST_DIR.rglob("*.jpg")) or any(_TEST_DIR.rglob("*.JPG")) else _VAL_DIR

DEVICE = (
    torch.device("mps") if torch.backends.mps.is_available()
    else torch.device("cuda") if torch.cuda.is_available()
    else torch.device("cpu")
)

# Match production preprocessing exactly (app.py:280-284)
TF = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
])


# Reproduce CustomCNN architecture from app.py:123 verbatim
class CustomCNN(nn.Module):
    def __init__(self, num_classes):
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv2d(3, 32, 3, padding=1), nn.BatchNorm2d(32), nn.ReLU(True), nn.MaxPool2d(2, 2),
            nn.Conv2d(32, 64, 3, padding=1), nn.BatchNorm2d(64), nn.ReLU(True), nn.MaxPool2d(2, 2),
            nn.Conv2d(64, 128, 3, padding=1), nn.BatchNorm2d(128), nn.ReLU(True),
            nn.AdaptiveAvgPool2d((4, 4))
        )
        self.classifier = nn.Sequential(
            nn.Flatten(), nn.Linear(128 * 4 * 4, 512), nn.ReLU(True),
            nn.Dropout(0.5), nn.Linear(512, num_classes)
        )

    def forward(self, x):
        return self.classifier(self.features(x))


def load_class_indices():
    path = MODEL_PATH / "class_indices.json"
    with open(path) as f:
        m = json.load(f)
    # File stores {idx_str: class_name}. Build name->idx and idx->name.
    sample_v = next(iter(m.values()))
    if isinstance(sample_v, str):
        idx_to_name = {int(k): v for k, v in m.items()}
    else:
        idx_to_name = {int(v): k for k, v in m.items()}
    name_to_idx = {n: i for i, n in idx_to_name.items()}
    return name_to_idx, idx_to_name


class _PathListDataset(torch.utils.data.Dataset):
    def __init__(self, samples, transform):
        self.samples = samples
        self.transform = transform

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, i):
        from PIL import Image
        path, label = self.samples[i]
        img = Image.open(path).convert("RGB")
        return self.transform(img), label


def build_test_loader(class_to_idx_train, batch_size=64):
    """Manual loader so empty class folders don't crash ImageFolder.
    Uses the SAME class_to_idx mapping the models were trained with.
    """
    exts = (".jpg", ".jpeg", ".png", ".bmp", ".webp")
    samples = []
    for cls_dir in sorted(TEST_PATH.iterdir()):
        if not cls_dir.is_dir():
            continue
        cls = cls_dir.name
        if cls not in class_to_idx_train:
            continue
        idx = class_to_idx_train[cls]
        for f in cls_dir.iterdir():
            if f.suffix.lower() in exts and f.is_file():
                samples.append((str(f), idx))
    ds = _PathListDataset(samples, TF)
    loader = DataLoader(ds, batch_size=batch_size, shuffle=False, num_workers=0)
    return ds, loader


def load_model(name, builder, filename, num_classes):
    path = MODEL_PATH / filename
    if not path.exists():
        print(f"  ⚠️  {filename} not found — skipping {name}")
        return None
    # All three constructors accept num_classes
    model = builder(num_classes=num_classes)
    state = torch.load(str(path), map_location=DEVICE)
    model.load_state_dict(state, strict=False)
    model.to(DEVICE).eval()
    return model


@torch.no_grad()
def evaluate(model, loader, num_classes):
    """Returns top-1, top-5, macro precision/recall/F1, total samples."""
    correct1 = 0
    correct5 = 0
    total = 0
    all_preds = []
    all_labels = []

    for imgs, labels in loader:
        imgs = imgs.to(DEVICE)
        labels = labels.to(DEVICE)
        logits = model(imgs)
        pred1 = logits.argmax(dim=1)
        correct1 += (pred1 == labels).sum().item()
        top5 = logits.topk(5, dim=1).indices
        correct5 += (top5 == labels.unsqueeze(1)).any(dim=1).sum().item()
        total += labels.size(0)
        all_preds.append(pred1.cpu())
        all_labels.append(labels.cpu())

    preds = torch.cat(all_preds)
    labels = torch.cat(all_labels)
    # Vectorised confusion: build per-class TP/FP/FN with a single pass
    eps = 1e-9
    tp = torch.zeros(num_classes)
    fp = torch.zeros(num_classes)
    fn = torch.zeros(num_classes)
    for c in range(num_classes):
        lm = labels == c
        pm = preds == c
        tp[c] = (lm & pm).sum().item()
        fp[c] = ((~lm) & pm).sum().item()
        fn[c] = (lm & (~pm)).sum().item()
    precision_per = tp / (tp + fp + eps)
    recall_per = tp / (tp + fn + eps)
    f1_per = 2 * precision_per * recall_per / (precision_per + recall_per + eps)
    valid = (tp + fn) > 0
    macro_p = precision_per[valid].mean().item() if valid.any() else 0.0
    macro_r = recall_per[valid].mean().item() if valid.any() else 0.0
    macro_f1 = f1_per[valid].mean().item() if valid.any() else 0.0

    return {
        "top1": correct1 / max(total, 1),
        "top5": correct5 / max(total, 1),
        "macro_p": macro_p, "macro_r": macro_r, "macro_f1": macro_f1,
        "total": total, "classes_seen": int(valid.sum().item()),
    }


def main():
    print("=" * 72)
    print(" AGROSETU AI — TEST-SET EVALUATION (held-out, read-only)")
    print("=" * 72)
    print(f" Device: {DEVICE}")
    print(f" Test root: {TEST_PATH}")

    class_to_idx, idx_to_name = load_class_indices()
    num_classes = len(class_to_idx)
    print(f" Classes: {num_classes}")

    print(" Building test loader...")
    ds, loader = build_test_loader(class_to_idx, batch_size=64)
    print(f" Test images: {len(ds)}")

    models_to_run = [
        ("MobileNetV2",     "mobilenet",    MobileNetV2Scratch,      "mobilenet_scratch_best.pt"),
        ("EfficientNet-B0", "efficientnet", EfficientNetB0Scratch,   "efficientnet_scratch_best.pt"),
        ("Custom CNN",      "cnn",          CustomCNN,               "custom_cnn_best.pt"),
    ]

    results = {}
    for label, key, builder, fn in models_to_run:
        print(f"\n[{label}] loading {fn} ...")
        m = load_model(key, builder, fn, num_classes)
        if m is None:
            continue
        params = sum(p.numel() for p in m.parameters()) / 1e6
        print(f"  params: {params:.2f}M")
        t0 = time.time()
        r = evaluate(m, loader, num_classes)
        dt = time.time() - t0
        r["seconds"] = dt
        r["params_m"] = params
        results[label] = r
        print(f"  top-1: {r['top1']*100:6.2f}%   top-5: {r['top5']*100:6.2f}%   "
              f"macro F1: {r['macro_f1']*100:6.2f}%   ({dt:.1f}s)")
        # Free memory before next model
        del m
        if DEVICE.type == "cuda":
            torch.cuda.empty_cache()

    print("\n" + "=" * 72)
    print(" SUMMARY")
    print("=" * 72)
    print(f" {'Model':<18} {'Params':>9} {'Top-1':>9} {'Top-5':>9} "
          f"{'Macro-P':>9} {'Macro-R':>9} {'Macro-F1':>10} {'Time':>8}")
    print(" " + "-" * 70)
    for label, r in results.items():
        print(f" {label:<18} {r['params_m']:8.2f}M "
              f"{r['top1']*100:8.2f}% {r['top5']*100:8.2f}% "
              f"{r['macro_p']*100:8.2f}% {r['macro_r']*100:8.2f}% "
              f"{r['macro_f1']*100:9.2f}% {r['seconds']:7.1f}s")
    print(f"\n Total test images evaluated: {results[next(iter(results))]['total']}"
          if results else "\n No models evaluated.")


if __name__ == "__main__":
    main()
