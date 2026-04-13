import json
from pathlib import Path

def get_stats(history_path, model_name):
    path = Path(history_path)
    if not path.exists():
        return None
    
    with open(path, 'r') as f:
        data = json.load(f)
    
    epochs = len(data['loss'])
    peak_acc = max(data['val_accuracy'])
    final_acc = data['val_accuracy'][-1]
    
    return {
        "name": model_name,
        "epochs": epochs,
        "peak_acc": peak_acc,
        "final_acc": final_acc
    }

print("\n" + "="*60)
print("             AGROSETU AI TRAINING REPORT (SCRATCH)")
print("="*60)
print(f"{'Model Name':<20} | {'Epochs':<8} | {'Peak Accuracy':<15} | {'Status'}")
print("-" * 60)

models = [
    ("models/mobilenet_scratch_history.json", "MobileNetV2"),
    ("models/efficientnet_scratch_history.json", "EfficientNet-B0"),
    ("models/custom_cnn_history.json", "Custom CNN")
]

for path, name in models:
    stats = get_stats(path, name)
    if stats:
        print(f"{stats['name']:<20} | {stats['epochs']:<8} | {stats['peak_acc']:>12.2f}% | ✅ SAVED")
    else:
        print(f"{name:<20} | {'N/A':<8} | {'N/A':>13} | ❌ NOT FOUND")

print("-" * 60)
print("Training Mode : FROM SCRATCH (Zero Pretrained Weights)")
print("Datasets      : 100,107 Training Images | 11,452 Validation")
print("Batch Size    : 32 Images per Batch (~3,129 Batches per Epoch)")
print("Hardware      : Apple Silicon MPS (Metal Performance Shaders)")
print("="*60 + "\n")
