import 'package:mongo_dart/mongo_dart.dart';
import '../models/entity.dart';

class MongoDBHelper {
  static final MongoDBHelper _instance = MongoDBHelper._internal();
  factory MongoDBHelper() => _instance;

  // My MongoDB connection URL
  final String _connectionString =
      'mongodb+srv://GeoBangladeshApp:GeoBangladeshApp123@geobangladeshapp.qty9xmu.mongodb.net/?retryWrites=true&w=majority&appName=GeoBangladeshApp';

  Db? _db;
  DbCollection? _collection;

  MongoDBHelper._internal();

  // Connecting to MongoDB
  Future<void> connect() async {
    if (_db != null && _db!.isConnected) return;

    try {
      _db = await Db.create(_connectionString);
      await _db!.open();
      _collection = _db!.collection('entities');
      print('Connected to MongoDB');
    } catch (e) {
      print('Error connecting to MongoDB: $e');
      rethrow;
    }
  }

  Future<void> _ensureConnected() async {
    if (_db == null || !_db!.isConnected) {
      await connect();
    }
  }

  Future<void> close() async {
    if (_db != null && _db!.isConnected) {
      await _db!.close();
      _db = null;
      _collection = null;
      print('Disconnected from MongoDB');
    }
  }

  // Save entity to MongoDB
  Future<ObjectId> saveEntity(Entity entity) async {
    try {
      await _ensureConnected();

      if (_collection == null) {
        throw Exception('MongoDB collection not initialized');
      }

      final Map<String, dynamic> data = {
        'title': entity.title,
        'lat': entity.lat,
        'lon': entity.lon,
        'image': entity.image,
        'original_id': entity.id,
        'created_at': DateTime.now(),
      };

      final result = await _collection!.insert(data);
      return result as ObjectId;
    } catch (e) {
      print('Error saving entity to MongoDB: $e');
      rethrow;
    }
  }

  // Get all entities from MongoDB
  Future<List<Entity>> getEntities() async {
    try {
      await _ensureConnected();

      if (_collection == null) {
        throw Exception('MongoDB collection not initialized');
      }

      final List<Map<String, dynamic>> docs = await _collection!.find().toList();

      return docs.map((doc) {
        return Entity(
          id: doc['original_id'] ?? doc['_id'].toHexString(),
          title: doc['title'],
          lat: doc['lat'],
          lon: doc['lon'],
          image: doc['image'],
        );
      }).toList();
    } catch (e) {
      print('Error fetching entities from MongoDB: $e');
      rethrow;
    }
  }

  Future<bool> updateEntity(Entity entity) async {
    try {
      await _ensureConnected();

      if (_collection == null) {
        throw Exception('MongoDB collection not initialized');
      }

      final query = where.eq('original_id', entity.id);
      final update = {
        '\$set': {
          'title': entity.title,
          'lat': entity.lat,
          'lon': entity.lon,
          if (entity.image != null) 'image': entity.image,
          'updated_at': DateTime.now(),
        }
      };

      final result = await _collection!.update(query, update);
      return result['nModified'] > 0;
    } catch (e) {
      print('Error updating entity in MongoDB: $e');
      rethrow;
    }
  }

  Future<bool> deleteEntity(int entityId) async {
    try {
      await _ensureConnected();

      if (_collection == null) {
        throw Exception('MongoDB collection not initialized');
      }

      final result = await _collection!.remove(where.eq('original_id', entityId));
      return result['n'] > 0;
    } catch (e) {
      print('Error deleting entity from MongoDB: $e');
      rethrow;
    }
  }

  Future<void> syncEntities(List<Entity> entities) async {
    try {
      await _ensureConnected();

      if (_collection == null) {
        throw Exception('MongoDB collection not initialized');
      }

      for (var entity in entities) {
        final existing = await _collection!.findOne(where.eq('original_id', entity.id));

        if (existing == null) {
          await saveEntity(entity);
        } else {
          await updateEntity(entity);
        }
      }
    } catch (e) {
      print('Error syncing entities with MongoDB: $e');
      rethrow;
    }
  }
}