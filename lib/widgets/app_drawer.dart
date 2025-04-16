import 'package:flutter/material.dart';
import '../screens/map_screen.dart';
import '../screens/entity_form_screen.dart';
import '../screens/entity_list_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: const Text(
              'Geo Bangladesh App',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Map'),
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
            title: const Text('Entity List'),
            onTap: () {
              Navigator.pushReplacementNamed(context, EntityListScreen.routeName);
            },
          ),
        ],
      ),
    );
  }
}