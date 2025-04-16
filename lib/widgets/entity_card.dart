import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/entity.dart';
import '../screens/entity_form_screen.dart';

class EntityCard extends StatelessWidget {
  final Entity entity;
  final Function? onDelete;
  final bool showActions;

  const EntityCard({
    Key? key,
    required this.entity,
    this.onDelete,
    this.showActions = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              entity.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Image (if available)
          if (entity.image != null && entity.image!.isNotEmpty)
            GestureDetector(
              onTap: () => _showFullImage(context),
              child: SizedBox(
                height: 200,
                child: _buildImageWidget(),
              ),
            ),
          // Location info
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              'Latitude: ${entity.lat.toStringAsFixed(6)}\nLongitude: ${entity.lon.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          // Actions
          if (showActions)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Edit button
                  TextButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    onPressed: () {
                      Navigator.of(context).pushNamed(
                        EntityFormScreen.routeName,
                        arguments: entity,
                      );
                    },
                  ),
                  // Delete button
                  if (onDelete != null)
                    TextButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        _confirmDelete(context);
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Helper method to build the appropriate image widget
  Widget _buildImageWidget() {
    // Check if it's a local file path (starts with '/')
    if (entity.image != null && entity.image!.startsWith('/')) {
      return Image.file(
        File(entity.image!),
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image, size: 50),
          );
        },
      );
    } else {
      // It's a remote URL
      return CachedNetworkImage(
        imageUrl: entity.getFullImageUrl(),
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (BuildContext context, String url, Object error) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.error, color: Colors.red),
                Text(
                  'Failed to load image',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );
    }
  }

  void _showFullImage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: Text(entity.title),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: entity.image != null && entity.image!.startsWith('/')
                  ? Image.file(
                File(entity.image!),
                fit: BoxFit.contain,
                errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                  return const Center(
                    child: Icon(Icons.error),
                  );
                },
              )
                  : CachedNetworkImage(
                imageUrl: entity.getFullImageUrl(),
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (BuildContext context, String url, Object error) {
                  return const Center(
                    child: Icon(Icons.error),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${entity.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete!();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}