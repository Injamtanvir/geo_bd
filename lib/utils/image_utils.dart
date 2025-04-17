import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';

class ImageUtils {
  static final ImagePicker _picker = ImagePicker();

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

  static Future<String> fileToBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return base64.encode(bytes);
    }
    catch (e) {
      print('Error converting file to base64: $e');
      throw Exception('Failed to convert image to base64: $e');
    }
  }

  static Future<File> base64ToFile(String base64String, String fileName) async {
    try {
      final bytes = base64.decode(base64String); // Using base64.decode instead of base64Decode (AI Help)
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