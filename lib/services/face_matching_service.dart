import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'facenet_service.dart';

class FaceMatchingService {
  final MobileFaceNetService _mobileFaceNetService = MobileFaceNetService();

  // Face matching thresholds
  static const double SIMILARITY_THRESHOLD = 0.6;
  static const double EUCLIDEAN_THRESHOLD = 0.4;

  bool get isLoaded => _mobileFaceNetService.isLoaded;

  Future<void> loadModel() async {
    await _mobileFaceNetService.loadModel();
  }

  /// Ek captured face ko tamam registered faces se match karo
  /// Returns: {matched_person_name, similarity_score, is_match}
  Future<Map<String, dynamic>> matchFaceWithRegistered(
    File capturedImage,
  ) async {
    try {
      // 1. Captured image se embeddings nikalo
      final capturedEmbeddings = await _mobileFaceNetService.generateEmbeddings(
        capturedImage,
      );

      // 2. Firestore se tamam registered faces nikalo
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'matched': false, 'error': 'User not authenticated'};
      }

      final facesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('registered_faces')
          .get();

      if (facesSnapshot.docs.isEmpty) {
        return {'matched': false, 'message': 'No registered faces found'};
      }

      // 3. Har face se compare karo
      List<Map<String, dynamic>> matches = [];

      for (var doc in facesSnapshot.docs) {
        final name = doc['name'] as String;
        final embeddingsJson = doc['embeddings'] as String;

        // JSON se embeddings convert karo
        final storedEmbeddings = List<double>.from(
          jsonDecode(embeddingsJson) as List,
        );

        // Similarity calculate karo
        final similarity = _mobileFaceNetService.calculateSimilarity(
          capturedEmbeddings,
          storedEmbeddings,
        );

        matches.add({
          'name': name,
          'similarity': similarity,
          'matched': similarity >= SIMILARITY_THRESHOLD,
          'doc_id': doc.id,
        });
      }

      // Best match nikalo
      matches.sort(
        (a, b) =>
            (b['similarity'] as double).compareTo(a['similarity'] as double),
      );
      final bestMatch = matches.first;

      return {
        'matched': bestMatch['matched'],
        'name': bestMatch['name'],
        'similarity': bestMatch['similarity'],
        'confidence': '${(bestMatch['similarity'] * 100).toStringAsFixed(1)}%',
        'all_matches': matches,
      };
    } catch (e) {
      print('❌ Error in face matching: $e');
      return {'matched': false, 'error': 'Error matching face: $e'};
    }
  }

  /// Ek captured face ko specific registered face se match karo
  Future<bool> verifyFace(File capturedImage, String registeredFaceName) async {
    try {
      final capturedEmbeddings = await _mobileFaceNetService.generateEmbeddings(
        capturedImage,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Registered face ki embeddings nikalo
      final faceDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('registered_faces')
          .where('name', isEqualTo: registeredFaceName)
          .limit(1)
          .get();

      if (faceDoc.docs.isEmpty) {
        print('❌ Registered face not found: $registeredFaceName');
        return false;
      }

      final embeddingsJson = faceDoc.docs.first['embeddings'] as String;
      final storedEmbeddings = List<double>.from(
        jsonDecode(embeddingsJson) as List,
      );

      final similarity = _mobileFaceNetService.calculateSimilarity(
        capturedEmbeddings,
        storedEmbeddings,
      );

      final isMatch = similarity >= SIMILARITY_THRESHOLD;
      print('✅ Verification result: $isMatch (similarity: $similarity)');

      return isMatch;
    } catch (e) {
      print('❌ Error verifying face: $e');
      return false;
    }
  }

  /// Registered faces ki quality ko check karo
  Future<Map<String, dynamic>> getFaceQualityMetrics(File imageFile) async {
    try {
      final embeddings = await _mobileFaceNetService.generateEmbeddings(
        imageFile,
      );

      // Embeddings ka magnitude calculate karo (quality indicator)
      double magnitude = 0.0;
      for (double val in embeddings) {
        magnitude += val * val;
      }
      magnitude = math.sqrt(magnitude);

      return {
        'quality_score': (magnitude / embeddings.length).toStringAsFixed(3),
        'embedding_magnitude': magnitude.toStringAsFixed(3),
        'is_valid': magnitude > 0,
      };
    } catch (e) {
      return {'quality_score': 0, 'error': e.toString(), 'is_valid': false};
    }
  }

  /// Tamam registered faces ko list karo similarity ke saath
  Future<List<Map<String, dynamic>>> getAllFacesWithSimilarity(
    File capturedImage,
  ) async {
    try {
      final capturedEmbeddings = await _mobileFaceNetService.generateEmbeddings(
        capturedImage,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final facesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('registered_faces')
          .get();

      List<Map<String, dynamic>> results = [];

      for (var doc in facesSnapshot.docs) {
        final name = doc['name'] as String;
        final embeddingsJson = doc['embeddings'] as String;

        final storedEmbeddings = List<double>.from(
          jsonDecode(embeddingsJson) as List,
        );

        final similarity = _mobileFaceNetService.calculateSimilarity(
          capturedEmbeddings,
          storedEmbeddings,
        );

        results.add({
          'name': name,
          'similarity': similarity,
          'confidence': '${(similarity * 100).toStringAsFixed(1)}%',
          'matched': similarity >= SIMILARITY_THRESHOLD,
        });
      }

      // Highest similarity ke hisaab se sort karo
      results.sort(
        (a, b) =>
            (b['similarity'] as double).compareTo(a['similarity'] as double),
      );

      return results;
    } catch (e) {
      print('❌ Error getting face similarities: $e');
      return [];
    }
  }

  void dispose() {
    _mobileFaceNetService.dispose();
  }
}
