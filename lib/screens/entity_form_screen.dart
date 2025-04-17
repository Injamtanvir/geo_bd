import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/entity.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/db_helper.dart';
import '../services/mongodb_helper.dart';
import '../services/auth_service.dart';
import '../utils/image_utils.dart';
import '../utils/connectivity_provider.dart';
import '../widgets/app_drawer.dart';
import '../screens/auth_screen.dart';
import '../screens/map_screen.dart';

class EntityFormScreen extends StatefulWidget{
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
  final MongoDBHelper _mongoDBHelper = MongoDBHelper();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isEdit = false;
  File? _imageFile;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lonController = TextEditingController();
  Entity? _entity;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (mounted) {
      setState(() {
        _isAuthenticated = isLoggedIn;
      });
      
      if (!isLoggedIn){
        Future.delayed(Duration.zero, () {
          _showLoginPrompt();
        });
      }
    }
  }

  void _showLoginPrompt(){
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Authentication Required'),
        content: const Text(
          'You need to be logged in to create or edit entities. Would you like to login now?',// This will never need
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacementNamed(MapScreen.routeName);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacementNamed(AuthScreen.routeName);
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Entity)
    {
      _entity = args;
      _isEdit = true;
      _titleController.text = _entity!.title;
      _latController.text = _entity!.lat.toString();
      _lonController.text = _entity!.lon.toString();

      if (_entity!.image != null && _entity!.image!.startsWith('/')) {
        _imageFile = File(_entity!.image!);
      }
    }

  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });
    
    final currentLocation = await _locationService.getCurrentLocation();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        
        if (currentLocation != null) {
          _latController.text = currentLocation.latitude.toString();
          _lonController.text = currentLocation.longitude.toString();
        } else {
          final defaultLocation = _locationService.getDefaultLocation();
          _latController.text = defaultLocation.latitude.toString();
          _lonController.text = defaultLocation.longitude.toString();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not get current location. Using default.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      File? pickedImage;
      if (source == ImageSource.gallery) {
        pickedImage = await ImageUtils.pickImage();
      } else {
        pickedImage = await ImageUtils.captureImage();
      }

      if (pickedImage != null) {
        final resizedImage = await ImageUtils.resizeImage(pickedImage);
        if (mounted && resizedImage != null) {
          setState(() {
            _imageFile = resizedImage;
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showImagePickerOptions(){
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

    if (_latController.text.isEmpty || _lonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide latitude and longitude or use current location'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!_isAuthenticated) {
      _showLoginPrompt();
      return;
    }

    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    try {
      final isOnline = Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
      
      if (_isEdit) {
        // Update existing entity
        if (_entity != null) {
          try {
            if (isOnline) {
              final success = await _apiService.updateEntity(
                id: _entity!.id!,
                title: _titleController.text,
                lat: double.parse(_latController.text),
                lon: double.parse(_lonController.text),
                imageFile: _imageFile,
              );

              if (success) {
                final updatedEntity = Entity(
                  id: _entity!.id,
                  title: _titleController.text,
                  lat: double.parse(_latController.text),
                  lon: double.parse(_lonController.text),
                  image: _imageFile?.path ?? _entity!.image,
                );

                await _dbHelper.updateEntity(updatedEntity);

                try {
                  await _mongoDBHelper.updateEntity(updatedEntity);
                  print('Entity updated in MongoDB');
                } catch (e) {
                  print('MongoDB update failed: $e');
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Entity updated successfully'),
                      duration: Duration(seconds: 2),
                    ),
                  );

                  Navigator.of(context).pushReplacementNamed(MapScreen.routeName);
                }
              }
            } else {
              _updateOffline();
            }
          } catch (e)
          {
            print('Error updating entity: $e');
            _updateOffline();
          }
        }
      }
      else {
        try {
          if (isOnline) {
            final id = await _apiService.createEntity(
              title: _titleController.text,
              lat: double.parse(_latController.text),
              lon: double.parse(_lonController.text),
              imageFile: _imageFile!,
            );

            if (id > 0) {
              final newEntity = Entity(
                id: id,
                title: _titleController.text,
                lat: double.parse(_latController.text),
                lon: double.parse(_lonController.text),
                image: _imageFile?.path,
              );

              await _dbHelper.insertEntity(newEntity);

              try {
                await _mongoDBHelper.saveEntity(newEntity);
                print('Entity saved to MongoDB');
              } catch (e) {
                print('MongoDB save failed: $e');
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Entity created successfully'),
                    duration: Duration(seconds: 2),
                  ),
                );

                Navigator.of(context).pushReplacementNamed(MapScreen.routeName);
              }
            }
          } else {
            _createOffline();
          }
        } catch (e) {
          print('Error creating entity: $e');
          _createOffline();
        }
      }
    } catch (e) {
      print('Error saving form: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
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

  Future<void> _updateOffline() async {
    final updatedEntity = Entity(
      id: _entity!.id,
      title: _titleController.text,
      lat: double.parse(_latController.text),
      lon: double.parse(_lonController.text),
      image: _imageFile?.path ?? _entity!.image,
    );

    await _dbHelper.updateEntity(updatedEntity);
    await _dbHelper.markAsSynced(_entity!.id!, synced: false);

    try {
      await _mongoDBHelper.updateEntity(updatedEntity);
      print('Entity updated in MongoDB while offline');
    } catch (e) {
      print('MongoDB offline update failed: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entity saved offline. Will sync when online.'),
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pushReplacementNamed(MapScreen.routeName);
    }
  }

  Future<void> _createOffline() async {
    // Generate a temporary negative ID for offline entities
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempId = -(timestamp % 100000);

    final newEntity = Entity(
      id: tempId,
      title: _titleController.text,
      lat: double.parse(_latController.text),
      lon: double.parse(_lonController.text),
      image: _imageFile?.path,
    );

    // Save to local database and mark as not synced
    await _dbHelper.insertEntity(newEntity, synced: false);

    try {
      await _mongoDBHelper.saveEntity(newEntity);
      print('Entity saved to MongoDB while offline');
    } catch (e) {
      print('MongoDB offline save failed: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entity saved offline. Will sync when online.'),
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pushReplacementNamed(MapScreen.routeName);
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
                            final lat = double.parse(value);
                            if (lat < -90 || lat > 90) {
                              return 'Invalid latitude';
                            }
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
                            final lon = double.parse(value);
                            if (lon < -180 || lon > 180) {
                              return 'Invalid longitude';
                            }
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
                          child: _buildImagePreview(),
                        ),
                        const SizedBox(height: 12),

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

  Widget _buildImagePreview() {
    if (_imageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          _imageFile!,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
            return const Center(
              child: Icon(Icons.broken_image, size: 50),
            );
          },
        ),
      );
    } else if (_isEdit && _entity?.image != null) {
      // If editing and image is from remote URL
      if (!(_entity!.image!.startsWith('/'))) {
        return ClipRRect(
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
        );
      }

      else {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(_entity!.image!),
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(Icons.error),
              );
            },
          ),
        );
      }
    } else {
      return const Center(
        child: Text('No Image Selected'),
      );
    }
  }
}

enum ImageSource {
  camera,
  gallery,
}