"""
cleanup_dataset.py
==================
Merges all duplicate/variant folder names into one clean canonical set.
Moves images from all duplicate folders into a single folder per disease.
Run this ONCE before training.

Usage:
    python cleanup_dataset.py
"""

import shutil
from pathlib import Path

DATA_PATH = Path(__file__).parent / "data"

# ──────────────────────────────────────────────────────────────────
#  CANONICAL CLASS MAP
#  Key   = the final folder name that will be used for training
#  Value = list of ALL variant folder names that map to this class
#          (including the canonical name itself)
# ──────────────────────────────────────────────────────────────────
CANONICAL_MAP = {

    # ── Apple ──
    "Apple_Scab":           ["Apple__scab", "Apple_Scab", "Apple__Apple_scab"],
    "Apple_Black_Rot":      ["Apple__black_rot", "Apple_Black_Rot", "Apple__Black_rot"],
    "Apple_Rust":           ["Apple__rust", "Apple_Rust", "Apple__Cedar_apple_rust"],
    "Apple_Healthy":        ["Apple__Healthy", "Apple_Healthy", "Apple__healthy"],
    "Apple_Rotten":         ["Apple__Rotten", "Apple_Rotten"],

    # ── Banana ──
    "Banana_Healthy":       ["Banana__Healthy", "Banana_Healthy"],
    "Banana_Rotten":        ["Banana__Rotten", "Banana_Rotten"],

    # ── Bell Pepper ──
    "BellPepper_Bacterial_Spot": ["Bellpepper__Healthy", "BellPepper_Bacterial_Spot",
                                  "Pepper__bell___Bacterial_spot", "Pepper_bell__bacterial_spot"],
    "BellPepper_Healthy":        ["Bellpepper__Healthy", "BellPepper_Healthy",
                                  "Pepper__bell___healthy", "Pepper_bell__healthy"],

    # ── Carrot ──
    "Carrot_Healthy":       ["Carrot__Healthy", "Carrot_Healthy"],
    "Carrot_Rotten":        ["Carrot__Rotten", "Carrot_Rotten"],

    # ── Cassava ──
    "Cassava_Bacterial_Blight":   ["Cassava__bacterial_blight", "Cassava_Bacterial_Blight"],
    "Cassava_Brown_Streak":       ["Cassava__brown_streak_disease", "Cassava_Brown_Streak"],
    "Cassava_Green_Mottle":       ["Cassava__green_mottle", "Cassava_Green_Mottle"],
    "Cassava_Healthy":            ["Cassava__healthy", "Cassava_Healthy"],
    "Cassava_Mosaic":             ["Cassava__mosaic_disease", "Cassava_Mosaic"],

    # ── Cherry ──
    "Cherry_Healthy":        ["Cherry__healthy", "Cherry_Healthy"],
    "Cherry_Powdery_Mildew": ["Cherry__powdery_mildew", "Cherry_Powdery_Mildew"],

    # ── Chili ──
    "Chili_Healthy":    ["Chili__healthy", "Chili_Healthy"],
    "Chili_Leaf_Curl":  ["Chili__leaf_curl"],
    "Chili_Leaf_Spot":  ["Chili__leaf_spot", "Chili_Leaf_Spot"],
    "Chili_Whitefly":   ["Chili__whitefly"],
    "Chili_Yellowish":  ["Chili__yellowish"],

    # ── Coffee ──
    "Coffee_Cercospora_Leaf_Spot": ["Coffee__cercospora_leaf_spot"],
    "Coffee_Healthy":              ["Coffee__healthy", "Coffee_Healthy"],
    "Coffee_Red_Spider_Mite":      ["Coffee__red_spider_mite", "Coffee_Red_Spider_Mite"],
    "Coffee_Rust":                 ["Coffee__rust", "Coffee_Rust"],

    # ── Corn ──
    "Corn_Common_Rust":         ["Corn___Common_Rust", "Corn__common_rust", "Corn_Common_Rust"],
    "Corn_Gray_Leaf_Spot":      ["Corn___Gray_Leaf_Spot", "Corn__gray_leaf_spot", "Corn_Gray_Leaf_Spot"],
    "Corn_Healthy":             ["Corn___Healthy", "Corn__healthy", "Corn_Healthy"],
    "Corn_Northern_Leaf_Blight":["Corn___Northern_Leaf_Blight", "Corn__northern_leaf_blight",
                                  "Corn_Northern_Leaf_Blight"],

    # ── Cucumber ──
    "Cucumber_Diseased": ["Cucumber__diseased", "Cucumber_Diseased"],
    "Cucumber_Healthy":  ["Cucumber__healthy", "Cucumber_Healthy"],
    "Cucumber_Rotten":   ["Cucumber__Rotten", "Cucumber_Rotten"],

    # ── Grape ──
    "Grape_Black_Measles": ["Grape__black_measles", "Grape_Black_Measles"],
    "Grape_Black_Rot":     ["Grape__black_rot", "Grape_Black_Rot"],
    "Grape_Healthy":       ["Grape__healthy", "Grape_Healthy"],
    "Grape_Leaf_Blight":   ["Grape__leaf_blight_(isariopsis_leaf_spot)", "Grape_Leaf_Blight"],
    "Grape_Rotten":        ["Grape__Rotten", "Grape_Rotten"],

    # ── Guava / Gauva (typo variant) ──
    "Guava_Diseased": ["Gauva__diseased", "Guava_Diseased"],
    "Guava_Healthy":  ["Gauva__healthy", "Guava__Healthy", "Guava_Healthy"],
    "Guava_Rotten":   ["Guava__Rotten", "Guava_Rotten"],

    # ── Jamun ──
    "Jamun_Diseased": ["Jamun__diseased", "Jamun_Diseased"],
    "Jamun_Healthy":  ["Jamun__healthy", "Jamun_Healthy"],

    # ── Jujube ──
    "Jujube_Healthy": ["Jujube__Healthy", "Jujube_Healthy"],
    "Jujube_Rotten":  ["Jujube__Rotten", "Jujube_Rotten"],

    # ── Lemon ──
    "Lemon_Diseased": ["Lemon__diseased"],
    "Lemon_Healthy":  ["Lemon__healthy", "Lemon_Healthy"],

    # ── Mango ──
    "Mango_Diseased": ["Mango__diseased", "Mango_Diseased"],
    "Mango_Healthy":  ["Mango__healthy", "Mango_Healthy"],
    "Mango_Rotten":   ["Mango__Rotten", "Mango_Rotten"],

    # ── Orange ──
    "Orange_Healthy": ["Orange__Healthy", "Orange_Healthy"],
    "Orange_Rotten":  ["Orange__Rotten", "Orange_Rotten"],

    # ── Peach ──
    "Peach_Bacterial_Spot": ["Peach__bacterial_spot", "Peach_Bacterial_Spot"],
    "Peach_Healthy":        ["Peach__healthy", "Peach_Healthy"],

    # ── Pomegranate ──
    "Pomegranate_Diseased": ["Pomegranate__diseased", "Pomegranate_Diseased"],
    "Pomegranate_Healthy":  ["Pomegranate__Healthy", "Pomegranate_Healthy"],
    "Pomegranate_Rotten":   ["Pomegranate__Rotten", "Pomegranate_Rotten"],

    # ── Potato ──
    "Potato_Early_Blight": ["Potato___Early_blight", "Potato__early_blight",
                             "potato_early", "Potato_Early_Blight"],
    "Potato_Late_Blight":  ["Potato___Late_Blight", "Potato__late_blight",
                             "potato_late", "Potato_Late_Blight"],
    "Potato_Healthy":      ["Potato__Healthy", "potato_healthy"],
    "Potato_Rotten":       ["Potato__Rotten", "Potato_Rotten"],

    # ── Rice ──
    "Rice_Brown_Spot":       ["Rice___Brown_Spot", "Rice__brown_spot", "Rice_Brown_Spot"],
    "Rice_Healthy":          ["Rice___Healthy", "Rice__healthy", "Rice_Healthy"],
    "Rice_Hispa":            ["Rice__hispa", "Rice_Hispa"],
    "Rice_Leaf_Blast":       ["Rice___Leaf_Blast", "Rice__leaf_blast", "Rice_Leaf_Blast"],
    "Rice_Neck_Blast":       ["Rice___Neck_Blast", "Rice__neck_blast", "Rice_Neck_Blast"],

    # ── Soybean ──
    "Soybean_Bacterial_Blight": ["Soybean__bacterial_blight"],
    "Soybean_Caterpillar":      ["Soybean__caterpillar", "Soybean_Caterpillar"],
    "Soybean_Diabrotica":       ["Soybean__diabrotica_speciosa", "Soybean_Diabrotica"],
    "Soybean_Downy_Mildew":     ["Soybean__downy_mildew"],
    "Soybean_Healthy":          ["Soybean__healthy", "Soybean_Healthy"],
    "Soybean_Mosaic_Virus":     ["Soybean__mosaic_virus"],
    "Soybean_Powdery_Mildew":   ["Soybean__powdery_mildew"],
    "Soybean_Rust":             ["Soybean__rust"],
    "Soybean_Southern_Blight":  ["Soybean__southern_blight"],

    # ── Strawberry ──
    "Strawberry_Leaf_Scorch": ["Strawberry___leaf_scorch", "Strawberry_Leaf_Scorch"],
    "Strawberry_Healthy":     ["Strawberry__healthy", "Strawberry_Healthy"],
    "Strawberry_Rotten":      ["Strawberry__Rotten", "Strawberry_Rotten"],

    # ── Sugarcane ──
    "Sugarcane_Bacterial_Blight": ["Sugarcane_Bacterial_Blight"],
    "Sugarcane_Healthy":          ["Sugarcane__healthy", "Sugarcane_Healthy"],
    "Sugarcane_Red_Rot":          ["Sugarcane__red_rot", "Sugarcane_Red_Rot"],
    "Sugarcane_Red_Stripe":       ["Sugarcane__red_stripe"],
    "Sugarcane_Rust":             ["Sugarcane__rust"],

    # ── Tea ──
    "Tea_Algal_Leaf":    ["Tea__algal_leaf", "Tea_Algal_Leaf"],
    "Tea_Anthracnose":   ["Tea__anthracnose", "Tea_Anthracnose"],
    "Tea_Bird_Eye_Spot": ["Tea__bird_eye_spot", "Tea_Bird_Eye_Spot"],
    "Tea_Brown_Blight":  ["Tea__brown_blight", "Tea_Brown_Blight"],
    "Tea_Healthy":       ["Tea__healthy", "Tea_Healthy"],
    "Tea_Red_Leaf_Spot": ["Tea__red_leaf_spot", "Tea_Red_Leaf_Spot"],

    # ── Tomato ──
    "Tomato_Bacterial_Spot":   ["Tomato__bacterial_spot", "Tomato_Bacterial_Spot"],
    "Tomato_Early_Blight":     ["Tomato__early_blight", "tomato_early", "Tomato_Early_Blight"],
    "Tomato_Healthy":          ["Tomato__healthy", "tomato_healthy", "Tomato_Healthy"],
    "Tomato_Late_Blight":      ["Tomato__late_blight", "tomato_late", "Tomato_Late_Blight"],
    "Tomato_Leaf_Mold":        ["Tomato__leaf_mold", "Tomato_Leaf_Mold"],
    "Tomato_Mosaic_Virus":     ["Tomato__mosaic_virus", "Tomato__Tomato_mosaic_virus",
                                 "Tomato_Mosaic_Virus"],
    "Tomato_Rotten":           ["Tomato__Rotten", "Tomato_Rotten"],
    "Tomato_Septoria_Leaf_Spot":["Tomato__septoria_leaf_spot", "Tomato_Septoria_Leaf_Spot"],
    "Tomato_Spider_Mites":     ["Tomato__spider_mites_(two_spotted_spider_mite)",
                                 "Tomato_Spider_Mites",
                                 "Tomato_Spider_mites_Two_spotted_spider_mite"],
    "Tomato_Target_Spot":      ["Tomato__target_spot", "Tomato_Target_Spot"],
    "Tomato_Yellow_Leaf_Curl": ["Tomato__yellow_leaf_curl_virus",
                                 "Tomato__Tomato_YellowLeaf__Curl_Virus",
                                 "Tomato_Yellow_Leaf_Curl"],

    # ── Wheat ──
    "Wheat_Brown_Rust":  ["Wheat___Brown_Rust", "Wheat__brown_rust", "Wheat_Brown_Rust"],
    "Wheat_Healthy":     ["Wheat___Healthy", "Wheat__healthy", "Wheat_Healthy"],
    "Wheat_Septoria":    ["Wheat__septoria"],
    "Wheat_Yellow_Rust": ["Wheat___Yellow_Rust", "Wheat__yellow_rust", "Wheat_Yellow_Rust"],
}


def merge_split(split: str):
    split_path = DATA_PATH / split
    if not split_path.exists():
        print(f"  ⚠️  {split_path} not found — skipping")
        return

    moved      = 0
    removed    = 0
    skipped    = 0

    for canonical, variants in CANONICAL_MAP.items():
        dest = split_path / canonical
        dest.mkdir(parents=True, exist_ok=True)

        for variant in variants:
            src = split_path / variant
            if not src.exists():
                continue
            if src == dest:
                continue  # already the canonical folder

            # Move every image from src → dest
            img_files = []
            for ext in ["*.jpg", "*.jpeg", "*.JPG", "*.JPEG", "*.png", "*.PNG"]:
                img_files.extend(src.glob(ext))

            for img in img_files:
                target = dest / img.name
                # Avoid overwrite collisions by appending variant name
                if target.exists():
                    target = dest / f"{variant}__{img.name}"
                shutil.move(str(img), str(target))
                moved += 1

            # Remove now-empty source folder
            try:
                src.rmdir()
                removed += 1
            except OSError:
                # Not empty — some non-image files remain; leave it
                skipped += 1

    # Remove any leftover folders not in the canonical map
    all_canonical = set(CANONICAL_MAP.keys())
    for folder in list(split_path.iterdir()):
        if folder.is_dir() and folder.name not in all_canonical:
            remaining = list(folder.iterdir())
            if not remaining:
                folder.rmdir()
                removed += 1
            else:
                print(f"  ⚠️  Unknown folder with files: {folder.name} "
                      f"({len(remaining)} items) — left untouched")

    print(f"  {split}: moved {moved} images, removed {removed} folders, "
          f"skipped {skipped} non-empty unknown folders")


def verify(split: str):
    split_path = DATA_PATH / split
    classes    = sorted([d.name for d in split_path.iterdir() if d.is_dir()])
    total_imgs = 0
    print(f"\n  {split.upper()} — {len(classes)} classes:")
    for cls in classes:
        imgs = (
            list((split_path / cls).glob("*.jpg"))
            + list((split_path / cls).glob("*.jpeg"))
            + list((split_path / cls).glob("*.png"))
            + list((split_path / cls).glob("*.PNG"))
        )
        print(f"    {cls:45s} : {len(imgs):5d} images")
        total_imgs += len(imgs)
    print(f"  Total images in {split}: {total_imgs}")
    return classes


if __name__ == "__main__":
    print("=" * 60)
    print("AgroSetu Dataset Cleanup")
    print("=" * 60)

    for split in ["train", "valid"]:
        print(f"\nMerging {split}/...")
        merge_split(split)

    print("\n" + "=" * 60)
    print("Verification after cleanup:")

    train_classes = verify("train")
    valid_classes = verify("valid")

    # Check train/valid have the same classes
    train_set = set(train_classes)
    valid_set = set(valid_classes)
    only_train = train_set - valid_set
    only_valid = valid_set - train_set

    print("\n" + "=" * 60)
    if only_train:
        print(f"⚠️  Classes only in train (no valid images): {only_train}")
    if only_valid:
        print(f"⚠️  Classes only in valid (no train images): {only_valid}")
    if not only_train and not only_valid:
        print("✅ Train and valid have identical class sets!")

    print(f"\n✅ Done! {len(train_classes)} canonical classes.")
    print("Next step: update DISEASE_CLASSES in train_models.py with these class names,")
    print("then run: python train_models.py")

    # Print the DISEASE_CLASSES list ready to paste into train_models.py
    print("\n" + "=" * 60)
    print("Paste this into train_models.py as DISEASE_CLASSES:\n")
    print("DISEASE_CLASSES = [")
    for cls in sorted(train_classes):
        print(f'    "{cls}",')
    print("]")
    print(f"NUM_CLASSES = {len(train_classes)}")