import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'face_database.dart';

class FirebaseToSQLiteSync {
  final FaceDatabase _faceDb = FaceDatabase();

  /// Firebase se tamam registered faces download karo aur local DB mein save karo
  Future<bool> syncFacesFromFirebase() async {
    try {
      print('🔄 Starting Firebase to SQLite sync...');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ User not authenticated');
        return false;
      }

      // Pehle apne faces check karo
      final facesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('registered_faces')
          .get();

      // Agar user hai aur guardian linked hai, to guardian ke faces bhi fetch karo
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      final String? guardianEmail = userData?['guardianEmail'];
      final bool isLinked = userData?['isLinked'] == true;

      print('👤 User role: ${userData?['role']}');
      print('🔗 Guardian linked: $isLinked, email: $guardianEmail');

      final faces = <RegisteredFace>[];

      // Apne faces add karo
      for (var doc in facesSnapshot.docs) {
        try {
          final face = RegisteredFace(
            id: doc.id,
            name: doc['name'] ?? '',
            embeddings: doc['embeddings'] ?? '',
            imagePath: doc['image_path'] ?? '',
            createdAt:
                (doc['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
            isPrimary: doc['is_primary'] ?? false,
          );
          faces.add(face);
          print('✅ Loaded (own): ${face.name}');
        } catch (e) {
          print('⚠️ Error loading own face: $e');
        }
      }

      // Agar guardian linked hai to uske faces bhi fetch karo
      if (isLinked && guardianEmail != null) {
        print('🔍 Fetching guardian faces from: $guardianEmail');

        // Guardian ka UID dhundo
        final guardianQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: guardianEmail)
            .limit(1)
            .get();

        if (guardianQuery.docs.isNotEmpty) {
          final guardianUid = guardianQuery.docs.first.id;
          print('👨‍👩‍👧 Guardian UID: $guardianUid');

          // Guardian ke registered faces fetch karo
          final guardianFaces = await FirebaseFirestore.instance
              .collection('users')
              .doc(guardianUid)
              .collection('registered_faces')
              .get();

          for (var doc in guardianFaces.docs) {
            try {
              final face = RegisteredFace(
                id: doc.id,
                name: doc['name'] ?? '',
                embeddings: doc['embeddings'] ?? '',
                imagePath: doc['image_path'] ?? '',
                createdAt:
                    (doc['created_at'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                isPrimary: doc['is_primary'] ?? false,
              );
              faces.add(face);
              print('✅ Loaded (guardian): ${face.name}');
            } catch (e) {
              print('⚠️ Error loading guardian face: $e');
            }
          }
        } else {
          print('⚠️ Guardian account not found for email: $guardianEmail');
        }
      }

      if (faces.isEmpty) {
        print('⚠️ No faces found in Firebase (own or guardian)');
        await _faceDb.deleteAllFaces();
        return true;
      }

      print('📥 Found total ${faces.length} faces');

      // Local database clear karo aur naye faces add karo
      await _faceDb.deleteAllFaces();
      await _faceDb.addFaces(faces);

      print('✅ Successfully synced ${faces.length} faces to local database');
      return true;
    } catch (e) {
      print('❌ Sync error: $e');
      return false;
    }
  }

  /// Sirf naye faces update karo (incremental sync)
  Future<bool> syncNewFaces() async {
    try {
      print('🔄 Syncing new faces...');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final facesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('registered_faces')
          .get();

      for (var doc in facesSnapshot.docs) {
        final face = RegisteredFace(
          id: doc.id,
          name: doc['name'] ?? '',
          embeddings: doc['embeddings'] ?? '',
          imagePath: doc['image_path'] ?? '',
          createdAt:
              (doc['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isPrimary: doc['is_primary'] ?? false,
        );

        await _faceDb.addFace(face);
      }

      print('✅ New faces synced');
      return true;
    } catch (e) {
      print('❌ Error: $e');
      return false;
    }
  }

  /// Local database ka status nikalo
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final localCount = await _faceDb.getFacesCount();

      int firebaseCount = 0;
      if (user != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('registered_faces')
            .get();
        firebaseCount = snapshot.docs.length;
      }

      return {
        'local_faces': localCount,
        'firebase_faces': firebaseCount,
        'is_synced': localCount == firebaseCount,
        'user_id': user?.uid,
      };
    } catch (e) {
      print('❌ Error getting sync status: $e');
      return {'error': e.toString()};
    }
  }

  /// Offline mode mein available faces
  Future<List<RegisteredFace>> getOfflineFaces() async {
    try {
      return await _faceDb.getAllFaces();
    } catch (e) {
      print('❌ Error getting offline faces: $e');
      return [];
    }
  }
}
