import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class RegisteredFace {
  final String id;
  final String name;
  final String embeddings; // JSON string of 192 floats
  final String imagePath;
  final DateTime createdAt;
  final bool isPrimary;

  RegisteredFace({
    required this.id,
    required this.name,
    required this.embeddings,
    required this.imagePath,
    required this.createdAt,
    this.isPrimary = false,
  });

  // JSON se object banao
  factory RegisteredFace.fromJson(Map<String, dynamic> json) {
    return RegisteredFace(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      embeddings: json['embeddings'] ?? '',
      imagePath: json['image_path'] ?? '',
      createdAt: json['created_at'] is DateTime
          ? json['created_at']
          : DateTime.parse(json['created_at'] ?? ''),
      isPrimary: json['is_primary'] ?? false,
    );
  }

  // Object ko JSON mein convert karo
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'embeddings': embeddings,
      'image_path': imagePath,
      'created_at': createdAt.toIso8601String(),
      'is_primary': isPrimary,
    };
  }

  // SQLite ke liye Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'embeddings': embeddings,
      'image_path': imagePath,
      'created_at': createdAt.toIso8601String(),
      'is_primary': isPrimary ? 1 : 0,
    };
  }

  // SQLite se object banao
  factory RegisteredFace.fromMap(Map<String, dynamic> map) {
    return RegisteredFace(
      id: map['id'],
      name: map['name'],
      embeddings: map['embeddings'],
      imagePath: map['image_path'],
      createdAt: DateTime.parse(map['created_at']),
      isPrimary: map['is_primary'] == 1,
    );
  }
}

class FaceDatabase {
  static final FaceDatabase _instance = FaceDatabase._internal();
  static Database? _database;

  FaceDatabase._internal();

  factory FaceDatabase() {
    return _instance;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'registered_faces.db');

    print('📁 Database path: $path');

    return openDatabase(path, version: 1, onCreate: _createTables);
  }

  Future<void> _createTables(Database db, int version) async {
    print('📋 Creating database tables...');

    // Registered faces table
    await db.execute('''
      CREATE TABLE registered_faces(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        embeddings TEXT NOT NULL,
        image_path TEXT,
        created_at TEXT NOT NULL,
        is_primary INTEGER DEFAULT 0,
        synced_at TEXT
      )
    ''');

    // Recognition history table (optional)
    await db.execute('''
      CREATE TABLE recognition_history(
        id TEXT PRIMARY KEY,
        face_id TEXT NOT NULL,
        person_name TEXT NOT NULL,
        confidence REAL NOT NULL,
        recognized_at TEXT NOT NULL,
        FOREIGN KEY(face_id) REFERENCES registered_faces(id)
      )
    ''');

    print('✅ Tables created successfully');
  }

  // ==================== REGISTERED FACES ====================

  /// Naya face add karo local database mein
  Future<void> addFace(RegisteredFace face) async {
    final db = await database;
    await db.insert(
      'registered_faces',
      face.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('✅ Face added locally: ${face.name}');
  }

  /// Multiple faces add karo (Firebase se sync karte waqt)
  Future<void> addFaces(List<RegisteredFace> faces) async {
    final db = await database;
    final batch = db.batch();

    for (var face in faces) {
      batch.insert(
        'registered_faces',
        face.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
    print('✅ ${faces.length} faces synced to local database');
  }

  /// Ek face ka embeddings nikalo
  Future<List<double>?> getFaceEmbeddings(String faceId) async {
    final db = await database;
    final result = await db.query(
      'registered_faces',
      where: 'id = ?',
      whereArgs: [faceId],
      limit: 1,
    );

    if (result.isEmpty) return null;

    final embeddingsJson = result.first['embeddings'] as String;
    return List<double>.from(
      (embeddingsJson.split(',')).map((e) => double.parse(e.trim())).toList(),
    );
  }

  /// Tamam registered faces nikalo
  Future<List<RegisteredFace>> getAllFaces() async {
    final db = await database;
    final result = await db.query('registered_faces');

    return result.map((map) => RegisteredFace.fromMap(map)).toList();
  }

  /// Ek specific face nikalo
  Future<RegisteredFace?> getFaceById(String faceId) async {
    final db = await database;
    final result = await db.query(
      'registered_faces',
      where: 'id = ?',
      whereArgs: [faceId],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return RegisteredFace.fromMap(result.first);
  }

  /// Kitne faces registered hain
  Future<int> getFacesCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM registered_faces',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Face delete karo
  Future<void> deleteFace(String faceId) async {
    final db = await database;
    await db.delete('registered_faces', where: 'id = ?', whereArgs: [faceId]);
    print('🗑️ Face deleted: $faceId');
  }

  /// Tamam faces delete karo (fresh sync ke liye)
  Future<void> deleteAllFaces() async {
    final db = await database;
    await db.delete('registered_faces');
    print('🗑️ All faces deleted from local database');
  }

  // ==================== RECOGNITION HISTORY ====================

  /// Recognition ko save karo (optional tracking)
  Future<void> saveRecognition({
    required String faceId,
    required String personName,
    required double confidence,
  }) async {
    final db = await database;
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    await db.insert('recognition_history', {
      'id': id,
      'face_id': faceId,
      'person_name': personName,
      'confidence': confidence,
      'recognized_at': DateTime.now().toIso8601String(),
    });
  }

  /// Recognition history nikalo
  Future<List<Map<String, dynamic>>> getRecognitionHistory({
    int limit = 50,
  }) async {
    final db = await database;
    return await db.query(
      'recognition_history',
      orderBy: 'recognized_at DESC',
      limit: limit,
    );
  }

  /// Database clear karo
  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('registered_faces');
    await db.delete('recognition_history');
    print('🧹 Database cleared');
  }

  /// Database close karo
  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
