import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/connectivity_provider.dart';

class ConnectivityService {
  static bool _isConnected = false;

  // Getter to access current connectivity status
  static bool get isConnected => _isConnected;

  // Method to update connectivity status
  static void setConnected(bool connected) {
    _isConnected = connected;
  }
  
  // Method to get connectivity status from provider
  static bool checkConnectivity(BuildContext context) {
    _isConnected = Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
    return _isConnected;
  }
} 