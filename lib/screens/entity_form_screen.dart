import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart' as image_picker;
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

/// Entity Form Screen
/// 
/// This screen allows users to create new entities or edit existing ones.
/// Key features:
/// - Form validation for all fields including latitude/longitude range checks
/// - Image selection from camera or gallery with built-in resizing
/// - Current location detection with user feedback
/// - Support for both online and offline creation/editing
/// - Automatic user association with entities
/// - MongoDB and SQLite synchronization
/// 
/// The form ensures that:
/// 1. Location coordinates are only set when explicitly requested by the user
/// 2. Validation provides clear error messages for latitude/longitude
/// 3. The user is properly redirected to the map screen after submission
/// 4. All entities are properly associated with the current user
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
  bool _isLoadingLocation = false;
  bool _isEdit = false;
  File? _selectedImage;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lonController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
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
          'You need to be logged in to create or edit entities. Would you like to login now?',
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

      if (_entity!.imageUrl != null && _entity!.imageUrl!.startsWith('/')) {
        _selectedImage = File(_entity!.imageUrl!);
      }
    }
    // No automatic location fetching for new entities
  }

  Future<void> _getCurrentLocation() async {
    // If the form is in edit mode, don't auto-fetch the location
    if (_isEdit) return;
    
    // Don't auto-fetch location if user has already manually entered coordinates
    if (_latController.text.isNotEmpty && _lonController.text.isNotEmpty) {
      return;
    }
    
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final position = await _locationService.getCurrentLocation();
      
      // Only update controllers if they're empty (user hasn't input values)
      // This prevents overwriting user-entered coordinates
      if (position != null && _latController.text.isEmpty && _lonController.text.isEmpty) {
        setState(() {
          _latController.text = position.latitude.toStringAsFixed(6);
          _lonController.text = position.longitude.toStringAsFixed(6);
          _isLoadingLocation = false;
        });
      } else if (position == null) {
        // Use default location if we couldn't get the current location
        final defaultPosition = _locationService.getDefaultLocation();
        setState(() {
          _latController.text = defaultPosition.latitude.toStringAsFixed(6);
          _lonController.text = defaultPosition.longitude.toStringAsFixed(6);
          _isLoadingLocation = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get current location, using default location'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      print('Error getting current location: $e');
      setState(() {
        _isLoadingLocation = false;
      });
      
      // Only show error if user hasn't already input coordinates
      if (_latController.text.isEmpty && _lonController.text.isEmpty) {
        // Use default location
        final defaultPosition = _locationService.getDefaultLocation();
        setState(() {
          _latController.text = defaultPosition.latitude.toStringAsFixed(6);
          _lonController.text = defaultPosition.longitude.toStringAsFixed(6);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get location: ${e.toString()}. Using default position.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final image_picker.ImagePicker picker = image_picker.ImagePicker();
    final image_picker.XFile? imageFile = await picker.pickImage(source: image_picker.ImageSource.gallery);

    if (imageFile != null) {
      setState(() {
        _selectedImage = File(imageFile.path);
      });
      
      // Removing the auto-location fetch after picking an image
      // This was causing unwanted behavior where location was automatically populated
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImage == null && !_isEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }

    // Validate latitude and longitude are provided
    final latitude = double.tryParse(_latController.text);
    final longitude = double.tryParse(_lonController.text);
    
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid coordinates')),
      );
      return;
    }
    
    // Validate latitude and longitude ranges
    if (latitude < -90 || latitude > 90) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Latitude must be between -90 and 90')),
      );
      return;
    }
    
    if (longitude < -180 || longitude > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Longitude must be between -180 and 180')),
      );
      return;
    }

    // Check if user is authenticated
    final username = await _authService.getUsername();
    if (username == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to add or edit entities'),
        ),
      );
      return;
    }

    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    try {
      final connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);
      final isOnline = connectivityProvider.isOnline;

      final name = _titleController.text;
      final lat = double.parse(_latController.text);
      final lon = double.parse(_lonController.text);

      String? imageData;
      
      // Process image data
      if (_selectedImage != null) {
        // Convert to base64 for storage
        imageData = await ImageUtils.fileToBase64(_selectedImage!);
      } else if (_isEdit && _entity?.imageUrl != null) {
        // Keep existing image data for edits
        imageData = _entity?.imageUrl;
      }

      final entity = Entity(
        id: _isEdit ? _entity!.id : null,
        title: name,
        lat: lat,
        lon: lon,
        imageUrl: imageData,
        createdBy: username,
        syncStatus: _isAuthenticated ? 'synced' : 'local',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      if (_isEdit) {
        // Update existing entity
        if (_isAuthenticated) {
          // Online - update through API
          try {
            // Manual conversion to match the updateEntity method signature
            final success = await _apiService.updateEntity(
              id: int.tryParse(entity.id.toString()) ?? 0,
              title: entity.title,
              lat: entity.lat,
              lon: entity.lon,
              imageFile: _selectedImage,
            );
            
            if (success) {
              await _dbHelper.updateEntity(entity.copyWith(syncStatus: 'synced'));
              await _mongoDBHelper.updateEntity(entity.copyWith(syncStatus: 'synced'));
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Entity updated successfully')),
              );
              
              // Return to previous screen with result true to trigger a refresh
              Navigator.of(context).pop(true);
            } else {
              throw Exception('API update returned false');
            }
          } catch (e) {
            print('Error updating entity online: $e');
            // Save locally with 'update-pending' status
            await _dbHelper.updateEntity(entity.copyWith(syncStatus: 'update-pending'));
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Entity saved locally, will sync when online')),
            );
            
            // Return to previous screen with result true to trigger a refresh
            Navigator.of(context).pop(true);
          }
        } else {
          // Offline - update local DB only with pending status
          await _dbHelper.updateEntity(entity.copyWith(syncStatus: 'update-pending'));
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entity updated locally, will sync when online')),
          );
          
          // Return to previous screen with result true to trigger a refresh
          Navigator.of(context).pop(true);
        }
      } else {
        // Create new entity
        if (_isAuthenticated) {
          // Online - create through API
          try {
            if (_selectedImage != null) {
              try {
                // First save entity locally with a temporary ID
                final tempId = DateTime.now().millisecondsSinceEpoch.toString();
                final localEntity = entity.copyWith(
                  id: tempId,
                  syncStatus: 'pending'
                );
                
                // Save to local DB first
                await _dbHelper.insertEntity(localEntity);
                
                // Then try to create via API
                final newId = await _apiService.createEntity(
                  title: entity.title,
                  lat: entity.lat,
                  lon: entity.lon,
                  imageFile: _selectedImage!,
                );
                
                if (newId > 0) {
                  // API creation successful, update local entity
                  final updatedEntity = localEntity.copyWith(
                    id: newId.toString(),
                    syncStatus: 'synced'
                  );
                  
                  // Update local DB
                  await _dbHelper.updateEntity(updatedEntity);
                  
                  // Save to MongoDB too
                  try {
                    await _mongoDBHelper.saveEntity(updatedEntity);
                  } catch (e) {
                    print('MongoDB save error: $e');
                    // Continue even if MongoDB fails
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Entity created successfully')),
                  );
                  
                  // Return to previous screen with result true to trigger a refresh
                  Navigator.of(context).pop(true);
                }
              } catch (apiError) {
                print('API error but local entity saved: $apiError');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Entity saved locally, will sync when online')),
                );
                // Entity already saved locally, just return to previous screen
                Navigator.of(context).pop(true);
              }
            } else {
              throw Exception('No image selected');
            }
          } catch (e) {
            print('Error creating entity: $e');
            // Save locally with a pending status
            try {
              final tempId = DateTime.now().millisecondsSinceEpoch.toString();
              final localEntity = entity.copyWith(
                id: tempId,
                syncStatus: 'pending'
              );
              
              await _dbHelper.insertEntity(localEntity);
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Entity saved locally, will sync when online')),
              );
              
              // Return to previous screen with result true to trigger a refresh
              Navigator.of(context).pop(true);
            } catch (dbError) {
              print('Error saving to local DB: $dbError');
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to save entity: $dbError')),
              );
            }
          }
        } else {
          // Offline - save to local DB only
          final localEntity = entity.copyWith(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            syncStatus: 'pending',
          );
          await _dbHelper.insertEntity(localEntity);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entity saved locally, will sync when online')),
          );
          
          // Return to previous screen with result true to trigger a refresh
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      print('Error saving entity: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving entity: $e')),
      );
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
    _imageController.dispose();
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
                        validator: _validateLatitude,
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
                        validator: _validateLongitude,
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
                          onPressed: _pickImage,
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
    if (_selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          _selectedImage!,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
            return const Center(
              child: Icon(Icons.broken_image, size: 50),
            );
          },
        ),
      );
    } else if (_isEdit && _entity?.imageUrl != null) {
      // If editing and image is from remote URL
      if (!(_entity!.imageUrl!.startsWith('/'))) {
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
            File(_entity!.imageUrl!),
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

  String? _validateLatitude(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter latitude';
    }
    
    final latitude = double.tryParse(value);
    if (latitude == null) {
      return 'Please enter a valid number';
    }
    
    if (latitude < -90 || latitude > 90) {
      return 'Latitude must be between -90 and 90';
    }
    
    return null;
  }

  String? _validateLongitude(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter longitude';
    }
    
    final longitude = double.tryParse(value);
    if (longitude == null) {
      return 'Please enter a valid number';
    }
    
    if (longitude < -180 || longitude > 180) {
      return 'Longitude must be between -180 and 180';
    }
    
    return null;
  }
}