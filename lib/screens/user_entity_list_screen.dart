import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/entity.dart';
import '../services/api_service.dart';
import '../services/db_helper.dart';
import '../services/mongodb_helper.dart';
import '../services/auth_service.dart';
import '../utils/connectivity_provider.dart';
import '../widgets/app_drawer.dart';
import 'map_screen.dart';
import 'entity_form_screen.dart';

class UserEntityListScreen extends StatefulWidget {
  static const routeName = '/user-entity-list';
  const UserEntityListScreen({Key? key}) : super(key: key);

  @override
  State<UserEntityListScreen> createState() => _UserEntityListScreenState();
}

class _UserEntityListScreenState extends State<UserEntityListScreen> {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final MongoDBHelper _mongoDBHelper = MongoDBHelper();
  final AuthService _authService = AuthService();
  List<Entity> _entities = [];
  bool _isLoading = true;
  bool _isOfflineMode = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadUserEntities();
  }

  Future<void> _loadUserEntities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final username = await _authService.getUsername();
    if (username == null) {
      setState(() {
        _errorMessage = 'You must be logged in to view your entities';
        _isLoading = false;
      });
      return;
    }

    print('Loading entities for user: $username');
    
    try {
      final isOnline = Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
      
      if (isOnline) {
        print('Online mode: Loading user entities');
        
        try {
          // First try to get entities from MongoDB (already filtered by user)
          final mongoEntitiesData = await _mongoDBHelper.getEntities();
          print('Loaded ${mongoEntitiesData.length} entities from MongoDB for user: $username');
          
          if (mongoEntitiesData.isNotEmpty) {
            // Convert Map objects to Entity objects
            _entities = mongoEntitiesData.map((doc) => Entity(
              id: doc['original_id'] ?? doc['_id'].toString(),
              title: doc['name'] ?? '',
              lat: doc['latitude'] is int ? (doc['latitude'] as int).toDouble() : (doc['latitude'] ?? 0.0),
              lon: doc['longitude'] is int ? (doc['longitude'] as int).toDouble() : (doc['longitude'] ?? 0.0),
              imageUrl: doc['image_data'],
              createdBy: doc['creator'],
              timestamp: doc['created_at'] != null 
                  ? doc['created_at'] is DateTime 
                      ? (doc['created_at'] as DateTime).millisecondsSinceEpoch 
                      : DateTime.now().millisecondsSinceEpoch
                  : DateTime.now().millisecondsSinceEpoch,
            )).toList();
            
            // Try to get entities from API to keep local DB updated
            try {
              final apiEntities = await _apiService.getEntities();
              print('Loaded ${apiEntities.length} entities from API');
              
              // For any MongoDB entity, make sure it exists in local DB
              for (var entity in _entities) {
                await _dbHelper.insertEntity(entity);
              }
            } catch (e) {
              print('API fetch failed, but using MongoDB entities: $e');
            }
          } else {
            // No MongoDB entities, we need to check the API
            final apiEntities = await _apiService.getEntities();
            print('No MongoDB entities found. Loaded ${apiEntities.length} entities from API');
            
            // Try to match by examining created_by field if available
            _entities = apiEntities.where((entity) => 
              entity.createdBy == username).toList();
              
            print('Filtered ${_entities.length} entities from API that match current user');
            
            // Save these to MongoDB for future reference
            for (var entity in _entities) {
              try {
                await _mongoDBHelper.saveEntity(entity);
              } catch (e) {
                print('Failed to save entity ${entity.id} to MongoDB: $e');
              }
              
              // Also save to local DB
              await _dbHelper.insertEntity(entity);
            }
          }

          setState(() {
            _isOfflineMode = false;
          });
          
        } catch (e) {
          print('Error loading online entities, falling back to local: $e');
          _loadLocalEntities();
        }
      } else {
        print('Offline mode detected');
        _loadLocalEntities();
      }
    } catch (e) {
      print('Error loading user entities: $e');
      setState(() {
        _errorMessage = 'Failed to load your entities: $e';
        _entities = [];
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadLocalEntities() async {
    final username = await _authService.getUsername();
    
    if (username == null) {
      print('No user logged in. Cannot load local entities.');
      setState(() {
        _entities = [];
        _isLoading = false;
        _errorMessage = 'You must be logged in to view your entities';
      });
      return;
    }
    
    print('Loading local entities for user: $username');
    
    // Try SQLite first
    try {
      _entities = await _dbHelper.getEntities();
      print('Loaded ${_entities.length} entities from local SQLite database');
      
      // If SQLite has entities, try to filter them by user
      // This depends on whether the local DB properly stores user info
      if (_entities.isNotEmpty) {
        // Check if we have user information in the entities
        final entitiesWithUser = _entities.where((e) => e.createdBy != null && e.createdBy!.isNotEmpty).toList();
        
        if (entitiesWithUser.isNotEmpty) {
          // We can filter by user
          _entities = _entities.where((e) => e.createdBy == username).toList();
          print('Filtered ${_entities.length} entities that belong to current user: $username');
        } else {
          print('Local entities do not have user information. Trying MongoDB for filtering.');
          // Try to get user entities from MongoDB for filtering
          try {
            final mongoEntitiesData = await _mongoDBHelper.getEntities();
            if (mongoEntitiesData.isNotEmpty) {
              // Convert Map objects to Entity objects
              _entities = mongoEntitiesData.map((doc) => Entity(
                id: doc['original_id'] ?? doc['_id'].toString(),
                title: doc['name'] ?? '',
                lat: doc['latitude'] is int ? (doc['latitude'] as int).toDouble() : (doc['latitude'] ?? 0.0),
                lon: doc['longitude'] is int ? (doc['longitude'] as int).toDouble() : (doc['longitude'] ?? 0.0),
                imageUrl: doc['image_data'],
                createdBy: doc['creator'],
                timestamp: doc['created_at'] != null 
                    ? doc['created_at'] is DateTime 
                        ? (doc['created_at'] as DateTime).millisecondsSinceEpoch 
                        : DateTime.now().millisecondsSinceEpoch
                    : DateTime.now().millisecondsSinceEpoch,
              )).toList();
              print('Using ${_entities.length} MongoDB entities instead of unfiltered local entities');
            }
          } catch (e) {
            print('Failed to load MongoDB entities for filtering: $e');
          }
        }
      }
    } catch (e) {
      print('SQLite load failed: $e');
      _entities = [];
    }
      
    // If still empty, try MongoDB
    if (_entities.isEmpty) {
      print('No entities in local database, trying MongoDB...');

      try {
        final mongoEntitiesData = await _mongoDBHelper.getEntities();
        
        // Convert Map objects to Entity objects
        _entities = mongoEntitiesData.map((doc) => Entity(
          id: doc['original_id'] ?? doc['_id'].toString(),
          title: doc['name'] ?? '',
          lat: doc['latitude'] is int ? (doc['latitude'] as int).toDouble() : (doc['latitude'] ?? 0.0),
          lon: doc['longitude'] is int ? (doc['longitude'] as int).toDouble() : (doc['longitude'] ?? 0.0),
          imageUrl: doc['image_data'],
          createdBy: doc['creator'],
          timestamp: doc['created_at'] != null 
              ? doc['created_at'] is DateTime 
                  ? (doc['created_at'] as DateTime).millisecondsSinceEpoch 
                  : DateTime.now().millisecondsSinceEpoch
              : DateTime.now().millisecondsSinceEpoch,
        )).toList();
        
        print('Loaded ${_entities.length} entities from MongoDB for user: $username');
      } catch (e) {
        print('MongoDB load failed: $e');
      }
    }

    setState(() {
      _isOfflineMode = true;
    });
  }

  Future<void> _deleteEntity(Entity entity) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${entity.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        setState(() {
          _isLoading = true;
        });

        final isOnline = Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
        
        if (isOnline && entity.id! > 0) {
          // Try to delete from the API first
          try {
            // API doesn't provide delete functionality, so we just remove from other sources
            print('API doesn\'t support deletion, removing from local storage only');
          } catch (e) {
            print('API deletion failed: $e');
          }
        }

        // Delete from local SQLite
        await _dbHelper.deleteEntity(entity.id!);
        
        // Delete from MongoDB
        try {
          await _mongoDBHelper.deleteEntity(entity.id!);
          print('Entity deleted from MongoDB');
        } catch (e) {
          print('MongoDB deletion failed: $e');
        }

        // Remove from local list
        setState(() {
          _entities.removeWhere((e) => e.id == entity.id);
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entity deleted successfully')),
          );
        }
      } catch (e) {
        print('Error deleting entity: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete entity: $e')),
          );
        }
      }
    }
  }

  void _editEntity(Entity entity) {
    Navigator.of(context).pushNamed(
      EntityFormScreen.routeName,
      arguments: entity,
    ).then((_) => _loadUserEntities());
  }

  Widget _buildImageWidget(Entity entity) {
    if (entity.imageUrl == null || entity.imageUrl!.isEmpty) {
      return const Center(
        child: Icon(Icons.image_not_supported, size: 50),
      );
    }
    
    // Debug information
    print('Attempting to load image for entity ${entity.id}: ${entity.imageUrl}');
    print('Full image URL: ${entity.getFullImageUrl()}');
    
    if (entity.imageUrl!.startsWith('/')) {
      // Local file image
      final file = File(entity.imageUrl!);
      print('Checking if local file exists: ${file.path}');
      
      if (file.existsSync()) {
        print('Local file exists, loading from file system');
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
            print('Error loading local image: $error, path: ${entity.imageUrl}');
            // If local file fails, try loading from network as fallback
            return _buildNetworkImage(entity);
          },
        );
      } else {
        print('Local file does not exist, trying to load from API URL');
        return _buildNetworkImage(entity);
      }
    }
    else {
      // Remote API image or images/ path
      return _buildNetworkImage(entity);
    }
  }
  
  Widget _buildNetworkImage(Entity entity) {
    final String imageUrl = entity.getFullImageUrl();
    print('Loading from network URL: $imageUrl');
    
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text('Loading...', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
      errorWidget: (BuildContext context, String url, Object error) {
        print('Error loading image from $url: $error');
        // Try one more time with a direct image constructor as a last resort
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Final error loading image: $error');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 30),
                  const SizedBox(height: 4),
                  Text('Image not found', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Entities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserEntities,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context)
            .pushNamed(EntityFormScreen.routeName)
            .then((_) => _loadUserEntities()),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadUserEntities,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _entities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'You haven\'t added any entities yet',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Entity'),
                            onPressed: () => Navigator.of(context)
                                .pushNamed(EntityFormScreen.routeName)
                                .then((_) => _loadUserEntities()),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _entities.length,
                      itemBuilder: (ctx, i) => Dismissible(
                        key: ValueKey(_entities[i].id),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Confirm Delete'),
                              content: Text('Are you sure you want to delete "${_entities[i].title}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) {
                          _deleteEntity(_entities[i]);
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          elevation: 4,
                          child: Column(
                            children: [
                              if (_entities[i].imageUrl != null && _entities[i].imageUrl!.isNotEmpty)
                                Container(
                                  height: 120,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4),
                                    ),
                                  ),
                                  child: _buildImageWidget(_entities[i]),
                                ),
                              ListTile(
                                title: Text(_entities[i].title),
                                subtitle: Text(
                                  'Lat: ${_entities[i].lat.toStringAsFixed(4)}, Lon: ${_entities[i].lon.toStringAsFixed(4)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _editEntity(_entities[i]),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _deleteEntity(_entities[i]),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.of(context).pushNamed(
                                    MapScreen.routeName,
                                    arguments: _entities[i],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }
} 