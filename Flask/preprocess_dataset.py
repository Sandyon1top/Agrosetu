import os
import cv2
import numpy as np
from pathlib import Path
import json

BASE_PATH = Path(__file__).parent / "archive" / "idata" / "Image Dataset" / "ImageDataset"
OUTPUT_PATH = Path(__file__).parent / "data"
IMAGE_SIZE = (224, 224)

DISEASE_CLASSES = {
    'potato_early': 'Potato Early Blight',
    'potato_late': 'Potato Late Blight',
    'potato_healthy': 'Healthy Potato',
    'tomato_early': 'Tomato Early Blight',
    'tomato_late': 'Tomato Late Blight',
    'tomato_healthy': 'Healthy Tomato'
}

def create_output_structure():
    for split in ['train', 'valid', 'test']:
        split_path = OUTPUT_PATH / split
        split_path.mkdir(parents=True, exist_ok=True)
        for class_name in DISEASE_CLASSES.keys():
            class_path = split_path / class_name
            class_path.mkdir(parents=True, exist_ok=True)

def resize_and_save_images():
    print("Starting image preprocessing...")
    processed_count = 0
    error_count = 0
    
    for split in ['train', 'valid']:
        split_path = BASE_PATH / split
        for class_name in DISEASE_CLASSES.keys():
            class_path = split_path / class_name
            
            if not class_path.exists():
                print(f"Skipping {split}/{class_name} - not found")
                continue
            
            img_files = list(class_path.glob("*.jpg")) + list(class_path.glob("*.png"))
            print(f"Processing {split}/{class_name} - found {len(img_files)} images")
            
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
                    
                except Exception as e:
                    print(f"Error processing {img_file}: {str(e)}")
                    error_count += 1
    
    print(f"\nPreprocessing complete!")
    print(f"Successfully processed: {processed_count}")
    print(f"Errors encountered: {error_count}")
    return processed_count, error_count

def generate_dataset_summary():
    summary = {}
    
    for split in ['train', 'valid']:
        summary[split] = {}
        for class_name in DISEASE_CLASSES.keys():
            class_path = OUTPUT_PATH / split / class_name
            if class_path.exists():
                img_count = len(list(class_path.glob("*.jpg"))) + len(list(class_path.glob("*.png")))
                summary[split][class_name] = img_count
    
    summary_file = OUTPUT_PATH / "dataset_summary.json"
    with open(summary_file, 'w') as f:
        json.dump(summary, f, indent=2)
    
    print("\nDataset Summary:")
    for split, classes in summary.items():
        print(f"\n{split.upper()}:")
        total = 0
        for class_name, count in classes.items():
            print(f"  {DISEASE_CLASSES[class_name]}: {count} images")
            total += count
        print(f"  Total: {total}")

if __name__ == "__main__":
    create_output_structure()
    resize_and_save_images()
    generate_dataset_summary()
