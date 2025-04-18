import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/entity.dart';

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

  Future<List<Entity>> getEntities() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      print('API Response (GET): ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final List<Entity> entities = jsonData.map((json) => Entity.fromJson(json)).toList();
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

      request.fields['title'] = title;
      request.fields['lat'] = lat.toString();
      request.fields['lon'] = lon.toString();

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

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('API Response (POST): ${response.statusCode}, ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('id')) {
          return data['id'];
        } else {
          throw Exception('No ID returned from API');
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