import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/entity.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

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
        synced INTEGER DEFAULT 1
      )
    ''');
  }

  // Insert entity into local database
  Future<int> insertEntity(Entity entity, {bool synced = true}) async {
    final db = await database;
    final data = entity.toJson();
    data['synced'] = synced ? 1 : 0;

    return await db.insert(
      'entities',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all entities from local database
  Future<List<Entity>> getEntities() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('entities');

    return List.generate(maps.length, (i) {
      return Entity(
        id: maps[i]['id'],
        title: maps[i]['title'],
        lat: maps[i]['lat'],
        lon: maps[i]['lon'],
        image: maps[i]['image'],
      );
    });
  }

  // Get unsynced entities
  Future<List<Entity>> getUnsyncedEntities() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'entities',
      where: 'synced = ?',
      whereArgs: [0],
    );

    return List.generate(maps.length, (i) {
      return Entity(
        id: maps[i]['id'],
        title: maps[i]['title'],
        lat: maps[i]['lat'],
        lon: maps[i]['lon'],
        image: maps[i]['image'],
      );
    });
  }

  // Update entity in local database
  Future<int> updateEntity(Entity entity) async {
    final db = await database;
    return await db.update(
      'entities',
      entity.toJson(),
      where: 'id = ?',
      whereArgs: [entity.id],
    );
  }

  // Mark entity as synced
  Future<int> markAsSynced(int id) async {
    final db = await database;
    return await db.update(
      'entities',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete entity from local database
  Future<int> deleteEntity(int id) async {
    final db = await database;
    return await db.delete(
      'entities',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Clear all entities
  Future<void> clearEntities() async {
    final db = await database;
    await db.delete('entities');
  }
}