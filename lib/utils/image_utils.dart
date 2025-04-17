import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ImageUtils {
  static final ImagePicker _picker = ImagePicker();

  static Future<File?> pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    return image != null ? File(image.path) : null;
  }

  static Future<File?> pickImageFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    return image != null ? File(image.path) : null;
  }

  //Resize image to 800x600
  static Future<File?> resizeImage(File imageFile) async {
    try {
      List<int> imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(Uint8List.fromList(imageBytes));

      if (image == null) return imageFile;

      img.Image resizedImage = img.copyResize(
          image,
          width: 800,
          height: 600,
          interpolation: img.Interpolation.linear
      );

      final directory = await getTemporaryDirectory();
      final targetPath = path.join(
          directory.path,
          'resized_${DateTime.now().millisecondsSinceEpoch}.jpg'
      );

      final File resizedFile = File(targetPath);
      await resizedFile.writeAsBytes(img.encodeJpg(resizedImage, quality: 85));

      return resizedFile;
    } catch (e) {
      print('Error resizing image: $e');
      return imageFile;
    }
  }

  // Convert a File to a Base64 string
  static Future<String> fileToBase64(File file) async {
    final bytes = await file.readAsBytes();
    final base64String = base64Encode(bytes);
    return 'data:image/${path.extension(file.path).replaceAll('.', '')};base64,$base64String';
  }

  // Create a copy of the image file in the app's documents directory
  static Future<File> saveImageToAppDirectory(File imageFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'entity_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
    final savedImage = await imageFile.copy('${appDir.path}/$fileName');
    return savedImage;
  }

  // Download an image from a URL and convert it to Base64
  static Future<String?> downloadAndConvertToBase64(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final base64String = base64Encode(bytes);
        // Detect image type from URL or Content-Type header
        String? contentType = response.headers['content-type'];
        String imageType = 'jpeg';  // Default
        
        if (contentType != null && contentType.startsWith('image/')) {
          imageType = contentType.split('/')[1];
        } else {
          // Try to get from URL extension
          final extension = path.extension(url).toLowerCase();
          if (extension.isNotEmpty) {
            imageType = extension.replaceAll('.', '');
          }
        }
        
        return 'data:image/$imageType;base64,$base64String';
      } else {
        print('Failed to download image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error downloading image: $e');
      return null;
    }
  }

  // Display an image widget based on the image string (base64, URL, or file path)
  static Widget displayImage(String? imageString, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (imageString == null || imageString.isEmpty) {
      return Image.asset(
        'assets/placeholder.png',
        width: width,
        height: height,
        fit: fit,
      );
    }

    if (imageString.startsWith('data:image')) {
      return displayBase64Image(imageString, width: width, height: height, fit: fit);
    } else if (imageString.startsWith('http')) {
      return Image.network(
        imageString,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading network image: $error');
          return Image.asset(
            'assets/placeholder.png',
            width: width,
            height: height,
            fit: fit,
          );
        },
      );
    } else if (imageString.startsWith('/')) {
      return Image.file(
        File(imageString),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading file image: $error');
          return Image.asset(
            'assets/placeholder.png',
            width: width,
            height: height,
            fit: fit,
          );
        },
      );
    } else {
      // Assume it's an image name from the API
      final apiBaseUrl = 'https://labs.anontech.info/cse489/t3/images';
      return Image.network(
        '$apiBaseUrl/$imageString',
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading API image: $error');
          return Image.asset(
            'assets/placeholder.png',
            width: width,
            height: height,
            fit: fit,
          );
        },
      );
    }
  }

  // Display a base64 image
  static Widget displayBase64Image(String base64String, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    try {
      // Extract the actual base64 data from the data URL
      final dataStart = base64String.indexOf(',') + 1;
      final data = base64String.substring(dataStart);
      
      final decodedBytes = base64Decode(data);
      
      return Image.memory(
        decodedBytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          print('Error displaying base64 image: $error');
          return Image.asset(
            'assets/placeholder.png',
            width: width,
            height: height,
            fit: fit,
          );
        },
      );
    } catch (e) {
      print('Error decoding base64 image: $e');
      return Image.asset(
        'assets/placeholder.png',
        width: width,
        height: height,
        fit: fit,
      );
    }
  }
}