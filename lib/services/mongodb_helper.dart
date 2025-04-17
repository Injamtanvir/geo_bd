import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/entity.dart';
import '../utils/image_utils.dart';
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

  Future<void> connect() async{
    if (_db != null && _db!.isConnected) return;

    try{
      _db = await Db.create(_connectionString);
      await _db!.open();
      _collection = _db!.collection('entities');
      print('Connected to MongoDB');
    }
    catch (e) {
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

  Future<ObjectId?> saveEntity(Entity entity) async {
    try {
      await _ensureConnected();

      if (_collection == null || _db == null || !_db!.isConnected) {
        print('MongoDB not connected, skipping save');
        return null;
      }

      final username = await _authService.getUsername();
      if (username == null) {
        print('User not logged in, skipping MongoDB save');
        return null;
      }

      print('MongoDB save - Entity ID: ${entity.id}, Title: ${entity.title}, Creator: $username');

      try {
        if (entity.id != null && entity.id.toString().isNotEmpty) {
          final existingEntity = await _collection!.findOne(
            where.eq('original_id', entity.id.toString()).eq('creator', username)
          );
          
          if (existingEntity != null) {
            print('Entity already exists in MongoDB, updating instead: ${entity.id}');
            await updateEntity(entity);
            return existingEntity['_id'] as ObjectId;
          }
        }

        // Process the image path and convert to base64 if needed
        String? imageData;
        try {
          imageData = entity.imageUrl;
          if (imageData != null) {
            if (imageData.startsWith('/')) {
              // For local files, convert to base64
              final file = File(imageData);
              if (file.existsSync()) {
                try {
                  imageData = await ImageUtils.fileToBase64(file);
                  print('Converted local image to base64 (length: ${imageData.length})');
                } catch (e) {
                  print('Error converting image to base64: $e');
                  imageData = null;
                }
              } else {
                print('Local file does not exist: $imageData');
                imageData = null;
              }
            } else if (imageData.startsWith('https://labs.anontech.info/cse489/t3/')) {
              // If it's an API URL, download and convert
              try {
                print('Attempting to download and convert image from API: $imageData');
                final downloadedImage = await ImageUtils.downloadAndConvertToBase64(imageData);
                if (downloadedImage != null) {
                  imageData = downloadedImage;
                  print('Successfully converted API image to base64 (length: ${imageData.length})');
                } else {
                  print('Failed to download and convert API image');
                }
              } catch (e) {
                print('Error downloading image from API URL: $e');
              }
            } else if (!imageData.startsWith('http') && !imageData.startsWith('data:image') && imageData.length < 100) {
              // If it's just a filename, try to use the API URL to download and convert
              try {
                final apiBaseUrl = 'https://labs.anontech.info/cse489/t3/images';
                final url = '$apiBaseUrl/$imageData';
                print('Attempting to download and convert image from: $url');
                
                imageData = await ImageUtils.downloadAndConvertToBase64(url);
                if (imageData == null) {
                  print('Failed to download and convert image');
                } else {
                  print('Successfully converted API image to base64 (length: ${imageData.length})');
                }
              } catch (e) {
                print('Error downloading image from API: $e');
                imageData = null;
              }
            }
          }
        } catch (imageError) {
          print('Error processing image: $imageError');
          imageData = null;
        }

        // Add this entity on mongoDb
        final Map<String, dynamic> data = {
          'name': entity.title,
          'latitude': entity.lat,
          'longitude': entity.lon,
          'image_data': imageData, // Store the base64 data or URL
          'original_id': entity.id.toString(),
          'created_at': DateTime.now(),
          'creator': username,
          'created_by': username, // Ensure both fields are consistent
        };

        print('MongoDB save - Final document to insert with creator: $username');

        final result = await _collection!.insert(data);
        print('Entity saved to MongoDB by user: $username with ID: ${entity.id}, Result: $result');
        return result as ObjectId;
      } catch (dbError) {
        print('MongoDB database operation error: $dbError');
        return null;
      }
    } catch (e) {
      print('Error saving entity to MongoDB: $e');
      return null; // Return null instead of rethrowing to prevent app crashes
    }
  }

  Future<List<Map<String, dynamic>>> getEntities() async {
    try {
      await _ensureConnected();
      
      // Get the currently logged in username
      final String? username = await AuthService().getUsername();
      print('Getting entities for user: $username');
      
      if (username == null || username.isEmpty) {
        print('No user logged in, returning empty list');
        return [];
      }
      
      if (_collection == null) {
        print('MongoDB collection not initialized, returning empty list');
        return [];
      }
      
      // Filter entities by creator field
      final cursor = _collection!.find(where.eq('creator', username));
      final List<Map<String, dynamic>> entities = await cursor.toList();
      
      print('Found ${entities.length} entities for user $username in MongoDB');
      
      for (var entity in entities) {
        print('MongoDB Entity: ${entity['name']}, Creator: ${entity['creator']}, ID: ${entity['_id']}');
      }
      
      return entities;
    } catch (e) {
      print('Error fetching entities from MongoDB: $e');
      return [];
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

      print('MongoDB update - Entity ID: ${entity.id}, Title: ${entity.title}');
      
      final query = where
          .eq('original_id', entity.id)
          .eq('creator', username); // Only update user's own entities

      // Check if entity exists
      final existingEntity = await _collection!.findOne(query);
      if (existingEntity == null) {
        print('Entity not found in MongoDB: ${entity.id}');
        // If entity doesn't exist, save it instead
        await saveEntity(entity);
        return true;
      }

      // Process the image path and convert to base64 if needed
      String? imageData = entity.imageUrl;
      if (imageData != null) {
        if (imageData.startsWith('/')) {
          // For local files, convert to base64
          final file = File(imageData);
          if (file.existsSync()) {
            imageData = await ImageUtils.fileToBase64(file);
            print('Converted local image to base64 for update (length: ${imageData.length})');
          } else {
            print('Local file does not exist for update: $imageData');
            imageData = null;
          }
        } else if (!imageData.startsWith('http') && imageData.length < 100) {
          // If it's just a filename, try to use the API URL to download and convert
          try {
            final apiBaseUrl = 'https://labs.anontech.info/cse489/t3/images';
            final url = '$apiBaseUrl/$imageData';
            print('Attempting to download and convert image from: $url');
            
            imageData = await ImageUtils.downloadAndConvertToBase64(url);
            if (imageData == null) {
              print('Failed to download and convert image for update');
            } else {
              print('Successfully converted API image to base64 for update (length: ${imageData.length})');
            }
          } catch (e) {
            print('Error downloading image from API for update: $e');
            imageData = null;
          }
        }
      }

      final update = {
        '\$set': {
          'name': entity.title,
          'latitude': entity.lat,
          'longitude': entity.lon,
          if (imageData != null) 'image_data': imageData,
          'updated_at': DateTime.now(),
        }
      };

      print('MongoDB update - Updating entity for user: $username');

      final result = await _collection!.update(query, update);
      print('Entity updated in MongoDB by user: $username, Result: $result');
      
      // Get the updated entity to verify changes
      final updatedEntity = await _collection!.findOne(query);
      if (updatedEntity != null) {
        print('Updated entity in MongoDB - Name: ${updatedEntity['name']}, Creator: ${updatedEntity['creator']}');
      }
      
      return result['nModified'] > 0;
    } catch (e) {
      print('Error updating entity in MongoDB: $e');
      rethrow;
    }
  }

  Future<bool> deleteEntity(String entityId) async {
    try {
      await _ensureConnected();

      if (_collection == null) {
        throw Exception('MongoDB collection not initialized');
      }

      final username = await _authService.getUsername();
      if (username == null) {
        throw Exception('User not logged in');
      }

      final query = where
          .eq('original_id', entityId)
          .eq('creator', username);

      final result = await _collection!.remove(query);
      print('Entity deleted from MongoDB by user: $username, ID: $entityId');
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

      final username = await _authService.getUsername();
      if (username == null) {
        throw Exception('User not logged in');
      }

      for (var entity in entities) {
        final existing = await _collection!.findOne(
            where.eq('original_id', entity.id).eq('creator', username));

        if (existing == null){
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