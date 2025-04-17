import 'package:flutter/material.dart';
import '../models/entity.dart';
import '../services/api_service.dart';
import '../services/db_helper.dart';
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
  List<Entity> _entities = [];
  bool _isLoading = true;
  bool _isOfflineMode = false;
  String _statusMessage = ''; // Changed from _errorMessage to _statusMessage

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
      // Always try to load from server first
      print('Attempting to load entities from API...');
      try {
        final apiEntities = await _apiService.getEntities();

        if (apiEntities.isNotEmpty) {
          print('Loaded ${apiEntities.length} entities from API successfully');
          _entities = apiEntities;

          // Save to local database for offline access
          for (var entity in _entities) {
            await _dbHelper.insertEntity(entity);
          }

          setState(() {
            _isOfflineMode = false;
          });
        } else {
          print('API returned empty entity list');
        }
      } catch (e) {
        print('API error, falling back to local: $e');

        // Try loading from local DB if API fails
        _entities = await _dbHelper.getEntities();

        if (_entities.isEmpty) {
          print('Local database also returned empty entity list');
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
    // Only allow deleting local entities in offline mode
    if (_isOfflineMode) {
      await _dbHelper.deleteEntity(entity.id!);
      
      // Fire an event to notify other screens of the deletion
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
    } else {
      // In online mode, we would need a DELETE API endpoint
      // Since the API doesn't support deletion in the requirements, we'll
      // just show a message
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