import 'dart:convert';
import 'dart:io';
import 'package:flutter_application_1/services/facenet_service.dart';
import 'face_database.dart';

class OfflineRecognitionResult {
  final bool isRecognized; // Registered person hai ya nahi
  final String? personName; // Kon hai
  final double similarity; // Kitna match (0-1)
  final String? faceId; // Firebase document ID
  final String confidence; // Percentage

  OfflineRecognitionResult({
    required this.isRecognized,
    this.personName,
    required this.similarity,
    this.faceId,
    String? confidence,
  }) : confidence = confidence ?? '${(similarity * 100).toStringAsFixed(1)}%';

  @override
  String toString() {
    if (isRecognized) {
      return '✅ Recognized: $personName ($confidence)';
    } else {
      return '❌ Unknown Person (${confidence})';
    }
  }
}

class OfflineRecognitionService {
  final MobileFaceNetService _mobileNetService = MobileFaceNetService();
  final FaceDatabase _faceDb = FaceDatabase();

  // Matching threshold (balanced for accuracy)
  static const double SIMILARITY_THRESHOLD = 0.80;

  bool _isModelLoaded = false;

  /// Model initialize karo
  Future<void> initialize() async {
    try {
      if (!_isModelLoaded) {
        await _mobileNetService.loadModel();
        _isModelLoaded = true;
        print('✅ Offline recognition initialized');
      }
    } catch (e) {
      print('❌ Initialization error: $e');
      rethrow;
    }
  }

  /// Camera se captured face ko offline recognize karo
  /// Returns: Kon samna mein hai (name + bool)
  Future<OfflineRecognitionResult> recognizeOfflineFace(
    File capturedImage,
  ) async {
    try {
      if (!_isModelLoaded) {
        throw Exception('Model not initialized. Call initialize() first');
      }

      print('🔍 Starting offline recognition...');

      // 1. Captured image se embeddings nikalo
      final capturedEmbeddings = await _mobileNetService.generateEmbeddings(
        capturedImage,
      );
      print('✅ Embeddings generated from camera');

      // 2. Local database se tamam registered faces nikalo
      final registeredFaces = await _faceDb.getAllFaces();
      print('📊 Checking against ${registeredFaces.length} registered faces');

      if (registeredFaces.isEmpty) {
        print('⚠️ No registered faces found in local database');
        return OfflineRecognitionResult(
          isRecognized: false,
          similarity: 0.0,
          personName: null,
        );
      }

      // 3. Har registered face se compare karo
      double bestSimilarity = 0.0;
      RegisteredFace? bestMatch;

      for (var registeredFace in registeredFaces) {
        try {
          // Registered face ke embeddings parse karo
          final storedEmbeddings = List<double>.from(
            jsonDecode(registeredFace.embeddings) as List,
          );

          // Similarity calculate karo
          final similarity = _mobileNetService.calculateSimilarity(
            capturedEmbeddings,
            storedEmbeddings,
          );

          print(
            '📈 ${registeredFace.name}: ${(similarity * 100).toStringAsFixed(1)}%',
          );

          // Best match track karo
          if (similarity > bestSimilarity) {
            bestSimilarity = similarity;
            bestMatch = registeredFace;
          }
        } catch (e) {
          print('⚠️ Error comparing with ${registeredFace.name}: $e');
        }
      }

      // 4. Result nikalo
      if (bestSimilarity >= SIMILARITY_THRESHOLD && bestMatch != null) {
        print('✅ MATCH FOUND: ${bestMatch.name}');

        // Recognition ko save karo (optional)
        await _faceDb.saveRecognition(
          faceId: bestMatch.id,
          personName: bestMatch.name,
          confidence: bestSimilarity,
        );

        return OfflineRecognitionResult(
          isRecognized: true,
          personName: bestMatch.name,
          similarity: bestSimilarity,
          faceId: bestMatch.id,
        );
      } else {
        print('❌ NO MATCH: Unknown person');
        return OfflineRecognitionResult(
          isRecognized: false,
          similarity: bestSimilarity,
          personName: null,
        );
      }
    } catch (e) {
      print('❌ Recognition error: $e');
      rethrow;
    }
  }

  /// Multiple faces recognize karo (list return karo)
  Future<List<OfflineRecognitionResult>> recognizeMultipleFaces(
    File capturedImage,
  ) async {
    try {
      if (!_isModelLoaded) {
        throw Exception('Model not initialized');
      }

      final capturedEmbeddings = await _mobileNetService.generateEmbeddings(
        capturedImage,
      );

      final registeredFaces = await _faceDb.getAllFaces();
      final results = <OfflineRecognitionResult>[];

      for (var registeredFace in registeredFaces) {
        try {
          final storedEmbeddings = List<double>.from(
            jsonDecode(registeredFace.embeddings) as List,
          );

          final similarity = _mobileNetService.calculateSimilarity(
            capturedEmbeddings,
            storedEmbeddings,
          );

          results.add(
            OfflineRecognitionResult(
              isRecognized: similarity >= SIMILARITY_THRESHOLD,
              personName: registeredFace.name,
              similarity: similarity,
              faceId: registeredFace.id,
            ),
          );
        } catch (e) {
          print('⚠️ Error: $e');
        }
      }

      // Similarity ke hisaab se sort karo (highest first)
      results.sort((a, b) => b.similarity.compareTo(a.similarity));

      return results;
    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }

  /// Database mein recorded faces nikalo
  Future<List<RegisteredFace>> getAvailableFaces() async {
    try {
      return await _faceDb.getAllFaces();
    } catch (e) {
      print('❌ Error getting faces: $e');
      return [];
    }
  }

  /// Offline database status
  Future<Map<String, dynamic>> getDatabaseStatus() async {
    try {
      final count = await _faceDb.getFacesCount();
      final faces = await _faceDb.getAllFaces();

      return {
        'total_faces': count,
        'is_loaded': true,
        'faces': faces.map((f) => {'name': f.name, 'id': f.id}).toList(),
      };
    } catch (e) {
      return {'total_faces': 0, 'is_loaded': false, 'error': e.toString()};
    }
  }

  /// Recognized persons ka history nikalo
  Future<List<Map<String, dynamic>>> getRecognitionHistory({
    int limit = 20,
  }) async {
    try {
      return await _faceDb.getRecognitionHistory(limit: limit);
    } catch (e) {
      print('❌ Error getting history: $e');
      return [];
    }
  }

  /// Clear all data
  Future<void> clearAllData() async {
    try {
      await _faceDb.clearDatabase();
      print('🧹 Offline data cleared');
    } catch (e) {
      print('❌ Error clearing data: $e');
    }
  }

  void dispose() {
    _mobileNetService.dispose();
  }
}
