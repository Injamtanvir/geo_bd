import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/entity.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/db_helper.dart';
import '../utils/image_utils.dart';
import '../widgets/app_drawer.dart';

class EntityFormScreen extends StatefulWidget {
  static const routeName = '/entity-form';

  const EntityFormScreen({Key? key}) : super(key: key);

  @override
  State<EntityFormScreen> createState() => _EntityFormScreenState();
}

class _EntityFormScreenState extends State<EntityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  bool _isLoading = false;
  bool _isEdit = false;
  File? _imageFile;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lonController = TextEditingController();

  Entity? _entity;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Entity) {
      _entity = args;
      _isEdit = true;

      // Fill form with entity data
      _titleController.text = _entity!.title;
      _latController.text = _entity!.lat.toString();
      _lonController.text = _entity!.lon.toString();
    } else {
      // Get current location for new entity
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    final currentLocation = await _locationService.getCurrentLocation();
    if (currentLocation != null && mounted) {
      setState(() {
        _latController.text = currentLocation.latitude.toString();
        _lonController.text = currentLocation.longitude.toString();
      });
    } else {
      // Use default Bangladesh coordinates if location not available
      final defaultLocation = _locationService.getDefaultLocation();
      setState(() {
        _latController.text = defaultLocation.latitude.toString();
        _lonController.text = defaultLocation.longitude.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not get current location. Using default.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    File? pickedImage;

    if (source == ImageSource.gallery) {
      pickedImage = await ImageUtils.pickImage();
    } else {
      pickedImage = await ImageUtils.captureImage();
    }

    if (pickedImage != null) {
      // Resize image to 800x600 as required
      final resizedImage = await ImageUtils.resizeImage(pickedImage);

      setState(() {
        _imageFile = resizedImage;
      });
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Take a Picture'),
            onTap: () {
              Navigator.of(ctx).pop();
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from Gallery'),
            onTap: () {
              Navigator.of(ctx).pop();
              _pickImage(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_imageFile == null && !_isEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isEdit) {
        // Update existing entity
        if (_entity != null) {
          final success = await _apiService.updateEntity(
            id: _entity!.id!,
            title: _titleController.text,
            lat: double.parse(_latController.text),
            lon: double.parse(_lonController.text),
            imageFile: _imageFile,
          );

          if (success) {
            // Update in local database
            final updatedEntity = Entity(
              id: _entity!.id,
              title: _titleController.text,
              lat: double.parse(_latController.text),
              lon: double.parse(_lonController.text),
              image: _entity!.image, // Keep existing image path if not updated
            );

            await _dbHelper.updateEntity(updatedEntity);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Entity updated successfully'),
                duration: Duration(seconds: 2),
              ),
            );

            Navigator.of(context).pop();
          }
        }
      } else {
        // Create new entity
        if (_imageFile != null) {
          final entityId = await _apiService.createEntity(
            title: _titleController.text,
            lat: double.parse(_latController.text),
            lon: double.parse(_lonController.text),
            imageFile: _imageFile!,
          );

          // Save to local database
          final newEntity = Entity(
            id: entityId,
            title: _titleController.text,
            lat: double.parse(_latController.text),
            lon: double.parse(_lonController.text),
            // Image path will be returned by API
          );

          await _dbHelper.insertEntity(newEntity);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entity created successfully'),
              duration: Duration(seconds: 2),
            ),
          );

          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      // Handle offline mode - save locally
      if (!_isEdit) {
        // Create new entity locally
        final newEntity = Entity(
          id: DateTime.now().millisecondsSinceEpoch, // Temporary ID
          title: _titleController.text,
          lat: double.parse(_latController.text),
          lon: double.parse(_lonController.text),
          image: _imageFile?.path, // Store local file path
        );

        await _dbHelper.insertEntity(newEntity, synced: false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved offline. Will sync when online.'),
            duration: Duration(seconds: 3),
          ),
        );

        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Entity' : 'Add Entity'),
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Coordinates
                Row(
                  children: [
                    // Latitude
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          try {
                            double.parse(value);
                          } catch (e) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Longitude
                    Expanded(
                      child: TextFormField(
                        controller: _lonController,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          try {
                            double.parse(value);
                          } catch (e) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Get current location button
                ElevatedButton.icon(
                  icon: const Icon(Icons.my_location),
                  label: const Text('Use Current Location'),
                  onPressed: _getCurrentLocation,
                ),
                const SizedBox(height: 24),

                // Image picker
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Image',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Image preview
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _imageFile != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _imageFile!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                              : _isEdit && _entity?.image != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _entity!.getFullImageUrl(),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(Icons.error),
                                );
                              },
                            ),
                          )
                              : const Center(
                            child: Text('No Image Selected'),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Image picker button
                        ElevatedButton.icon(
                          icon: const Icon(Icons.photo),
                          label: Text(_isEdit ? 'Change Image' : 'Select Image'),
                          onPressed: _showImagePickerOptions,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveForm,
                    child: Text(
                      _isEdit ? 'Update Entity' : 'Create Entity',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum ImageSource {
  camera,
  gallery,
}