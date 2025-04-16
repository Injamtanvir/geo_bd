// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
//
// class AuthService {
//   final String baseUrl = 'https://labs.anontech.info/cse489/t3/auth.php';
//   final FlutterSecureStorage _storage = const FlutterSecureStorage();
//
//   // Register a new user
//   Future<bool> register(String username, String password) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/register'),
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode({
//           'username': username,
//           'password': password,
//         }),
//       );
//
//       if (response.statusCode == 201) {
//         return true;
//       } else {
//         final Map<String, dynamic> data = json.decode(response.body);
//         throw Exception(data['message'] ?? 'Registration failed');
//       }
//     } catch (e) {
//       throw Exception('Registration failed: $e');
//     }
//   }
//
//   // Login user
//   Future<String> login(String username, String password) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/login'),
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode({
//           'username': username,
//           'password': password,
//         }),
//       );
//
//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);
//         final String token = data['token'];
//
//         // Save token to secure storage
//         await _storage.write(key: 'auth_token', value: token);
//         await _storage.write(key: 'username', value: username);
//
//         return token;
//       } else {
//         final Map<String, dynamic> data = json.decode(response.body);
//         throw Exception(data['message'] ?? 'Login failed');
//       }
//     } catch (e) {
//       throw Exception('Login failed: $e');
//     }
//   }
//
//   // Check if user is logged in
//   Future<bool> isLoggedIn() async {
//     try {
//       final token = await _storage.read(key: 'auth_token');
//       return token != null;
//     } catch (e) {
//       return false;
//     }
//   }
//
//   // Get current user's token
//   Future<String?> getToken() async {
//     try {
//       return await _storage.read(key: 'auth_token');
//     } catch (e) {
//       return null;
//     }
//   }
//
//   // Get current username
//   Future<String?> getUsername() async {
//     try {
//       return await _storage.read(key: 'username');
//     } catch (e) {
//       return null;
//     }
//   }
//
//   // Logout user
//   Future<void> logout() async {
//     try {
//       await _storage.delete(key: 'auth_token');
//       await _storage.delete(key: 'username');
//     } catch (e) {
//       throw Exception('Logout failed: $e');
//     }
//   }
// }




import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String baseUrl = 'https://labs.anontech.info/cse489/t3/auth.php';

  // Register a new user
  Future<bool> register(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        final Map<String, dynamic> data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  // Login user
  Future<String> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String token = data['token'];

        // Save token to shared preferences instead of secure storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setString('username', username);

        return token;
      } else {
        final Map<String, dynamic> data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      return token != null;
    } catch (e) {
      return false;
    }
  }

  // Get current user's token
  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      return null;
    }
  }

  // Get current username
  Future<String?> getUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('username');
    } catch (e) {
      return null;
    }
  }

  // Logout user
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('username');
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }
}