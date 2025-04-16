// // import 'dart:convert';
// // import 'dart:io';
// // import 'package:http/http.dart' as http;
// // import 'package:http_parser/http_parser.dart';
// // import 'package:dio/dio.dart';
// // import '../models/entity.dart';
// //
// // class ApiService {
// //   final String baseUrl = 'https://labs.anontech.info/cse489/t3/api.php';
// //   final Dio _dio = Dio();
// //
// //   Future<List<Entity>> getEntities() async {
// //     try {
// //       final response = await http.get(Uri.parse(baseUrl));
// //
// //       if (response.statusCode == 200) {
// //         final List<dynamic> data = json.decode(response.body);
// //         return data.map((json) => Entity.fromJson(json)).toList();
// //       } else {
// //         throw Exception('Failed to load entities: ${response.statusCode}');
// //       }
// //     } catch (e) {
// //       throw Exception('Failed to load entities: $e');
// //     }
// //   }
// //
// //   Future<int> createEntity({
// //     required String title,
// //     required double lat,
// //     required double lon,
// //     required File imageFile,
// //   }) async {
// //     try {
// //       // Create form data
// //       final formData = FormData.fromMap({
// //         'title': title,
// //         'lat': lat.toString(),
// //         'lon': lon.toString(),
// //         'image': await MultipartFile.fromFile(
// //           imageFile.path,
// //           filename: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
// //           contentType: MediaType('image', 'jpeg'),
// //         ),
// //       });
// //
// //       // Send POST request
// //       final response = await _dio.post(
// //         baseUrl,
// //         data: formData,
// //         options: Options(
// //           headers: {
// //             'Content-Type': 'multipart/form-data',
// //           },
// //         ),
// //       );
// //
// //       if (response.statusCode == 200) {
// //         final Map<String, dynamic> data = response.data;
// //         return data['id'];
// //       } else {
// //         throw Exception('Failed to create entity: ${response.statusCode}');
// //       }
// //     } catch (e) {
// //       throw Exception('Failed to create entity: $e');
// //     }
// //   }
// //
// //   Future<bool> updateEntity({
// //     required int id,
// //     required String title,
// //     required double lat,
// //     required double lon,
// //     File? imageFile,
// //   }) async {
// //     try {
// //       // Create form data
// //       final Map<String, dynamic> formMap = {
// //         'id': id.toString(),
// //         'title': title,
// //         'lat': lat.toString(),
// //         'lon': lon.toString(),
// //       };
// //
// //       // Add image if provided
// //       if (imageFile != null) {
// //         formMap['image'] = await MultipartFile.fromFile(
// //           imageFile.path,
// //           filename: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
// //           contentType: MediaType('image', 'jpeg'),
// //         );
// //       }
// //
// //       final formData = FormData.fromMap(formMap);
// //
// //       // Send PUT request
// //       final response = await _dio.put(
// //         baseUrl,
// //         data: formData,
// //         options: Options(
// //           headers: {
// //             'Content-Type': 'multipart/form-data',
// //           },
// //         ),
// //       );
// //
// //       if (response.statusCode == 200) {
// //         return true;
// //       } else {
// //         throw Exception('Failed to update entity: ${response.statusCode}');
// //       }
// //     } catch (e) {
// //       throw Exception('Failed to update entity: $e');
// //     }
// //   }
// //
// //   // For the bonus: MongoDB implementation
// //   Future<void> saveEntityToMongoDB(Entity entity) async {
// //     try {
// //       final response = await http.post(
// //         Uri.parse('https://your-custom-mongodb-api-endpoint.com/entities'),
// //         headers: {'Content-Type': 'application/json'},
// //         body: json.encode(entity.toJson()),
// //       );
// //
// //       if (response.statusCode != 200 && response.statusCode != 201) {
// //         throw Exception('Failed to save entity to MongoDB');
// //       }
// //     } catch (e) {
// //       throw Exception('Failed to save entity to MongoDB: $e');
// //     }
// //   }
// // }
//
//
//
//
// import 'dart:convert';
// import 'dart:io';
// import 'package:http/http.dart' as http;
// import 'package:http_parser/http_parser.dart';
// import 'package:dio/dio.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import '../models/entity.dart';
// import 'mongodb_helper.dart';
//
// class ApiService {
//   final String baseUrl = 'https://labs.anontech.info/cse489/t3/api.php';
//   final Dio _dio = Dio();
//   final MongoDBHelper _mongoDBHelper = MongoDBHelper();
//
//   Future<bool> isConnected() async {
//     var connectivityResult = await (Connectivity().checkConnectivity());
//     if (connectivityResult == ConnectivityResult.none) {
//       return false;
//     }
//
//     try {
//       final response = await http.get(
//         Uri.parse('https://labs.anontech.info'),
//         headers: {'Connection': 'keep-alive'},
//       ).timeout(const Duration(seconds: 5));
//       return response.statusCode == 200;
//     } catch (e) {
//       return false;
//     }
//   }
//
//   Future<List<Entity>> getEntities() async {
//     try {
//       // Check connectivity
//       bool connected = await isConnected();
//
//       if (!connected) {
//         throw Exception('No internet connection');
//       }
//
//       final response = await http.get(
//         Uri.parse(baseUrl),
//         headers: {'Connection': 'keep-alive'},
//       ).timeout(const Duration(seconds: 10));
//
//       if (response.statusCode == 200) {
//         final List<dynamic> data = json.decode(response.body);
//         return data.map((json) => Entity.fromJson(json)).toList();
//       } else {
//         throw Exception('Failed to load entities: ${response.statusCode}');
//       }
//     } catch (e) {
//       // Try to also save to MongoDB as backup
//       try {
//         await _mongoDBHelper.connect();
//         final entities = await _mongoDBHelper.getEntities();
//         return entities;
//       } catch (mongoErr) {
//         // Both services failed
//         throw Exception('Failed to load entities: $e');
//       }
//     }
//   }
//
//   Future<int> createEntity({
//     required String title,
//     required double lat,
//     required double lon,
//     required File imageFile,
//   }) async {
//     try {
//       bool connected = await isConnected();
//
//       if (!connected) {
//         throw Exception('No internet connection');
//       }
//
//       // Create form data
//       final formData = FormData.fromMap({
//         'title': title,
//         'lat': lat.toString(),
//         'lon': lon.toString(),
//         'image': await MultipartFile.fromFile(
//           imageFile.path,
//           filename: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
//           contentType: MediaType('image', 'jpeg'),
//         ),
//       });
//
//       // Set more robust dio options
//       final options = Options(
//         headers: {
//           'Content-Type': 'multipart/form-data',
//           'Connection': 'keep-alive',
//         },
//         sendTimeout: const Duration(seconds: 30),
//         receiveTimeout: const Duration(seconds: 30),
//       );
//
//       // Send POST request
//       final response = await _dio.post(
//         baseUrl,
//         data: formData,
//         options: options,
//       );
//
//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = response.data;
//         int entityId = data['id'];
//
//         // Also save to MongoDB as backup
//         try {
//           final entity = Entity(
//             id: entityId,
//             title: title,
//             lat: lat,
//             lon: lon,
//             image: 'images/image_${DateTime.now().millisecondsSinceEpoch}.jpg',
//           );
//           await _mongoDBHelper.saveEntity(entity);
//         } catch (e) {
//           print('MongoDB backup failed: $e');
//         }
//
//         return entityId;
//       } else {
//         throw Exception('Failed to create entity: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error creating entity: $e');
//
//       // Try to save to MongoDB
//       try {
//         final timestamp = DateTime.now().millisecondsSinceEpoch;
//         final entity = Entity(
//           id: timestamp, // Use timestamp as temporary ID
//           title: title,
//           lat: lat,
//           lon: lon,
//           image: imageFile.path, // Store local file path for offline mode
//         );
//         await _mongoDBHelper.saveEntity(entity);
//         return timestamp;
//       } catch (mongoErr) {
//         throw Exception('Failed to create entity: $e\nMongoDB backup failed: $mongoErr');
//       }
//     }
//   }
//
//   Future<bool> updateEntity({
//     required int id,
//     required String title,
//     required double lat,
//     required double lon,
//     File? imageFile,
//   }) async {
//     try {
//       bool connected = await isConnected();
//
//       if (!connected) {
//         throw Exception('No internet connection');
//       }
//
//       // Create form data
//       final Map<String, dynamic> formMap = {
//         'id': id.toString(),
//         'title': title,
//         'lat': lat.toString(),
//         'lon': lon.toString(),
//       };
//
//       // Add image if provided
//       if (imageFile != null) {
//         formMap['image'] = await MultipartFile.fromFile(
//           imageFile.path,
//           filename: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
//           contentType: MediaType('image', 'jpeg'),
//         );
//       }
//
//       final formData = FormData.fromMap(formMap);
//
//       // Set more robust dio options
//       final options = Options(
//         headers: {
//           'Content-Type': 'multipart/form-data',
//           'Connection': 'keep-alive',
//         },
//         sendTimeout: const Duration(seconds: 30),
//         receiveTimeout: const Duration(seconds: 30),
//       );
//
//       // Send PUT request
//       final response = await _dio.put(
//         baseUrl,
//         data: formData,
//         options: options,
//       );
//
//       if (response.statusCode == 200) {
//         // Also update in MongoDB
//         try {
//           final entity = Entity(
//             id: id,
//             title: title,
//             lat: lat,
//             lon: lon,
//             image: imageFile?.path,
//           );
//           await _mongoDBHelper.updateEntity(entity);
//         } catch (e) {
//           print('MongoDB update failed: $e');
//         }
//         return true;
//       } else {
//         throw Exception('Failed to update entity: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error updating entity: $e');
//
//       // Try to update in MongoDB
//       try {
//         final entity = Entity(
//           id: id,
//           title: title,
//           lat: lat,
//           lon: lon,
//           image: imageFile?.path,
//         );
//         await _mongoDBHelper.updateEntity(entity);
//         return true;
//       } catch (mongoErr) {
//         throw Exception('Failed to update entity: $e\nMongoDB update failed: $mongoErr');
//       }
//     }
//   }
//
//   // Full image URL generator
//   String getFullImageUrl(String? imagePath) {
//     if (imagePath == null || imagePath.isEmpty) {
//       return '';
//     }
//
//     // Check if it's a local file path
//     if (imagePath.startsWith('/')) {
//       return 'file://$imagePath';
//     }
//
//     // Check if it already has the base URL
//     if (imagePath.startsWith('http')) {
//       return imagePath;
//     }
//
//     // Add the base URL
//     return 'https://labs.anontech.info/cse489/t3/$imagePath';
//   }
// }






import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:dio/dio.dart';
import '../models/entity.dart';
import 'mongodb_helper.dart';

class ApiService {
  final String baseUrl = 'https://labs.anontech.info/cse489/t3/api.php';
  final Dio _dio = Dio();
  final MongoDBHelper _mongoDBHelper = MongoDBHelper();

  Future<bool> isConnected() async {
    try {
      final response = await http.get(
        Uri.parse('https://labs.anontech.info'),
        headers: {'Connection': 'keep-alive'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Connection check error: $e');
      return false;
    }
  }

// Rest of your ApiService class remains the same
// ...





  Future<List<Entity>> getEntities() async {
    try {
      // Check connectivity
      bool connected = await isConnected();

      if (!connected) {
        throw Exception('No internet connection');
      }

      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {'Connection': 'keep-alive'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Entity.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load entities: ${response.statusCode}');
      }
    } catch (e) {
      print('API error: $e');
      // Try to also get from MongoDB as backup
      try {
        await _mongoDBHelper.connect();
        final entities = await _mongoDBHelper.getEntities();
        return entities;
      } catch (mongoErr) {
        // Both services failed
        throw Exception('Failed to load entities: $e');
      }
    }
  }

  Future<int> createEntity({
    required String title,
    required double lat,
    required double lon,
    required File imageFile,
  }) async {
    try {
      bool connected = await isConnected();

      if (!connected) {
        throw Exception('No internet connection');
      }

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

      // Set more robust dio options
      final options = Options(
        headers: {
          'Content-Type': 'multipart/form-data',
          'Connection': 'keep-alive',
        },
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      );

      // Send POST request
      final response = await _dio.post(
        baseUrl,
        data: formData,
        options: options,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        int entityId = data['id'];
        String imagePath = 'images/image_${DateTime.now().millisecondsSinceEpoch}.jpg';

        if (data.containsKey('image') && data['image'] != null) {
          imagePath = data['image'];
        }

        // Also save to MongoDB as backup
        try {
          final entity = Entity(
            id: entityId,
            title: title,
            lat: lat,
            lon: lon,
            image: imagePath,
          );
          await _mongoDBHelper.saveEntity(entity);
        } catch (e) {
          print('MongoDB backup failed: $e');
        }

        return entityId;
      } else {
        throw Exception('Failed to create entity: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating entity: $e');

      // Try to save to MongoDB
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final entity = Entity(
          id: timestamp, // Use timestamp as temporary ID
          title: title,
          lat: lat,
          lon: lon,
          image: imageFile.path, // Store local file path for offline mode
        );
        await _mongoDBHelper.saveEntity(entity);
        return timestamp;
      } catch (mongoErr) {
        throw Exception('Failed to create entity: $e\nMongoDB backup failed: $mongoErr');
      }
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
      bool connected = await isConnected();

      if (!connected) {
        throw Exception('No internet connection');
      }

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

      // Set more robust dio options
      final options = Options(
        headers: {
          'Content-Type': 'multipart/form-data',
          'Connection': 'keep-alive',
        },
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      );

      // Send PUT request
      final response = await _dio.put(
        baseUrl,
        data: formData,
        options: options,
      );

      if (response.statusCode == 200) {
        // Also update in MongoDB
        try {
          String? imagePath = null;
          if (imageFile != null) {
            imagePath = 'images/image_${DateTime.now().millisecondsSinceEpoch}.jpg';
          }

          final entity = Entity(
            id: id,
            title: title,
            lat: lat,
            lon: lon,
            image: imagePath,
          );
          await _mongoDBHelper.updateEntity(entity);
        } catch (e) {
          print('MongoDB update failed: $e');
        }
        return true;
      } else {
        throw Exception('Failed to update entity: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating entity: $e');

      // Try to update in MongoDB
      try {
        final entity = Entity(
          id: id,
          title: title,
          lat: lat,
          lon: lon,
          image: imageFile?.path,
        );
        await _mongoDBHelper.updateEntity(entity);
        return true;
      } catch (mongoErr) {
        throw Exception('Failed to update entity: $e\nMongoDB update failed: $mongoErr');
      }
    }
  }

  // Full image URL generator
  String getFullImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '';
    }

    // Check if it's a local file path
    if (imagePath.startsWith('/')) {
      return 'file://$imagePath';
    }

    // Check if it already has the base URL
    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    // Add the base URL
    return 'https://labs.anontech.info/cse489/t3/$imagePath';
  }

  // Retry mechanism for better reliability
  Future<T> _retryRequest<T>(Future<T> Function() requestFunction, {int maxRetries = 3}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await requestFunction();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          rethrow;
        }
        // Exponential backoff delay
        await Future.delayed(Duration(milliseconds: 500 * attempts * attempts));
      }
    }
    throw Exception('Max retry attempts reached');
  }
}