import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/entity.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/db_helper.dart';
import '../services/mongodb_helper.dart';
import '../services/sync_service.dart';
import '../services/event_bus.dart';
import '../utils/connectivity_provider.dart';
import '../widgets/app_drawer.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../screens/entity_form_screen.dart';
import '../screens/entity_details_screen.dart';

class MapScreen extends StatefulWidget {
  static const routeName = '/map';
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final MongoDBHelper _mongoDBHelper = MongoDBHelper();
  final SyncService _syncService = SyncService();
  final AuthService _authService = AuthService();
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  List<Entity> _entities = [];
  bool _isLoading = true;
  bool _isOfflineMode = false;
  String _statusMessage = '';
  bool _previousOnlineStatus = false;
  late StreamSubscription<EntityEvent> _entitySubscription;
  String? _currentUsername;
  String? _loadError;

  final LatLng _defaultPosition = const LatLng(23.6850, 90.3563);

  @override
  void initState() {
    super.initState();
    _checkUserAndLoadEntities();

    _entitySubscription = EventBus().entityStream.listen((event) {
      if (event.type == EventType.deleted) {
        setState(() {
          _markers.removeWhere((marker) => marker.markerId.value == event.entityId.toString());
          _entities.removeWhere((entity) => entity.id == event.entityId);
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isOnline = Provider.of<ConnectivityProvider>(context).isOnline;

    if (isOnline && !_previousOnlineStatus) {
      _syncOfflineData();
    }
    
    _previousOnlineStatus = isOnline;

    _checkUserAndLoadEntities();
  }

  @override
  void dispose() {
    _entitySubscription.cancel();
    super.dispose();
  }

  Future<void> _syncOfflineData() async {
    if (_isOfflineMode) {
      final success = await _syncService.syncOfflineData();
      if (success) {
        _loadEntities();
      }
    }
  }

  Future<void> _checkUserAndLoadEntities() async {
    final username = await _authService.getUsername();
    
    if (_currentUsername != username) {
      setState(() {
        _currentUsername = username;
      });
      
      if (username == null) {
        setState(() {
          _entities = [];
          _markers.clear();
        });
        print('User logged out. Cleared entities and markers.');
      }
      else {
        _loadEntities();
      }
    }
  }

  Future<void> _loadEntities() async {
    try {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });

      _entities.clear();
      _markers.clear();

      // First check local database for offline entities
      final localEntities = await _dbHelper.getEntities();
      if (localEntities.isNotEmpty) {
        print('Loaded ${localEntities.length} entities from local database');
        _entities.addAll(localEntities);
      }

      // Try to get entities from MongoDB if online
      final isOnline = Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
      if (isOnline) {
        try {
          final username = await _authService.getUsername();
          if (username != null) {
            final mongoEntities = await _mongoDBHelper.getEntities();
            if (mongoEntities.isNotEmpty) {
              print('Loaded ${mongoEntities.length} entities from MongoDB');
              
              final List<Entity> parsedMongoEntities = mongoEntities.map((doc) {
                try {
                  final id = doc['original_id'] ?? doc['_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
                  final name = doc['name'] ?? 'Unknown';
                  
                  double? latitude;
                  double? longitude;
                  
                  if (doc['latitude'] == null) {
                    print('Missing latitude in MongoDB entity');
                    return null;
                  }
                  
                  if (doc['longitude'] == null) {
                    print('Missing longitude in MongoDB entity');
                    return null;
                  }
                  
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
                  
                  if (latitude == null || longitude == null || 
                      latitude < -90 || latitude > 90 || 
                      longitude < -180 || longitude > 180) {
                    print('Invalid MongoDB latitude/longitude: ${doc['latitude']}, ${doc['longitude']}');
                    return null;
                  }
                  
                  String? imageUrl = doc['image_data'];
                  // If image_data is null, try alternate fields
                  if (imageUrl == null) {
                    imageUrl = doc['image_url'] ?? doc['image'] ?? null;
                  }
                  
                  // Safely access creator field with fallbacks
                  final createdBy = doc['creator'] ?? doc['created_by'] ?? '';
                  
                  // Skip entities without creator or not matching current user
                  if (createdBy.isEmpty || (username != null && createdBy != username)) {
                    print('Skipping entity not created by current user: $createdBy vs $username');
                    return null;
                  }
                  
                  return Entity(
                    id: id,
                    title: name,
                    lat: latitude,
                    lon: longitude,
                    imageUrl: imageUrl,
                    createdBy: createdBy,
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
              
              // Add MongoDB entities to our list, avoiding duplicates with local DB
              for (final entity in parsedMongoEntities) {
                if (!_entities.any((e) => e.id.toString() == entity.id.toString())) {
                  _entities.add(entity);
                }
              }
            }
          } else {
            print('No username found, skipping MongoDB entities fetch');
          }
        } catch (e) {
          print('Error loading MongoDB entities: $e');
          // Continue with just local entities
        }
      }

      // Create markers for each entity
      _createMarkers();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error in _loadEntities: $e');
      setState(() {
        _isLoading = false;
        _loadError = 'Failed to load entities: $e';
      });
    }
  }

  void _createMarkers() {
    _markers.clear();

    for (var entity in _entities) {
      try {
        print('Creating marker for entity: ${entity.title} at ${entity.lat}, ${entity.lon}');

        final marker = Marker(
          markerId: MarkerId(entity.id.toString()),
          position: LatLng(entity.lat, entity.lon),
          infoWindow: InfoWindow(
            title: entity.title,
            snippet: 'Tap for details',
            onTap: () => _showEntityDetails(entity),
          ),
        );

        _markers.add(marker);
      } catch (e) {
        print('Error creating marker for entity ${entity.id}: $e');
      }
    }

    print('Created ${_markers.length} markers');
  }

  void _showEntityDetails(Entity entity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entity.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Latitude: ${entity.lat.toStringAsFixed(6)}\nLongitude: ${entity.lon.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (entity.imageUrl != null && entity.imageUrl!.isNotEmpty)
              GestureDetector(
                onTap: () => _showFullImage(entity),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildImageWidget(entity),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(Entity entity) {
    if (entity.imageUrl != null && entity.imageUrl!.startsWith('/')) {
      return Image.file(
        File(entity.imageUrl!),
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image, size: 50),
          );
        },
      );
    }
    else {
      return CachedNetworkImage(
        imageUrl: entity.getFullImageUrl(),
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (BuildContext context, String url, Object error) {
          print('Error loading image: $error, URL: ${entity.getFullImageUrl()}');
          return const Center(
            child: Icon(Icons.error, color: Colors.red, size: 50),
          );
        },
      );
    }
  }

  void _showFullImage(Entity entity) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: Text(entity.title),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: entity.imageUrl != null && entity.imageUrl!.startsWith('/')
                  ? Image.file(
                File(entity.imageUrl!),
                fit: BoxFit.contain,
                errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                  return const Center(
                    child: Icon(Icons.error),
                  );
                },
              )
                  : CachedNetworkImage(
                imageUrl: entity.getFullImageUrl(),
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (BuildContext context, String url, Object error) {
                  return const Center(
                    child: Icon(Icons.error),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _navigateToEntityForm() async {
    // Navigate to the entity form and wait for result
    final result = await Navigator.of(context).pushNamed(EntityFormScreen.routeName);
    // If we received true as a result, refresh entities
    if (result == true) {
      _checkUserAndLoadEntities();
    }
  }

  void _navigateToEntityDetails(Entity entity) async {
    // Navigate to entity details and wait for result
    final result = await Navigator.of(context).pushNamed(
      EntityDetailsScreen.routeName,
      arguments: entity,
    );
    // If we received true as a result, refresh entities
    if (result == true) {
      _checkUserAndLoadEntities();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEntities,
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () async {
              final currentLocation = await _locationService.getCurrentLocation();
              if (currentLocation != null && _mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(currentLocation, 15),
                );
              }
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _defaultPosition,
              zoom: 7,
            ),
            markers: _markers,
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            compassEnabled: true,
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToEntityForm,
        child: const Icon(Icons.add),
        tooltip: 'Add new entity',
      ),
    );
  }
}