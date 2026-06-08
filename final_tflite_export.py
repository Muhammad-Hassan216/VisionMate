"""YOLOv8n -> TFLite exporter (direct, no ONNX).

Runs INT8 export first; if quantization fails, falls back to FP32.
Copies the result into assets/models/yolov8n.tflite for Flutter.
"""

import os
import shutil
from ultralytics import YOLO


def main():
	os.makedirs("assets/models", exist_ok=True)

	print("=" * 60)
	print("YOLOv8n → TensorFlow Lite Export")
	print("=" * 60)

	print("📥 Loading model: yolov8n.pt")
	model = YOLO("yolov8n.pt")

	tflite_path = None

	# Try INT8 quantized export (smaller/faster). If it fails, fallback to FP32.
	try:
		print("\n🔄 Exporting (INT8 quantized, imgsz=320)...")
		tflite_path = model.export(format="tflite", imgsz=320, int8=True)
	except Exception as exc:
		print(f"⚠️ INT8 export failed, falling back to FP32. Error: {exc}")
		print("\n🔄 Exporting (FP32, imgsz=320)...")
		tflite_path = model.export(format="tflite", imgsz=320, int8=False)

	if not tflite_path or not os.path.exists(tflite_path):
		raise RuntimeError("Export failed: TFLite file not found.")

	target = "assets/models/yolov8n.tflite"
	shutil.copy(tflite_path, target)

	size_mb = os.path.getsize(target) / (1024 * 1024)

	print("\n=============================================")
	print("✅ MUBARAK HO! TFLite model taiyar hai.")
	print(f"📁 Saved: {target} ({size_mb:.2f} MB)")
	print("=============================================")


if __name__ == "__main__":
	main()