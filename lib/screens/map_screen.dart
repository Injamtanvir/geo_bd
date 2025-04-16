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
    });

    try {
      _entities = await _apiService.getEntities();

      // Save to local database for offline access
      for (var entity in _entities) {
        await _dbHelper.insertEntity(entity);
      }

      setState(() {
        _isOfflineMode = false;
      });
    } catch (e) {
      print('Error loading entities: $e');
      // Fallback to local database if API fails
      _entities = await _dbHelper.getEntities();
      setState(() {
        _isOfflineMode = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Using offline data. Check your internet connection.'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    // Create markers for all entities
    _createMarkers();

    setState(() {
      _isLoading = false;
    });
  }

  void _createMarkers() {
    _markers.clear();

    for (var entity in _entities) {
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
    }
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
                    child: CachedNetworkImage(
                      imageUrl: entity.getFullImageUrl(),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(Icons.error),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
              child: CachedNetworkImage(
                imageUrl: entity.getFullImageUrl(),
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.error),
                ),
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
    );
  }
}