import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/entity.dart';
import '../services/auth_service.dart';

// Response class to match what's expected in AllEntityListScreen
class ApiResponse {
  final List<dynamic> data;
  final String? error;

  ApiResponse({required this.data, this.error});
}

class ApiService {
  final String baseUrl = 'https://labs.anontech.info/cse489/t3/api.php';

  Future<bool> isConnected() async {
    try {
      final response = await http.get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 300;
    } on SocketException catch (e) {
      print('Network check failed - socket exception: $e');
      return false;
    } on TimeoutException catch (e) {
      print('Network check failed - timeout: $e');
      return false;
    } catch (e) {
      print('Network check failed - other error: $e');
      return false;
    }
  }

  Future<ApiResponse> getAllEntities() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      print('API Response (getAllEntities): ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        print('Fetched ${jsonData.length} entities from API');
        return ApiResponse(data: jsonData);
      } else {
        print('Failed to load entities. Status: ${response.statusCode}');
        return ApiResponse(
          data: [], 
          error: 'Failed to load entities: ${response.statusCode}'
        );
      }
    } catch (e) {
      print('Error in getAllEntities: $e');
      return ApiResponse(
        data: [],
        error: 'Network error: $e'
      );
    }
  }

  Future<List<Entity>> getEntities() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      print('API Response (GET): ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final List<Entity> entities = [];
        
        for (var item in jsonData) {
          try {
            // From the API response at https://labs.anontech.info/cse489/t3/api.php
            var entity = Entity(
              id: item['id'],
              title: item['title'] ?? '',
              lat: double.tryParse(item['lat']?.toString() ?? '') ?? 
                  double.tryParse(item['latitude']?.toString() ?? '') ?? 0.0,
              lon: double.tryParse(item['lon']?.toString() ?? '') ?? 
                  double.tryParse(item['longitude']?.toString() ?? '') ?? 0.0,
              imageUrl: item['image'],
              createdBy: item['created_by'],
              timestamp: DateTime.now().millisecondsSinceEpoch,
            );
            entities.add(entity);
          } catch (e) {
            print('Error parsing entity: $e');
          }
        }
        
        print('Parsed ${entities.length} entities from API');
        return entities;
      } else {
        print('Failed to load entities. Status: ${response.statusCode}');
        throw Exception('Failed to load entities: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getEntities: $e');
      throw Exception('Network error: $e');
    }
  }

  Future<int> createEntity({
    required String title,
    required double lat,
    required double lon,
    required File imageFile,
  }) async {
    try {
      final uri = Uri.parse(baseUrl);
      final request = http.MultipartRequest('POST', uri);

      // Use the field names expected by the API
      request.fields['title'] = title;
      request.fields['lat'] = lat.toString();
      request.fields['lon'] = lon.toString();
      // Add a created_by field if needed by the API
      request.fields['created_by'] = await AuthService().getUsername() ?? 'anonymous';

      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();

      // Get file extension
      final fileName = imageFile.path.split('/').last;
      final fileExtension = fileName.contains('.') ? fileName.split('.').last : 'jpg';

      final multipartFile = http.MultipartFile(
        'image',
        fileStream,
        fileLength,
        filename: 'image_${DateTime.now().millisecondsSinceEpoch}.$fileExtension',
        contentType: MediaType('image', fileExtension == 'png' ? 'png' : 'jpeg'),
      );

      request.files.add(multipartFile);

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('API Response (POST): ${response.statusCode}, ${response.body}');

      if (response.statusCode == 200) {
        try {
          if (response.body.isNotEmpty) {
            try {
              final Map<String, dynamic> data = json.decode(response.body);
              if (data.containsKey('id')) {
                final id = data['id'];
                if (id is int) return id;
                if (id is String) return int.parse(id);
                throw Exception('Unexpected ID type: ${id.runtimeType}');
              }
            } catch (e) {
              print('Error parsing JSON response: $e');
              // If there's an error parsing JSON, try parsing as plain text
              if (response.body.trim().isNotEmpty && int.tryParse(response.body.trim()) != null) {
                return int.parse(response.body.trim());
              }
            }
          }
          
          // If we can't parse the ID, create a temporary ID using timestamp
          return DateTime.now().millisecondsSinceEpoch;
        } catch (e) {
          print('Error getting ID from response: $e');
          // Return a timestamp-based ID as fallback
          return DateTime.now().millisecondsSinceEpoch;
        }
      } else {
        throw Exception('Failed to create entity: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      print('Error in createEntity: $e');
      throw Exception('Failed to create entity: $e');
    }
  }

  Future<bool> updateEntity({
    required int id,
    required String title,
    required double lat,
    required double lon,
    File? imageFile,
  }) async {
    try {
      final uri = Uri.parse(baseUrl);
      final request = http.MultipartRequest('PUT', uri);

      request.fields['id'] = id.toString();
      request.fields['title'] = title;
      request.fields['lat'] = lat.toString();
      request.fields['lon'] = lon.toString();

      if (imageFile != null) {
        final fileStream = http.ByteStream(imageFile.openRead());
        final fileLength = await imageFile.length();

        final multipartFile = http.MultipartFile(
          'image',
          fileStream,
          fileLength,
          filename: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: MediaType('image', 'jpeg'),
        );

        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('API Response (PUT): ${response.statusCode}, ${response.body}');

      if (response.statusCode == 200) {
        return true;
      }
      else {
        throw Exception('Failed to update entity: ${response.statusCode}, ${response.body}');
      }
    }
    catch (e) {
      print('Error in updateEntity: $e');
      throw Exception('Failed to update entity: $e');
    }
  }
}