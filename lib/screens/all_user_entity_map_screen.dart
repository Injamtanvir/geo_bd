import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/entity.dart';
import '../widgets/app_drawer.dart';

class AllUserEntityMapScreen extends StatefulWidget {
  static const routeName = '/all-user-entity-map';
  const AllUserEntityMapScreen({Key? key}) : super(key: key);

  @override
  State<AllUserEntityMapScreen> createState() => _AllUserEntityMapScreenState();
}

class _AllUserEntityMapScreenState extends State<AllUserEntityMapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  List<dynamic> _entities = [];
  bool _isLoading = true;
  final String _apiUrl = 'https://labs.anontech.info/cse489/t3/api.php';
  
  final LatLng _defaultPosition = const LatLng(23.6850, 90.3563); // Default position in Bangladesh

  @override
  void initState() {
    super.initState();
    _loadAllEntities();
  }

  Future<void> _loadAllEntities() async {
    setState(() {
      _isLoading = true;
      _markers.clear();
    });

    try {
      final response = await http.get(Uri.parse(_apiUrl));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is List) {
          setState(() {
            _entities = data;
          });
          
          _createMarkers();
        } else {
          print('API returned unexpected data format');
        }
      } else {
        print('Failed to load entities: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading entities: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _createMarkers() {
    _markers.clear();

    for (var entity in _entities) {
      try {
        final double lat = entity['lat'] is int 
            ? (entity['lat'] as int).toDouble() 
            : entity['lat'] is double ? entity['lat'] : 0.0;
            
        final double lon = entity['lon'] is int 
            ? (entity['lon'] as int).toDouble() 
            : entity['lon'] is double ? entity['lon'] : 0.0;
            
        // Skip entities with invalid coordinates
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
          print('Skipping entity with invalid coordinates: ${entity['id']}, Lat: $lat, Lon: $lon');
          continue;
        }

        final marker = Marker(
          markerId: MarkerId(entity['id'].toString()),
          position: LatLng(lat, lon),
          infoWindow: InfoWindow(
            title: entity['title'] ?? 'Unnamed Entity',
            snippet: 'ID: ${entity['id']}',
          ),
        );

        _markers.add(marker);
      } catch (e) {
        print('Error creating marker for entity ${entity['id']}: $e');
      }
    }

    print('Created ${_markers.length} markers');
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Users Entity Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllEntities,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _defaultPosition,
                    zoom: 7,
                  ),
                  markers: _markers,
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Showing ${_markers.length} entities',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} 