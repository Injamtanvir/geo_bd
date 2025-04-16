import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  final Location _location = Location();
  bool _serviceEnabled = false;
  PermissionStatus? _permissionGranted;

  Future<bool> requestPermission() async {
    _serviceEnabled = await _location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _location.requestService();
      if (!_serviceEnabled) {
        return false;
      }
    }

    _permissionGranted = await _location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return false;
      }
    }

    return true;
  }

  Future<LatLng?> getCurrentLocation() async {
    try {
      final hasPermission = await requestPermission();

      if (!hasPermission) {
        return null;
      }

      final locationData = await _location.getLocation();

      if (locationData.latitude == null || locationData.longitude == null) {
        return null;
      }

      return LatLng(locationData.latitude!, locationData.longitude!);
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  // Default coordinates for Bangladesh if location is not available
  LatLng getDefaultLocation() {
    return const LatLng(23.6850, 90.3563); // Center of Bangladesh
  }
}