import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/app_drawer.dart';

class AllUserEntityListScreen extends StatefulWidget {
  static const routeName = '/all-user-entity-list';
  const AllUserEntityListScreen({Key? key}) : super(key: key);

  @override
  State<AllUserEntityListScreen> createState() => _AllUserEntityListScreenState();
}

class _AllUserEntityListScreenState extends State<AllUserEntityListScreen> {
  List<dynamic> _entities = [];
  bool _isLoading = true;
  String? _errorMessage;
  final String _apiUrl = 'https://labs.anontech.info/cse489/t3/api.php';
  final String _baseImageUrl = 'https://labs.anontech.info/cse489/t3/';

  @override
  void initState() {
    super.initState();
    _loadAllEntities();
  }

  Future<void> _loadAllEntities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse(_apiUrl));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is List) {
          setState(() {
            _entities = data;
          });
        } else {
          setState(() {
            _errorMessage = 'API returned unexpected data format';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load entities: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading entities: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _viewOnMap(dynamic entity) {
    try {
      final double lat = entity['lat'] is int 
          ? (entity['lat'] as int).toDouble() 
          : entity['lat'] is double ? entity['lat'] : 0.0;
          
      final double lon = entity['lon'] is int 
          ? (entity['lon'] as int).toDouble() 
          : entity['lon'] is double ? entity['lon'] : 0.0;

      // Check for valid coordinates
      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid coordinates: Lat $lat, Lon $lon'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show entity on map
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            appBar: AppBar(
              title: Text(entity['title'] ?? 'Entity Location'),
            ),
            body: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(lat, lon),
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: MarkerId(entity['id'].toString()),
                  position: LatLng(lat, lon),
                  infoWindow: InfoWindow(
                    title: entity['title'] ?? 'Unnamed Entity',
                    snippet: 'ID: ${entity['id']}',
                  ),
                ),
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              compassEnabled: true,
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error showing entity on map: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildEntityImage(dynamic entity) {
    if (entity['image'] != null && entity['image'].toString().isNotEmpty && entity['image'] != 'images/') {
      final String imageUrl = entity['image'].toString().startsWith('http')
          ? entity['image']
          : _baseImageUrl + entity['image'];
          
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        height: 100,
        width: 100,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) {
          print('Error loading image: $error, URL: $imageUrl');
          return Container(
            color: Colors.grey[300],
            height: 100,
            width: 100,
            child: const Icon(Icons.error, color: Colors.red),
          );
        },
      );
    } else {
      return Container(
        color: Colors.grey[300],
        height: 100,
        width: 100,
        child: const Icon(Icons.image_not_supported),
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
                        style: const TextStyle(fontSize: 16),
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
                  ? const Center(child: Text('No entities found'))
                  : RefreshIndicator(
                      onRefresh: _loadAllEntities,
                      child: ListView.builder(
                        itemCount: _entities.length,
                        itemBuilder: (ctx, index) {
                          final entity = _entities[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(8),
                              leading: _buildEntityImage(entity),
                              title: Text(
                                entity['title'] ?? 'Unnamed Entity',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'ID: ${entity['id']}\nLat: ${entity['lat']}, Lon: ${entity['lon']}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.map, color: Colors.blue),
                                onPressed: () => _viewOnMap(entity),
                                tooltip: 'View on Map',
                              ),
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (ctx) => Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entity['title'] ?? 'Unnamed Entity',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text('ID: ${entity['id']}'),
                                        Text('Latitude: ${entity['lat']}'),
                                        Text('Longitude: ${entity['lon']}'),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.map),
                                              label: const Text('View on Map'),
                                              onPressed: () {
                                                Navigator.pop(context);
                                                _viewOnMap(entity);
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
} 