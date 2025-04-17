import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

class AuthService {
  final String _connectionString =
      'mongodb+srv://GeoBangladeshApp:GeoBangladeshApp123@geobangladeshapp.qty9xmu.mongodb.net/?retryWrites=true&w=majority&appName=GeoBangladeshApp';
  
  Db? _db;
  DbCollection? _collection;

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Future<void> _ensureConnected() async {
    if (_db == null || !_db!.isConnected) {
      _db = await Db.create(_connectionString);
      await _db!.open();
      _collection = _db!.collection('users');
      print('Connected to MongoDB - Auth Service');
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes); // saving the hash password in MongoDB
    return digest.toString();
  }


  Future<bool> register(String username, String password) async {
    try {
      await _ensureConnected();
      
      // Check same user id is not accepted
      final existingUser = await _collection!.findOne(where.eq('username', username));
      if (existingUser != null) {
        throw Exception('Username already exists');
      }

      final hashedPassword = _hashPassword(password);

      await _collection!.insert({
        'username': username,
        'password': hashedPassword,
        'created_at': DateTime.now(),
      });
      
      return true;
    } catch (e) {
      print('Registration error: $e');
      throw Exception('Registration failed: $e');
    }
  }

  Future<String> login(String username, String password) async {
    try {
      await _ensureConnected();

      final hashedPassword = _hashPassword(password);
      final user = await _collection!.findOne(
        where.eq('username', username).eq('password', hashedPassword)
      );
      
      if (user == null) {
        throw Exception('Invalid username or password');
      }

      final token = '${username}_${DateTime.now().millisecondsSinceEpoch}';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('username', username);
      
      return token;
    } catch (e) {
      print('Login error: $e');
      throw Exception('Login failed: $e');
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      return token != null;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      return null;
    }
  }

  Future<String?> getUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('username');
    } catch (e) {
      return null;
    }
  }

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