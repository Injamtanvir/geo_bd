import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/entity.dart';
import '../services/api_service.dart';
import '../services/mongodb_helper.dart';
import '../widgets/app_drawer.dart';
import 'map_screen.dart';
import 'all_user_map_screen.dart';

class AllEntityListScreen extends StatefulWidget {
  static const routeName = '/all-entity-list';
  const AllEntityListScreen({Key? key}) : super(key: key);

  @override
  State<AllEntityListScreen> createState() => _AllEntityListScreenState();
}

class _AllEntityListScreenState extends State<AllEntityListScreen> {
  final ApiService _apiService = ApiService();
  final MongoDBHelper _mongoDBHelper = MongoDBHelper();
  List<Entity> _entities = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAllEntities();
  }

  Future<void> _loadAllEntities() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Try to get entities from API
      final response = await _apiService.getAllEntities();
      if (response.error != null) {
        print('Error loading entities from API: ${response.error}');
        _entities = [];
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load entities: ${response.error}';
        });
        return;
      }

      if (response.data.isEmpty) {
        _entities = [];
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final List<Entity> apiEntities = response.data
          .where((entity) => 
            (entity['latitude'] != null || entity['lat'] != null) && 
            (entity['longitude'] != null || entity['lon'] != null))
          .map((entityData) {
            try {
              final id = entityData['id'];
              String title = 'Unknown';
              if (entityData['title'] != null) {
                title = entityData['title'].toString();
              } else if (entityData['name'] != null) {
                title = entityData['name'].toString();
              }
              
              double? latitude;
              if (entityData['latitude'] != null) {
                latitude = double.tryParse(entityData['latitude'].toString());
              } else if (entityData['lat'] != null) {
                latitude = double.tryParse(entityData['lat'].toString());
              }
              
              double? longitude;
              if (entityData['longitude'] != null) {
                longitude = double.tryParse(entityData['longitude'].toString());
              } else if (entityData['lon'] != null) {
                longitude = double.tryParse(entityData['lon'].toString());
              }
              
              if (latitude == null || longitude == null) {
                print('Invalid latitude/longitude for entity: $id');
                return null;
              }
              
              String? imageUrl = entityData['image'];
              if (imageUrl != null && !imageUrl.startsWith('http') && !imageUrl.startsWith('/')) {
                imageUrl = 'https://labs.anontech.info/cse489/t3/${imageUrl}';
              }
              
              return Entity(
                id: id,
                title: title,
                lat: latitude,
                lon: longitude,
                imageUrl: imageUrl,
                createdBy: entityData['created_by'],
                timestamp: DateTime.now().millisecondsSinceEpoch,
              );
            } catch (e) {
              print('Error converting entity: $e');
              return null;
            }
          })
          .where((entity) => entity != null)
          .cast<Entity>()
          .toList();
      
      _entities = apiEntities;
      
      // Also try to load entities from MongoDB for a richer view
      try {
        final mongoEntitiesData = await _mongoDBHelper.getEntities();
        if (mongoEntitiesData != null && mongoEntitiesData.isNotEmpty) {
          print('Successfully loaded ${mongoEntitiesData.length} entities from MongoDB');
          
          final List<Entity> mongoEntities = mongoEntitiesData.map((doc) {
            try {
              final id = doc['original_id'] ?? doc['_id'].toString();
              final name = doc['name'] ?? 'Unknown';
              
              double? latitude;
              double? longitude;
              
              if (doc['latitude'] is int) {
                latitude = (doc['latitude'] as int).toDouble();
              } else if (doc['latitude'] is double) {
                latitude = doc['latitude'];
              } else if (doc['latitude'] is String) {
                latitude = double.tryParse(doc['latitude']) ?? 0.0;
              }
              
              if (doc['longitude'] is int) {
                longitude = (doc['longitude'] as int).toDouble();
              } else if (doc['longitude'] is double) {
                longitude = doc['longitude'];
              } else if (doc['longitude'] is String) {
                longitude = double.tryParse(doc['longitude']) ?? 0.0;
              }
              
              if (latitude == null || longitude == null) {
                print('Invalid MongoDB latitude/longitude: ${doc['latitude']}, ${doc['longitude']}');
                return null;
              }
              
              String? imageUrl = doc['image_data'];
              // If image_data is null, try alternate fields
              if (imageUrl == null) {
                imageUrl = doc['image_url'] ?? doc['image'] ?? null;
              }
              
              return Entity(
                id: id,
                title: name,
                lat: latitude,
                lon: longitude,
                imageUrl: imageUrl,
                createdBy: doc['creator'] ?? doc['created_by'],
                timestamp: doc['created_at'] is DateTime 
                  ? doc['created_at'].millisecondsSinceEpoch 
                  : DateTime.now().millisecondsSinceEpoch,
              );
            } catch (e) {
              print('Error converting MongoDB entity: $e');
              return null;
            }
          })
          .where((entity) => entity != null)
          .cast<Entity>()
          .toList();
          
          // Merge with API entities, avoiding duplicates
          final allEntities = [..._entities];
          
          for (final mongoEntity in mongoEntities) {
            if (!allEntities.any((e) => 
                e.id.toString() == mongoEntity.id.toString() && 
                e.createdBy == mongoEntity.createdBy)) {
              allEntities.add(mongoEntity);
            }
          }
          
          _entities = allEntities;
        }
      } catch (e) {
        print('Error loading MongoDB entities: $e');
        // Continue with just API entities
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error in _loadAllEntities: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load entities: $e';
      });
    }
  }

  void _viewOnMap(Entity entity) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: Text(entity.title),
          ),
          body: Column(
            children: [
              if (entity.imageUrl != null && entity.imageUrl!.isNotEmpty)
                Container(
                  height: 200,
                  width: double.infinity,
                  child: _buildImageWidget(entity),
                ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entity.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Latitude: ${entity.lat.toStringAsFixed(6)}\nLongitude: ${entity.lon.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (entity.createdBy != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Created by: ${entity.createdBy}',
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text('View on Map'),
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AllUserMapScreen.routeName,
                          arguments: entity,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget(Entity entity) {
    if (entity.imageUrl != null && entity.imageUrl!.startsWith('/')) {
      // Local file image
      final file = File(entity.imageUrl!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
            print('Error loading local image: $error, path: ${entity.imageUrl}');
            return const Center(
              child: Icon(Icons.broken_image, size: 50),
            );
          },
        );
      } else {
        // If local file doesn't exist, try to load from API
        return CachedNetworkImage(
          imageUrl: entity.getFullImageUrl(),
          fit: BoxFit.cover,
          placeholder: (context, url) => const Center(
            child: CircularProgressIndicator(),
          ),
          errorWidget: (BuildContext context, String url, Object error) {
            print('Error loading remote image: $error, URL: ${entity.getFullImageUrl()}');
            return const Center(
              child: Icon(Icons.error, color: Colors.red, size: 50),
            );
          },
        );
      }
    }
    else if (entity.imageUrl != null && entity.imageUrl!.isNotEmpty) {
      // Remote API image
      return CachedNetworkImage(
        imageUrl: entity.getFullImageUrl(),
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (BuildContext context, String url, Object error) {
          print('Error loading remote image: $error, URL: ${entity.getFullImageUrl()}');
          return const Center(
            child: Icon(Icons.error, color: Colors.red, size: 50),
          );
        },
      );
    } else {
      return const Center(
        child: Icon(Icons.image_not_supported, size: 50),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Users Entities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllEntities,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('All Users Entities'),
                  content: const Text(
                    'This list shows entities created by all users of the application. To see only your own entities, use the "My Entities" option in the menu.'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadAllEntities,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _entities.isEmpty
                  ? const Center(
                      child: Text(
                        'No entities found.',
                        style: TextStyle(fontSize: 18),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _entities.length,
                      itemBuilder: (ctx, i) => Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        elevation: 4,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(8),
                          leading: _entities[i].imageUrl != null && _entities[i].imageUrl!.isNotEmpty
                              ? SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: _buildImageWidget(_entities[i]),
                                  ),
                                )
                              : const SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: Icon(Icons.image_not_supported),
                                ),
                          title: Text(_entities[i].title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lat: ${_entities[i].lat.toStringAsFixed(4)}, Lon: ${_entities[i].lon.toStringAsFixed(4)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (_entities[i].createdBy != null)
                                Text(
                                  'By: ${_entities[i].createdBy}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                            ],
                          ),
                          onTap: () => _viewOnMap(_entities[i]),
                        ),
                      ),
                    ),
    );
  }
} 