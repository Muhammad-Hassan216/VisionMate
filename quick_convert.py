#!/usr/bin/env python3
"""
YOLOv8n for Flutter - Direct approach
"""

from ultralytics import YOLO
import os

os.makedirs('assets/models', exist_ok=True)

print("🚀 YOLOv8n conversion for Flutter")
print("=" * 50)

# Model load karo
model = YOLO('yolov8n.pt')

# ONNX export karo (TFLite se better compatibility)
print("📥 Exporting to ONNX format...")
results = model.export(format='onnx', imgsz=640)

print(f"✅ Export complete!")
print(f"📁 Model saved at: {results}")

# Copy to assets folder
import shutil
if os.path.exists(results):
    target = f"assets/models/{os.path.basename(results)}"
    shutil.copy(results, target)
    print(f"✅ Copied to assets folder: {target}")

print("\n✨ Model ready for Flutter integration!")
print("📝 Next: Use ONNX Runtime with Flutter or convert using tflite_converter")
