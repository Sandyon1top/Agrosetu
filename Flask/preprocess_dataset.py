import os
import cv2
import numpy as np
from pathlib import Path
import json

# UPDATED: Pointing to the real 91-class dataset path found in train_models.py
BASE_PATH = Path("/Users/sandip/Datasets/dataset_clean_final 4")
OUTPUT_PATH = Path(__file__).parent / "data"
IMAGE_SIZE = (224, 224)

def get_all_classes():
    """Dynamically find all class folders in the dataset."""
    if not BASE_PATH.exists():
        print(f"❌ Error: Base path {BASE_PATH} not found!")
        return []
    
    # Check for both train/valid structure or flat structure
    train_path = BASE_PATH / "train"
    if train_path.exists():
        classes = [d.name for d in train_path.iterdir() if d.is_dir() and not d.name.startswith('.')]
    else:
        # Fallback to scanning the main directory if no split exists yet
        classes = [d.name for d in BASE_PATH.iterdir() if d.is_dir() and not d.name.startswith('.') and d.name not in ['train', 'valid', 'test']]
    
    classes.sort()
    print(f"🔍 Found {len(classes)} classes in dataset.")
    return classes

def create_output_structure(classes):
    for split in ['train', 'valid', 'test']:
        split_path = OUTPUT_PATH / split
        split_path.mkdir(parents=True, exist_ok=True)
        for class_name in classes:
            class_path = split_path / class_name
            class_path.mkdir(parents=True, exist_ok=True)

def resize_and_save_images(classes):
    print(f"🚀 Starting image preprocessing for {len(classes)} classes...")
    global processed_count, error_count
    processed_count = 0
    error_count = 0

    # Check if the source has splits or is flat
    has_splits = (BASE_PATH / "train").exists()
    
    if has_splits:
        for split in ['train', 'valid']:
            split_src = BASE_PATH / split
            for class_name in classes:
                src_class_path = split_src / class_name
                _process_class_folder(src_class_path, split, class_name)
    else:
        # Flat structure: process all into 'train' by default
        for class_name in classes:
            src_class_path = BASE_PATH / class_name
            _process_class_folder(src_class_path, "train", class_name)
            
    print(f"\n✅ Preprocessing complete!")
    print(f"📊 Successfully processed: {processed_count}")
    print(f"⚠️  Errors encountered: {error_count}")
    return processed_count, error_count

def _process_class_folder(src_class_path, split, class_name):
    global processed_count, error_count
    if not src_class_path.exists(): return
    
    img_files = []
    for ext in ["*.jpg", "*.jpeg", "*.png", "*.JPG", "*.JPEG", "*.PNG"]:
        img_files.extend(list(src_class_path.glob(ext)))
    
    if not img_files: return

    print(f"📦 Processing {split}/{class_name} ({len(img_files)} images)")
    
    for img_file in img_files:
        try:
            img = cv2.imread(str(img_file))
            if img is None:
                error_count += 1
                continue
            
            img_resized = cv2.resize(img, IMAGE_SIZE)
            output_dir = OUTPUT_PATH / split / class_name
            output_file = output_dir / img_file.name
            cv2.imwrite(str(output_file), img_resized)
            processed_count += 1
        except:
            error_count += 1

def generate_dataset_summary(classes):
    summary = {"total_classes": len(classes), "splits": {}}
    
    for split in ['train', 'valid']:
        summary["splits"][split] = {}
        total_in_split = 0
        for class_name in classes:
            class_path = OUTPUT_PATH / split / class_name
            if class_path.exists():
                count = len(list(class_path.glob("*.jpg"))) + len(list(class_path.glob("*.png")))
                summary["splits"][split][class_name] = count
                total_in_split += count
        summary["splits"][split]["_total"] = total_in_split
    
    summary_file = OUTPUT_PATH / "dataset_summary.json"
    with open(summary_file, 'w') as f:
        json.dump(summary, f, indent=2)
    
    print(f"\n📝 Dataset Summary saved to {summary_file}")
    print(f"🏆 Total Classes: {len(classes)}")

if __name__ == "__main__":
    classes = get_all_classes()
    if classes:
        create_output_structure(classes)
        resize_and_save_images(classes)
        generate_dataset_summary(classes)
    else:
        print("❌ No classes found. Please check your BASE_PATH.")
