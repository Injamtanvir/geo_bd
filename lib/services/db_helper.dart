import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/entity.dart';
import 'auth_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;
  final AuthService _authService = AuthService();

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'geo_entities.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE entities(
      id INTEGER PRIMARY KEY,
      title TEXT NOT NULL,
      lat REAL NOT NULL,
      lon REAL NOT NULL,
      image TEXT,
      created_by TEXT,
      synced INTEGER DEFAULT 1
    )
    ''');
  }

  Future<int> insertEntity(Entity entity, {bool synced = true}) async {
    final db = await database;
    final data = entity.toJson();
    data['synced'] = synced ? 1 : 0;
    

    if (data['created_by'] == null) {
      final username = await _authService.getUsername();
      if (username != null) {
        data['created_by'] = username;
      }
    }

    final existing = await db.query(
      'entities',
      where: 'id = ?',
      whereArgs: [entity.id],
    );

    if (existing.isNotEmpty) {
      return await updateEntity(entity);
    }

    return await db.insert(
      'entities',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Entity>> getEntities() async {
    final db = await database;
    final username = await _authService.getUsername();
    
    List<Map<String, dynamic>> maps;
    
    if (username != null) {
      maps = await db.query(
        'entities',
        where: 'created_by = ?',
        whereArgs: [username],
      );
    }
    else {
      maps = await db.query('entities');
    }
    
    return List.generate(maps.length, (i) {
      return Entity(
        id: maps[i]['id'],
        title: maps[i]['title'],
        lat: maps[i]['lat'],
        lon: maps[i]['lon'],
        imageUrl: maps[i]['image'],
        createdBy: maps[i]['created_by'],
        timestamp: maps[i]['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      );
    });
  }

  Future<List<Entity>> getUnsyncedEntities() async {
    final db = await database;
    final username = await _authService.getUsername();
    
    List<Map<String, dynamic>> maps;
    
    if (username != null) {
      maps = await db.query(
        'entities',
        where: 'synced = ? AND created_by = ?',
        whereArgs: [0, username],
      );
    }
    else {
      maps = await db.query(
        'entities',
        where: 'synced = ?',
        whereArgs: [0],
      );
    }
    
    return List.generate(maps.length, (i) {
      return Entity(
        id: maps[i]['id'],
        title: maps[i]['title'],
        lat: maps[i]['lat'],
        lon: maps[i]['lon'],
        imageUrl: maps[i]['image'],
        createdBy: maps[i]['created_by'],
        timestamp: maps[i]['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      );
    });
  }

  Future<int> updateEntity(Entity entity) async {
    final db = await database;
    final data = entity.toJson();

    if (data['created_by'] == null) {
      final username = await _authService.getUsername();
      if (username != null) {
        data['created_by'] = username;
      }
    }
    
    return await db.update(
      'entities',
      data,
      where: 'id = ?',
      whereArgs: [entity.id],
    );
  }

  Future<int> markAsSynced(int id, {bool synced = true}) async {
    final db = await database;
    return await db.update(
      'entities',
      {'synced': synced ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteEntity(int id) async {
    final db = await database;
    final username = await _authService.getUsername();
    
    if (username != null) {
      // Only delete entities created by current user
      return await db.delete(
        'entities',
        where: 'id = ? AND created_by = ?',
        whereArgs: [id, username],
      );
    } else {
      // Delete entity without user check
      return await db.delete(
        'entities',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> clearEntities() async {
    final db = await database;
    await db.delete('entities');
  }
}