import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/map_screen.dart';
import '../screens/entity_form_screen.dart';
import '../screens/entity_list_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/all_user_map_screen.dart';
import '../screens/all_entity_list_screen.dart';
import '../screens/user_entity_list_screen.dart';
import '../services/auth_service.dart';
import '../utils/connectivity_provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);
    
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Geo Bangladesh App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<String?>(
                  future: AuthService().getUsername(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return Text(
                        'User: ${snapshot.data}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      );
                    } else {
                      return const Text(
                        'Not logged in',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: connectivityProvider.isOnline ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      connectivityProvider.isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.map),
                  title: const Text('My Map'),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, MapScreen.routeName);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.add_location_alt),
                  title: const Text('Add Entity'),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, EntityFormScreen.routeName);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.list),
                  title: const Text('My Entities'),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, UserEntityListScreen.routeName);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.public),
                  title: const Text('All User Map'),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, AllUserMapScreen.routeName);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.view_list),
                  title: const Text('All Entities'),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, AllEntityListScreen.routeName);
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          FutureBuilder<bool>(
            future: AuthService().isLoggedIn(),
            builder: (context, snapshot) {
              final isLoggedIn = snapshot.data ?? false;
              
              return ListTile(
                leading: Icon(isLoggedIn ? Icons.logout : Icons.login),
                title: Text(isLoggedIn ? 'Logout' : 'Login'),
                onTap: () async {
                  if (isLoggedIn) {
                    await AuthService().logout();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, AuthScreen.routeName);
                    }
                  } else {
                    Navigator.pushReplacementNamed(context, AuthScreen.routeName);
                  }
                },
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}