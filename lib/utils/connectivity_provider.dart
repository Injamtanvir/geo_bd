import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ConnectivityProvider with ChangeNotifier {
  bool _isOnline = false;
  late Timer _connectivityTimer;
  final ApiService _apiService = ApiService();

  bool get isOnline => _isOnline;

  ConnectivityProvider() {
    // Check connectivity immediately
    checkConnectivity();
    
    // Setup periodic connectivity check every 5 seconds
    _connectivityTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      checkConnectivity();
    });
  }

  Future<void> checkConnectivity() async {
    final wasOnline = _isOnline;
    _isOnline = await _apiService.isConnected();
    
    // Only notify if there's a change in connectivity status
    if (wasOnline != _isOnline) {
      notifyListeners();
      print('Connectivity status changed: ${_isOnline ? 'Online' : 'Offline'}');
    }
  }

  @override
  void dispose() {
    _connectivityTimer.cancel();
    super.dispose();
  }
} 