import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/entity.dart';

class EntityDetailsScreen extends StatefulWidget {
  static const routeName = '/entity-details';
  
  const EntityDetailsScreen({Key? key}) : super(key: key);

  @override
  _EntityDetailsScreenState createState() => _EntityDetailsScreenState();
}

class _EntityDetailsScreenState extends State<EntityDetailsScreen> {
  Entity? _entity;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Entity) {
      _entity = args;
    }
  }
  
  Widget _buildImageWidget(Entity entity) {
    if (entity.imageUrl != null && entity.imageUrl!.startsWith('/')) {
      return Image.file(
        File(entity.imageUrl!),
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image, size: 50),
          );
        },
      );
    }
    else {
      return CachedNetworkImage(
        imageUrl: entity.getFullImageUrl(),
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (BuildContext context, String url, Object error) {
          print('Error loading image: $error, URL: ${entity.getFullImageUrl()}');
          return const Center(
            child: Icon(Icons.error, color: Colors.red, size: 50),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_entity == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Entity Details'),
        ),
        body: const Center(
          child: Text('No entity data provided'),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_entity!.title),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_entity!.imageUrl != null && _entity!.imageUrl!.isNotEmpty)
                  SizedBox(
                    height: 250,
                    child: _buildImageWidget(_entity!),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _entity!.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Latitude: ${_entity!.lat.toStringAsFixed(6)}\nLongitude: ${_entity!.lon.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      if (_entity!.createdBy != null && _entity!.createdBy!.isNotEmpty)
                        Text(
                          'Created by: ${_entity!.createdBy}',
                          style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }
} 