import re
import json
from pathlib import Path

def rescue_efficientnet():
    log_path = Path("training_log.txt")
    if not log_path.exists():
        print("Log not found.")
        return

    history = {'loss': [], 'val_loss': [], 'accuracy': [], 'val_accuracy': []}
    
    with open(log_path, 'r') as f:
        log_content = f.read()

    # Pattern to match Epoch summaries
    # Example:
    # Epoch 1/80 | 1925.8s
    #   Train Loss: 1.8550 | Acc: 47.21%
    #   Val Loss  : 0.9861 | Acc: 67.92%
    
    epochs = re.findall(r"Epoch \d+/80.*\n\s+Train Loss: ([\d.]+) \| Acc: ([\d.]+)%\n\s+Val Loss\s+: ([\d.]+) \| Acc: ([\d.]+)%", log_content)
    
    for loss, acc, v_loss, v_acc in epochs:
        history['loss'].append(float(loss))
        history['accuracy'].append(float(acc))
        history['val_loss'].append(float(v_loss))
        history['val_accuracy'].append(float(v_acc))

    # Save the rescued history
    out_path = Path("models/efficientnet_scratch_history.json")
    with open(out_path, 'w') as f:
        json.dump(history, f, indent=4)
    
    print(f"✅ Rescued {len(history['loss'])} epochs for EfficientNet-B0")

if __name__ == "__main__":
    rescue_efficientnet()
