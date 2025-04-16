import 'package:flutter/material.dart';
import '../models/entity.dart';
import '../services/api_service.dart';
import '../services/db_helper.dart';
import '../widgets/app_drawer.dart';
import '../widgets/entity_card.dart';

class EntityListScreen extends StatefulWidget {
  static const routeName = '/entity-list';

  const EntityListScreen({Key? key}) : super(key: key);

  @override
  State<EntityListScreen> createState() => _EntityListScreenState();
}

class _EntityListScreenState extends State<EntityListScreen> {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Entity> _entities = [];
  bool _isLoading = true;
  bool _isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    _loadEntities();
  }

  Future<void> _loadEntities() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _entities = await _apiService.getEntities();

      // Save to local database for offline access
      for (var entity in _entities) {
        await _dbHelper.insertEntity(entity);
      }

      setState(() {
        _isOfflineMode = false;
      });
    } catch (e) {
      print('Error loading entities: $e');
      // Fallback to local database if API fails
      _entities = await _dbHelper.getEntities();
      setState(() {
        _isOfflineMode = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Using offline data. Check your internet connection.'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteEntity(Entity entity) async {
    // Only allow deleting local entities in offline mode
    if (_isOfflineMode) {
      await _dbHelper.deleteEntity(entity.id!);

      setState(() {
        _entities.removeWhere((e) => e.id == entity.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entity deleted locally'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // In online mode, we would need a DELETE API endpoint
      // Since the API doesn't support deletion in the requirements, we'll just show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('DELETE operation not supported by the API'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isOfflineMode ? 'Entity List (Offline Mode)' : 'Entity List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEntities,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entities.isEmpty
          ? const Center(
        child: Text(
          'No entities found',
          style: TextStyle(fontSize: 18),
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadEntities,
        child: ListView.builder(
          itemCount: _entities.length,
          itemBuilder: (ctx, index) {
            final entity = _entities[index];
            return EntityCard(
              entity: entity,
              onDelete: () => _deleteEntity(entity),
            );
          },
        ),
      ),
    );
  }
}