import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/map_screen.dart';
import 'screens/entity_form_screen.dart';
import 'screens/entity_list_screen.dart';
import 'screens/auth_screen.dart';
import 'services/auth_service.dart';
import 'services/db_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final dbHelper = DatabaseHelper();
  await dbHelper.database;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geo Bangladesh App',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      routes: {
        MapScreen.routeName: (ctx) => const MapScreen(),
        EntityFormScreen.routeName: (ctx) => const EntityFormScreen(),
        EntityListScreen.routeName: (ctx) => const EntityListScreen(),
        AuthScreen.routeName: (ctx) => const AuthScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService().isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final isLoggedIn = snapshot.data ?? false;

        // Try to add security features using MongoDB Atlas Cluster but due to time sortage couldn't do it Properly
        return const MapScreen();
      },
    );
  }
}