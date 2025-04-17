import 'package:mongo_dart/mongo_dart.dart';
import '../models/entity.dart';
import 'auth_service.dart';

class MongoDBHelper {
  static final MongoDBHelper _instance = MongoDBHelper._internal();
  factory MongoDBHelper() => _instance;

  // My MongoDB connection URL
  final String _connectionString =
      'mongodb+srv://GeoBangladeshApp:GeoBangladeshApp123@geobangladeshapp.qty9xmu.mongodb.net/?retryWrites=true&w=majority&appName=GeoBangladeshApp';

  Db? _db;
  DbCollection? _collection;
  final AuthService _authService = AuthService();

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

  // Save entity to MongoDB with user info
  Future<ObjectId> saveEntity(Entity entity) async {
    try {
      await _ensureConnected();

      if (_collection == null) {
        throw Exception('MongoDB collection not initialized');
      }

      // Get current username
      final username = await _authService.getUsername();
      if (username == null) {
        throw Exception('User not logged in');
      }

      // Check if entity with this ID already exists for this user
      if (entity.id != null && entity.id! > 0) {
        final existingEntity = await _collection!.findOne(
          where.eq('original_id', entity.id).eq('created_by', username)
        );
        
        if (existingEntity != null) {
          // If it exists, update it instead
          await updateEntity(entity);
          return ObjectId.fromHexString(existingEntity['_id'].toHexString());
        }
      }

      // Create new entity
      final Map<String, dynamic> data = {
        'title': entity.title,
        'lat': entity.lat,
        'lon': entity.lon,
        'image': entity.image,
        'original_id': entity.id,
        'created_at': DateTime.now(),
        'created_by': username, // Add username
      };

      final result = await _collection!.insert(data);
      print('Entity saved to MongoDB by user: $username with ID: ${entity.id}');
      return result as ObjectId;
    } catch (e) {
      print('Error saving entity to MongoDB: $e');
      rethrow;
    }
  }

  // Get all entities from MongoDB for current user
  Future<List<Entity>> getEntities() async {
    try {
      await _ensureConnected();

      if (_collection == null) {
        throw Exception('MongoDB collection not initialized');
      }

      // Get current username
      final username = await _authService.getUsername();
      
      // Only get entities created by current user
      if (username == null) {
        return []; // Return empty list if not logged in
      }
      
      final query = where.eq('created_by', username);
      final List<Map<String, dynamic>> docs = await _collection!.find(query).toList();
      
      print('Fetched ${docs.length} entities from MongoDB for user: $username');

      return docs.map((doc) {
        return Entity(
          id: doc['original_id'] ?? int.parse(doc['_id'].toHexString().substring(0, 8), radix: 16),
          title: doc['title'],
          lat: doc['lat'],
          lon: doc['lon'],
          image: doc['image'],
          createdBy: doc['created_by'],
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

      // Get current username
      final username = await _authService.getUsername();
      if (username == null) {
        throw Exception('User not logged in');
      }

      final query = where
          .eq('original_id', entity.id)
          .eq('created_by', username); // Only update user's own entities

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
      print('Entity updated in MongoDB by user: $username');
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

      // Get current username
      final username = await _authService.getUsername();
      if (username == null) {
        throw Exception('User not logged in');
      }

      // Only delete user's own entities
      final query = where
          .eq('original_id', entityId)
          .eq('created_by', username);

      final result = await _collection!.remove(query);
      print('Entity deleted from MongoDB by user: $username');
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

      // Get current username
      final username = await _authService.getUsername();
      if (username == null) {
        throw Exception('User not logged in');
      }

      for (var entity in entities) {
        final existing = await _collection!.findOne(
            where.eq('original_id', entity.id).eq('created_by', username));

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