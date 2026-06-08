import 'dart:io'; 
import 'dart:math';
import 'dart:typed_data'; 
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class MobileFaceNetService {
  Interpreter? _interpreter;
  static const int inputSize = 112; 

  bool get isLoaded => _interpreter != null;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/mobilefacenet.tflite',
      );
      print('✅ MobileFaceNet model loaded successfully');
    } catch (e) {
      print('❌ Error loading MobileFaceNet model: $e');
      rethrow; 
    }
  }

  Future<List<double>> generateEmbeddings(File imageFile) async {
    if (_interpreter == null) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }

    try {
      final imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize image to 112x112
      image = img.copyResize(image, width: inputSize, height: inputSize);

      // Input buffer setup [1, 112, 112, 3]
      var input = Float32List(1 * inputSize * inputSize * 3);
      var buffer = Float32List.view(input.buffer);
      
      int pixelIndex = 0;
      for (var y = 0; y < inputSize; y++) {
        for (var x = 0; x < inputSize; x++) {
          final pixel = image.getPixel(x, y); // ERROR 3: getPixelSafe handles things differently in newer versions
          
          // Normalization: (pixel - 127.5) / 128.0
          buffer[pixelIndex++] = (pixel.r - 127.5) / 128.0;
          buffer[pixelIndex++] = (pixel.g - 127.5) / 128.0;
          buffer[pixelIndex++] = (pixel.b - 127.5) / 128.0;
        }
      }

      // Reshape input to [1, 112, 112, 3]
      final formattedInput = input.reshape([1, inputSize, inputSize, 3]);

      // Output buffer for 192-dimensional embeddings
      final output = Float32List(1 * 192).reshape([1, 192]);

      _interpreter!.run(formattedInput, output);

      return List<double>.from(output[0]);
    } catch (e) {
      print('❌ Error generating embeddings: $e');
      rethrow;
    }
  }

  // Cosine Similarity: Range 0 to 1
  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      throw Exception('Embeddings must have same length');
    }

    double dotProduct = 0.0;
    double magnitude1 = 0.0;
    double magnitude2 = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      magnitude1 += embedding1[i] * embedding1[i];
      magnitude2 += embedding2[i] * embedding2[i];
    }

    magnitude1 = sqrt(magnitude1);
    magnitude2 = sqrt(magnitude2);

    if (magnitude1 == 0 || magnitude2 == 0) return 0.0;

    double cosineSim = dotProduct / (magnitude1 * magnitude2);
    return ((cosineSim + 1) / 2).clamp(0.0, 1.0);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}