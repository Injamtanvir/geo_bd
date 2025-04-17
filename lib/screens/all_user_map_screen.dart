import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/entity.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/app_drawer.dart';

class AllUserMapScreen extends StatefulWidget {
  static const routeName = '/all-user-map';
  const AllUserMapScreen({Key? key}) : super(key: key);

  @override
  State<AllUserMapScreen> createState() => _AllUserMapScreenState();
}

class _AllUserMapScreenState extends State<AllUserMapScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  List<Entity> _entities = [];
  bool _isLoading = true;
  String _errorMessage = '';

  final LatLng _defaultPosition = const LatLng(23.6850, 90.3563); // Default to Bangladesh center

  @override
  void initState() {
    super.initState();
    _loadAllEntities();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Check if we have an entity to focus on
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Entity) {
      _focusOnEntity(args);
    }
  }

  Future<void> _loadAllEntities() async {
    setState(() {
      _isLoading = true;
      _markers.clear();
      _errorMessage = '';
    });

    try {
      final apiEntities = await _apiService.getEntities();
      
      // Filter out entities with invalid coordinates
      _entities = apiEntities.where((entity) {
        bool isValidLat = entity.lat >= -90 && entity.lat <= 90;
        bool isValidLon = entity.lon >= -180 && entity.lon <= 180;
        return isValidLat && isValidLon;
      }).toList();
      
      print('Loaded ${_entities.length} valid entities from API');
      
    } catch (e) {
      print('Error loading entities: $e');
      setState(() {
        _errorMessage = 'Failed to load entities: $e';
      });
      _entities = [];
    }

    _createMarkers();

    setState(() {
      _isLoading = false;
    });
  }

  void _createMarkers() {
    _markers.clear();

    for (var entity in _entities) {
      try {
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
            if (entity.createdBy != null) 
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Created by: ${entity.createdBy}',
                  style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 16),
            if (entity.image != null && entity.image!.isNotEmpty)
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
    if (entity.image != null && entity.image!.startsWith('/')) {
      // Local file image
      final file = File(entity.image!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
            print('Error loading local image: $error, path: ${entity.image}');
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
    else if (entity.image != null && entity.image!.isNotEmpty) {
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
              child: entity.image != null && entity.image!.startsWith('/')
                  ? Image.file(
                File(entity.image!),
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

  Future<void> _focusOnEntity(Entity entity) async {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(entity.lat, entity.lon),
          15,
        ),
      );
      
      // Create a marker for this entity if it's not already in the markers
      final markerId = MarkerId(entity.id.toString());
      if (!_markers.any((m) => m.markerId == markerId)) {
        final marker = Marker(
          markerId: markerId,
          position: LatLng(entity.lat, entity.lon),
          infoWindow: InfoWindow(
            title: entity.title,
            snippet: 'Tap for details',
            onTap: () => _showEntityDetails(entity),
          ),
        );
        
        setState(() {
          _markers.add(marker);
        });
      }
      
      // Show the entity details
      Future.delayed(Duration(milliseconds: 500), () {
        _showEntityDetails(entity);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Users Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllEntities,
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
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('All Users Map'),
                  content: const Text(
                    'This map shows entities created by all users of the application. To see only your own entities, use the "My Map" option.'
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
                        onPressed: _loadAllEntities,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
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
    );
  }
} 