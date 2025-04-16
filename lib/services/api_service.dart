import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:dio/dio.dart';
import '../models/entity.dart';

class ApiService {
  final String baseUrl = 'https://labs.anontech.info/cse489/t3/api.php';
  final Dio _dio = Dio();

  Future<List<Entity>> getEntities() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Entity.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load entities: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load entities: $e');
    }
  }

  Future<int> createEntity({
    required String title,
    required double lat,
    required double lon,
    required File imageFile,
  }) async {
    try {
      // Create form data
      final formData = FormData.fromMap({
        'title': title,
        'lat': lat.toString(),
        'lon': lon.toString(),
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      });

      // Send POST request
      final response = await _dio.post(
        baseUrl,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        return data['id'];
      } else {
        throw Exception('Failed to create entity: ${response.statusCode}');
      }
    } catch (e) {
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
      // Create form data
      final Map<String, dynamic> formMap = {
        'id': id.toString(),
        'title': title,
        'lat': lat.toString(),
        'lon': lon.toString(),
      };

      // Add image if provided
      if (imageFile != null) {
        formMap['image'] = await MultipartFile.fromFile(
          imageFile.path,
          filename: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: MediaType('image', 'jpeg'),
        );
      }

      final formData = FormData.fromMap(formMap);

      // Send PUT request
      final response = await _dio.put(
        baseUrl,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to update entity: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update entity: $e');
    }
  }

  // For the bonus: MongoDB implementation
  Future<void> saveEntityToMongoDB(Entity entity) async {
    try {
      final response = await http.post(
        Uri.parse('https://your-custom-mongodb-api-endpoint.com/entities'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(entity.toJson()),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to save entity to MongoDB');
      }
    } catch (e) {
      throw Exception('Failed to save entity to MongoDB: $e');
    }
  }
}