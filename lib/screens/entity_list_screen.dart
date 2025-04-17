import 'package:flutter/material.dart';
import '../models/entity.dart';
import '../services/api_service.dart';
import '../services/db_helper.dart';
import '../services/mongodb_helper.dart';
import '../widgets/app_drawer.dart';
import '../widgets/entity_card.dart';
import '../services/event_bus.dart';

class EntityListScreen extends StatefulWidget {
  static const routeName = '/entity-list';
  const EntityListScreen({Key? key}) : super(key: key);

  @override
  State<EntityListScreen> createState() => _EntityListScreenState();
}

class _EntityListScreenState extends State<EntityListScreen> {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final MongoDBHelper _mongoDBHelper = MongoDBHelper();
  List<Entity> _entities = [];
  bool _isLoading = true;
  bool _isOfflineMode = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadEntities();
  }

  Future<void> _loadEntities() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      print('Attempting to load entities from API...');
      try {
        final apiEntities = await _apiService.getEntities();

        if (apiEntities.isNotEmpty) {
          print('Loaded ${apiEntities.length} entities from API successfully');
          _entities = apiEntities;

          for (var entity in _entities) {
            await _dbHelper.insertEntity(entity);
          }

          try {
            await _mongoDBHelper.syncEntities(_entities);
            print('Entities synced with MongoDB');
          } catch (e) {
            print('MongoDB sync failed: $e');
          }

          setState(() {
            _isOfflineMode = false;
          });
        } else {
          print('API returned empty entity list');

          try {
            _entities = await _mongoDBHelper.getEntities();
            print('Loaded ${_entities.length} entities from MongoDB');
          } catch (e) {
            print('MongoDB load failed: $e');
          }
        }
      } catch (e) {
        print('API error, falling back to local: $e');

        _entities = await _dbHelper.getEntities();

        if (_entities.isEmpty) {
          print('Local database also returned empty entity list');

          try {
            _entities = await _mongoDBHelper.getEntities();
            print('Loaded ${_entities.length} entities from MongoDB');
          } catch (e) {
            print('MongoDB load failed: $e');
          }
        } else {
          print('Loaded ${_entities.length} entities from local database');
        }

        setState(() {
          _isOfflineMode = true;
        });
      }
    } catch (e) {
      print('Error loading entities: $e');
      _entities = [];
      setState(() {
        _statusMessage = 'Failed to load entities: $e';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteEntity(Entity entity) async {
    if (_isOfflineMode) {
      await _dbHelper.deleteEntity(entity.id!);

      try {
        final deleted = await _mongoDBHelper.deleteEntity(entity.id!);
        if (deleted) {
          print('Entity also deleted from MongoDB: ${entity.id}');
        }
      } catch (e) {
        print('Failed to delete from MongoDB: $e');
      }

      EventBus().fireEntityEvent(EntityEvent(entity.id!, EventType.deleted));
      
      setState(() {
        _entities.removeWhere((e) => e.id == entity.id);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entity deleted locally'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    else {

      try {
        final deleted = await _mongoDBHelper.deleteEntity(entity.id!);
        
        if (deleted) {
          await _dbHelper.deleteEntity(entity.id!);

          EventBus().fireEntityEvent(EntityEvent(entity.id!, EventType.deleted));
          
          setState(() {
            _entities.removeWhere((e) => e.id == entity.id);
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entity deleted successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete entity. You can only delete your own entities.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        print('Error deleting entity: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting entity: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entity List'),
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