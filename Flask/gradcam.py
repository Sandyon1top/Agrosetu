import tensorflow as tf
from tensorflow import keras
import cv2
import numpy as np
from pathlib import Path
import json

# Grad-CAM implementation for model interpretability
class GradCAM:
    def __init__(self, model, layer_name):
        self.model = model
        self.layer_name = layer_name
        self.grad_model = keras.models.Model(
            [model.inputs],
            [model.get_layer(layer_name).output, model.output]
        )
    
    def compute_heatmap(self, image, pred_index=None):
        with tf.GradientTape() as tape:
            conv_outputs, predictions = self.grad_model(image)
            if pred_index is None:
                pred_index = tf.argmax(predictions[0])
            class_channel = predictions[:, pred_index]
        
        grads = tape.gradient(class_channel, conv_outputs)
        pooled_grads = tf.reduce_mean(grads, axis=(0, 1, 2))
        
        conv_outputs = conv_outputs[0]
        heatmap = conv_outputs @ pooled_grads[..., tf.newaxis]
        heatmap = tf.squeeze(heatmap)
        
        heatmap = tf.maximum(heatmap, 0) / tf.math.reduce_max(heatmap)
        return heatmap.numpy()

def generate_gradcam_heatmap(model_path, image_path, output_path, layer_name='conv_pw_13'):
    # layer_name for MobileNetV2 final conv layer
    
    model = keras.models.load_model(model_path)
    gradcam = GradCAM(model, layer_name)
    
    img = cv2.imread(image_path)
    img_resized = cv2.resize(img, (224, 224))
    img_array = np.array(img_resized, dtype='float32') / 255.0
    img_array = np.expand_dims(img_array, axis=0)
    
    heatmap = gradcam.compute_heatmap(img_array)
    heatmap = cv2.resize(heatmap, (224, 224))
    
    heatmap_colored = cv2.applyColorMap(
        np.uint8(255 * heatmap),
        cv2.COLORMAP_JET
    )
    
    superimposed = cv2.addWeighted(img_resized, 0.6, heatmap_colored, 0.4, 0)
    
    cv2.imwrite(output_path, superimposed)
    print(f"Heatmap saved: {output_path}")
    
    return superimposed

def batch_generate_heatmaps(model_path, image_dir, output_dir, num_images=5):
    # Generate sample Grad-CAM heatmaps for report evidence
    
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    image_files = list(Path(image_dir).glob("*.jpg")) + list(Path(image_dir).glob("*.png"))
    sample_images = image_files[:num_images]
    
    for idx, image_file in enumerate(sample_images):
        output_file = output_path / f"heatmap_{idx}.jpg"
        try:
            generate_gradcam_heatmap(model_path, str(image_file), str(output_file))
        except Exception as e:
            print(f"Error processing {image_file}: {str(e)}")

if __name__ == "__main__":
    model_path = Path(__file__).parent / "models" / "mobilenet_scratch.h5"
    image_dir = Path(__file__).parent / "data" / "valid" / "potato_early"
    output_dir = Path(__file__).parent / "heatmaps"
    
    if model_path.exists() and image_dir.exists():
        batch_generate_heatmaps(str(model_path), str(image_dir), str(output_dir), num_images=5)
    else:
        print("Model or image directory not found")
        print(f"Model exists: {model_path.exists()}")
        print(f"Image dir exists: {image_dir.exists()}")
