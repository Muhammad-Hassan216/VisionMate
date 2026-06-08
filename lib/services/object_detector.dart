import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

// Detection class holds information about detected objects in image
// Contains object type name, confidence score, and bounding box coordinates
class Detection {
  final String label; // Object class name (e.g., "person", "car", "dog")
  final double confidence; // Detection confidence score (0.0 = 0%, 1.0 = 100%)
  final double x,
      y,
      width,
      height; // Bounding box: x,y = top-left corner, width, height = box size

  Detection({
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

// ObjectDetector class uses YOLOv8 object detection model
// YOLOv8-nano: fast, lightweight model optimized for mobile devices
class ObjectDetector {
  Interpreter? _interpreter; // TensorFlow Lite interpreter (runs the model)
  List<String> _labels =
      []; // List of COCO dataset class names (person, car, cat, etc.)

  static const int inputSize = 320; // YOLOv8 input image size: 320x320 pixels
  static const double confidenceThreshold =
      0.3; // Lowered for int8 quantized model (was 0.5)
  static const double iouThreshold = 0.5; // IoU threshold for NMS suppression

  bool get isLoaded => _interpreter != null; // Check if model is ready to use

  /// Load YOLOv8 TFLite model and class labels from assets
  /// Must be called before using detectObjects()
  /// Model file: assets/models/yolov8n_int8.tflite
  /// Labels file: assets/models/labels.txt
  // Model load karo (TFLite)
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/yolov8n_int8.tflite',
      );

      final labelsData = await rootBundle.loadString(
        'assets/models/labels.txt',
      );
      _labels = labelsData
          .split('\n')
          .map((label) => label.trim()) // Remove whitespace/newlines
          .where((label) => label.isNotEmpty)
          .toList();

      print('✅ TFLite model loaded. Labels: ${_labels.length}');
    } catch (e) {
      print('❌ Error loading TFLite model: $e');
      rethrow;
    }
  }

  /// Main detection method: Find all objects in an image
  /// Input: Image object (from camera or file)
  /// Output: List of Detection objects with labels, confidence scores, and bounding box coordinates
  /// Process:
  ///   1. Resize image to 320x320
  ///   2. Normalize pixel values
  ///   3. Run YOLOv8 model inference
  ///   4. Parse output to get bounding boxes
  ///   5. Apply NMS to remove duplicate detections
  // Image ko detect karo
  Future<List<Detection>> detectObjects(img.Image image) async {
    if (_interpreter == null) {
      throw Exception('Model not loaded!');
    }

    try {
      final inputData = _preprocessImage(image);

      // Get model output tensor shape to allocate output buffer
      // Typical shape: [1, 84, 8400] where:
      // - 1 = batch size
      // - 84 = bounding box (x,y,w,h) + 80 class confidence scores
      // - 8400 = number of anchor points / predictions
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      print('🔎 TFLite outputShape: $outputShape');

      // Allocate output buffer to hold model predictions
      List<dynamic> outputData;
      if (outputShape.length == 3) {
        // YOLOv8 TFLite output format: [1, 84, 8400]
        outputData = List.generate(
          outputShape[0],
          (_) => List.generate(
            outputShape[1],
            (_) => List<double>.filled(outputShape[2], 0.0),
          ),
        );
      } else if (outputShape.length == 2) {
        outputData = List.generate(
          outputShape[0],
          (_) => List<double>.filled(outputShape[1], 0.0),
        );
      } else {
        outputData = List<double>.filled(
          outputShape.fold<int>(1, (p, e) => p * e),
          0.0,
        );
      }

      _interpreter!.run(inputData, outputData);

      print(
        '🔎 Raw output sample (first 10 values): ${outputData.take(10).toList()}',
      );

      // Step 3: Parse YOLOv8 model output from complex tensor format to readable format
      // Convert from [1, 84, 8400] to List<List<double>> format
      // Each row: [x, y, w, h, class0_prob, class1_prob, ..., class79_prob]
      List<List<double>> parsedOutput;
      if (outputShape.length == 3 &&
          outputShape[0] == 1 &&
          outputShape[1] >= 4) {
        final channels = outputShape[1];
        final anchors = outputShape[2];
        final grid = (outputData[0] as List<dynamic>).cast<List<dynamic>>();
        parsedOutput = List.generate(anchors, (j) {
          return List<double>.generate(channels, (c) {
            final v = grid[c][j];
            return v is num ? v.toDouble() : 0.0;
          });
        });
      } else if (outputShape.length == 2) {
        parsedOutput = outputData
            .map<List<double>>(
              (row) => (row as List<dynamic>)
                  .map((e) => (e as num).toDouble())
                  .toList(),
            )
            .toList();
      } else {
        parsedOutput = [];
      }

      print('🔎 Parsed anchors: ${parsedOutput.length}');
      if (parsedOutput.isNotEmpty) {
        final sample = parsedOutput.first;
        final maxScore = sample.isNotEmpty
            ? sample.sublist(4).fold<double>(0, (p, e) => e > p ? e : p)
            : 0.0;
        print(
          '🔎 First anchor max class score: ${maxScore.toStringAsFixed(3)}',
        );
      }

      final detections = _parseOutput(parsedOutput, image.width, image.height);
      final filteredDetections = _nonMaxSuppression(detections);
      print('🎯 Detections after NMS: ${filteredDetections.length}');
      return filteredDetections;
    } catch (e) {
      print('❌ Error during detection: $e');
      return [];
    }
  }

  /// Image Preprocessing for YOLOv8 model input
  /// Steps:
  ///   1. Resize image to 320x320 pixels (model requirement)
  ///   2. Normalize RGB values from 0-255 to 0.0-1.0
  ///   3. Return in NHWC format: [Batch=1, Height=320, Width=320, Channels=3]
  // Image preprocessing (Resizing aur Normalization)
  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    final resized = img.copyResize(image, width: inputSize, height: inputSize);

    // NHWC format: [1, H, W, 3] with proper float normalization
    final input = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(inputSize, (x) {
          final pixel = resized.getPixel(x, y);
          return [
            pixel.r.toDouble() / 255.0,
            pixel.g.toDouble() / 255.0,
            pixel.b.toDouble() / 255.0,
          ];
        }),
      ),
    );

    print('📸 Preprocessed: ${inputSize}x${inputSize} NHWC format');
    return input;
  }

  /// Parse YOLOv8 model output and convert to Detection objects
  /// YOLOv8 output row format: [x_center, y_center, width, height, class0, class1, ... class79]
  /// Process:
  ///   1. Extract bounding box coordinates (center x, y, width, height)
  ///   2. Find class with highest confidence
  ///   3. Filter by confidence threshold (>0.5)
  ///   4. Convert coordinates from 320x320 model space to original image size
  /// Returns: List of Detection objects with valid predictions only
  // Output parsing (YOLOv8 format)
  List<Detection> _parseOutput(
    List<List<double>> output,
    int imgWidth,
    int imgHeight,
  ) {
    List<Detection> detections = [];

    for (int i = 0; i < output.length; i++) {
      final row = output[i];
      if (row.length < 5) continue;

      // YOLOv8 tflite export: [x, y, w, h, class0, class1, ...]
      final x = row[0];
      final y = row[1];
      final w = row[2];
      final h = row[3];

      double maxConf = 0.0;
      int maxIndex = 0;
      for (int j = 4; j < row.length; j++) {
        if (row[j] > maxConf) {
          maxConf = row[j];
          maxIndex = j - 4;
        }
      }

      if (maxConf > confidenceThreshold && maxIndex < _labels.length) {
        final scaleX = imgWidth / inputSize;
        final scaleY = imgHeight / inputSize;

        detections.add(
          Detection(
            label: _labels[maxIndex],
            confidence: maxConf,
            x: (x - w / 2) * scaleX,
            y: (y - h / 2) * scaleY,
            width: w * scaleX,
            height: h * scaleY,
          ),
        );
      }
    }

    return detections;
  }

  /// Non-Maximum Suppression (NMS) - Remove overlapping bounding boxes
  /// Problem: YOLOv8 may predict multiple boxes for the same object
  /// Solution: Keep high-confidence boxes, remove low-confidence overlapping boxes
  /// Algorithm:
  ///   1. Sort detections by confidence (highest first)
  ///   2. For each detection, calculate overlap (IoU) with remaining boxes
  ///   3. If overlap > 0.5, remove the lower-confidence box
  ///   4. Return final list of non-overlapping detections
  // Non-Maximum Suppression (overlapping boxes remove)
  List<Detection> _nonMaxSuppression(List<Detection> detections) {
    // sort (high to low)
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    List<Detection> result = [];
    List<bool> suppressed = List.filled(detections.length, false);

    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;

      result.add(detections[i]);

      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;

        // IoU calculate karo
        final iou = _calculateIoU(detections[i], detections[j]);
        if (iou > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }

    return result;
  }

  /// Calculate Intersection over Union (IoU) between two bounding boxes
  /// Formula: IoU = (Intersection Area) / (Union Area)
  /// IoU Range:
  ///   - 0.0 = no overlap at all
  ///   - 0.5 = 50% overlap (NMS threshold)
  ///   - 1.0 = perfect overlap (identical boxes)
  /// Used in NMS to determine if two boxes represent same object
  // Intersection over Union calculate karo
  double _calculateIoU(Detection a, Detection b) {
    final x1 = a.x.clamp(0, double.infinity);
    final y1 = a.y.clamp(0, double.infinity);
    final x2 = (a.x + a.width).clamp(0, double.infinity);
    final y2 = (a.y + a.height).clamp(0, double.infinity);

    final x1b = b.x.clamp(0, double.infinity);
    final y1b = b.y.clamp(0, double.infinity);
    final x2b = (b.x + b.width).clamp(0, double.infinity);
    final y2b = (b.y + b.height).clamp(0, double.infinity);

    final intersectionX = (x2 < x1b || x2b < x1)
        ? 0.0
        : (x2 < x2b ? x2 : x2b) - (x1 > x1b ? x1 : x1b);
    final intersectionY = (y2 < y1b || y2b < y1)
        ? 0.0
        : (y2 < y2b ? y2 : y2b) - (y1 > y1b ? y1 : y1b);
    final intersection = intersectionX * intersectionY;

    final areaA = (x2 - x1) * (y2 - y1);
    final areaB = (x2b - x1b) * (y2b - y1b);
    final union = areaA + areaB - intersection;

    return union > 0 ? intersection / union : 0.0;
  }

  /// Cleanup and release TensorFlow Lite interpreter resources
  /// Important: Call this when ObjectDetector is no longer needed
  /// Frees ~20-50 MB of memory used by the model
  /// Should be called in State.dispose() or when camera closes
  // Cleanup
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}

// ============================================================
// OBJECTDETECTOR SUMMARY
// ============================================================
// This class provides real-time object detection using YOLOv8-Nano model
//
// KEY FEATURES:
// 1. LOADMODEL() - Load 320x320 YOLOv8 TFLite model from assets
// 2. DETECTOBJECTS() - Main method to detect objects in image:
//    - Preprocesses image (resize to 320x320, normalize RGB 0-255 to 0-1)
//    - Runs TFLite model inference
//    - Parses YOLOv8 output format [x,y,w,h, class0-79 probabilities]
//    - Applies Non-Maximum Suppression to remove duplicates
// 3. NONMAXSUPPRESSION() - Removes overlapping bounding boxes
// 4. CALCULATEIOU() - Measures overlap between two boxes (0.0-1.0)
// 5. DISPOSE() - Cleanup TFLite interpreter memory
//
// OUTPUT FORMAT:
// List<Detection> with:
//   - label: Object class name (person, car, dog, chair, etc.)
//   - confidence: Detection score 0.0-1.0 (higher = more confident)
//   - x, y: Top-left corner of bounding box (pixels)
//   - width, height: Bounding box dimensions (pixels)
//
// USAGE EXAMPLE:
// final detector = ObjectDetector();
// await detector.loadModel();
// final detections = await detector.detectObjects(cameraImage);
// detector.dispose(); // When done
// ============================================================
