import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/entity.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/db_helper.dart';
import '../widgets/app_drawer.dart';

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
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  List<Entity> _entities = [];
  bool _isLoading = true;
  bool _isOfflineMode = false;
  String _statusMessage = ''; // Changed from _errorMessage to _statusMessage

  // Default position (Center of Bangladesh)
  final LatLng _defaultPosition = const LatLng(23.6850, 90.3563);

  @override
  void initState() {
    super.initState();
    _loadEntities();
  }

  Future<void> _loadEntities() async {
    setState(() {
      _isLoading = true;
      _markers.clear();
      _statusMessage = ''; // Clear previous status message
    });

    try {
      // Try to get entities from the server first
      print('Attempting to load entities from API...');
      try {
        final apiEntities = await _apiService.getEntities();

        if (apiEntities.isNotEmpty) {
          print('Loaded ${apiEntities.length} entities from API successfully');
          _entities = apiEntities;

          // Save to local database for offline access
          for (var entity in _entities) {
            await _dbHelper.insertEntity(entity);
          }

          setState(() {
            _isOfflineMode = false;
          });
        } else {
          print('API returned empty entity list');
          throw Exception('No entities found on server');
        }
      } catch (e) {
        print('API error, falling back to local: $e');

        // Try loading from local DB if API fails
        _entities = await _dbHelper.getEntities();

        if (_entities.isEmpty) {
          print('Local database also returned empty entity list');
        } else {
          print('Loaded ${_entities.length} entities from local database');
        }

        setState(() {
          _isOfflineMode = true;
          _statusMessage = 'Using offline data. Check your internet connection.';
        });
      }
    } catch (e) {
      print('Error loading entities: $e');
      _entities = [];
      setState(() {
        _statusMessage = 'Failed to load entities: $e';
      });
    }

    // Create markers for entities
    _createMarkers();

    setState(() {
      _isLoading = false;
    });
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
    // Check if it's a local file path (starts with '/')
    if (entity.image != null && entity.image!.startsWith('/')) {
      return Image.file(
        File(entity.image!),
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image, size: 50),
          );
        },
      );
    } else {
      // It's a remote URL
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isOfflineMode ? 'Map (Offline Mode)' : 'Map'),
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
      body: Stack(
        children: [
          _isLoading
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
          if (_statusMessage.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.7),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}