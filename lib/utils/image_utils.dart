// lib/utils/image_utils.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert'; // Add this import for base64
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';

class ImageUtils {
  static final ImagePicker _picker = ImagePicker();

  // Pick image from gallery
  static Future<File?> pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile == null) return null;
      return File(pickedFile.path);
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  // Pick image from camera
  static Future<File?> captureImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (pickedFile == null) return null;
      return File(pickedFile.path);
    } catch (e) {
      print('Error capturing image: $e');
      return null;
    }
  }

  // Resize image to 800x600
  static Future<File?> resizeImage(File imageFile) async {
    try {
      // Read the image file
      List<int> imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(Uint8List.fromList(imageBytes));

      if (image == null) return imageFile;

      // Resize the image
      img.Image resizedImage = img.copyResize(
          image,
          width: 800,
          height: 600,
          interpolation: img.Interpolation.linear
      );

      // Create a new file to save the resized image
      final directory = await getTemporaryDirectory();
      final targetPath = path.join(
          directory.path,
          'resized_${DateTime.now().millisecondsSinceEpoch}.jpg'
      );

      // Encode and save the image as JPEG
      final File resizedFile = File(targetPath);
      await resizedFile.writeAsBytes(img.encodeJpg(resizedImage, quality: 85));

      return resizedFile;
    } catch (e) {
      print('Error resizing image: $e');
      // Return original file if resize fails
      return imageFile;
    }
  }

  // Convert image file to base64 string (can be useful for API uploads)
  static Future<String> fileToBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return base64.encode(bytes); // Use base64.encode instead of base64Encode
    } catch (e) {
      print('Error converting file to base64: $e');
      throw Exception('Failed to convert image to base64: $e');
    }
  }

  // Parse base64 string to image file
  static Future<File> base64ToFile(String base64String, String fileName) async {
    try {
      final bytes = base64.decode(base64String); // Use base64.decode instead of base64Decode
      final directory = await getTemporaryDirectory();
      final filePath = path.join(directory.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      print('Error converting base64 to file: $e');
      throw Exception('Failed to convert base64 to image: $e');
    }
  }
}