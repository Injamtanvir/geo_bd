import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/entity.dart';
import 'api_service.dart';
import 'db_helper.dart';
import 'mongodb_helper.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final MongoDBHelper _mongoDBHelper = MongoDBHelper();
  
  bool _isSyncing = false;
  
  SyncService._internal();
  
  bool get isSyncing => _isSyncing;
  
  /// Synchronize offline data with the API when online
  Future<bool> syncOfflineData() async {
    if (_isSyncing) {
      print('Sync already in progress, skipping...');
      return false;
    }
    
    _isSyncing = true;
    bool success = false;
    
    try {
      // Check if we're online
      final isConnected = await _apiService.isConnected();
      if (!isConnected) {
        print('Device is offline, cannot sync');
        return false;
      }
      
      print('Starting data synchronization...');
      
      // Get unsynced entities from local database
      final unsyncedEntities = await _dbHelper.getUnsyncedEntities();
      print('Found ${unsyncedEntities.length} unsynced entities');
      
      if (unsyncedEntities.isEmpty) {
        print('No unsynced entities found');
        
        // Try to sync MongoDB with latest API data
        try {
          final apiEntities = await _apiService.getEntities();
          await _mongoDBHelper.syncEntities(apiEntities);
          print('MongoDB synced with API data');
        } catch (e) {
          print('Error syncing MongoDB with API data: $e');
        }
        
        _isSyncing = false;
        return true;
      }
      
      // Sync each entity
      for (final entity in unsyncedEntities) {
        try {
          // Check if it's a new entity (negative ID) or an existing one
          if (entity.id! < 0) {
            // This is a new entity created offline
            print('Syncing new entity: ${entity.title}');
            
            // We need the image file
            if (entity.image != null && entity.image!.startsWith('/')) {
              final imageFile = File(entity.image!);
              if (await imageFile.exists()) {
                final id = await _apiService.createEntity(
                  title: entity.title,
                  lat: entity.lat,
                  lon: entity.lon,
                  imageFile: imageFile,
                );
                
                if (id > 0) {
                  print('Entity created on server with ID: $id');
                  
                  // Delete the old entity with temporary ID
                  await _dbHelper.deleteEntity(entity.id!);
                  
                  // Create a new entity with the proper ID
                  final newEntity = Entity(
                    id: id,
                    title: entity.title,
                    lat: entity.lat,
                    lon: entity.lon,
                    imageUrl: entity.imageUrl,
                    createdBy: entity.createdBy,
                    timestamp: DateTime.now().millisecondsSinceEpoch,
                  );
                  
                  // Insert into local DB as synced
                  await _dbHelper.insertEntity(newEntity);
                  
                  // Update in MongoDB
                  try {
                    await _mongoDBHelper.saveEntity(newEntity);
                  } catch (e) {
                    print('MongoDB save failed during sync: $e');
                  }
                }
              }
            }
          } else {
            // This is an existing entity that was modified offline
            print('Syncing modified entity: ${entity.title} (ID: ${entity.id})');
            
            File? imageFile;
            if (entity.image != null && entity.image!.startsWith('/')) {
              imageFile = File(entity.image!);
              if (!await imageFile.exists()) {
                imageFile = null;
              }
            }
            
            final success = await _apiService.updateEntity(
              id: entity.id!,
              title: entity.title,
              lat: entity.lat,
              lon: entity.lon,
              imageFile: imageFile,
            );
            
            if (success) {
              print('Entity updated on server');
              await _dbHelper.markAsSynced(entity.id!);
              

              try {
                await _mongoDBHelper.updateEntity(entity);
              } catch (e) {
                print('MongoDB update failed during sync: $e');
              }
            }
          }
        } catch (e) {
          print('Error syncing entity ${entity.id}: $e');
        }
      }
      
      print('Sync completed');
      success = true;
    } catch (e) {
      print('Error during sync: $e');
      success = false;
    } finally {
      _isSyncing = false;
    }
    
    return success;
  }
} 
 