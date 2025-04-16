// // import 'dart:io';
// // import 'package:flutter_image_compress/flutter_image_compress.dart';
// // import 'package:path_provider/path_provider.dart';
// // import 'package:path/path.dart' as path;
// // import 'package:image_picker/image_picker.dart';
// //
// // class ImageUtils {
// //   static final ImagePicker _picker = ImagePicker();
// //
// //   // Pick image from gallery
// //   static Future<File?> pickImage() async {
// //     try {
// //       final XFile? pickedFile = await _picker.pickImage(
// //         source: ImageSource.gallery,
// //         imageQuality: 80,
// //       );
// //
// //       if (pickedFile == null) return null;
// //
// //       return File(pickedFile.path);
// //     } catch (e) {
// //       print('Error picking image: $e');
// //       return null;
// //     }
// //   }
// //
// //   // Pick image from camera
// //   static Future<File?> captureImage() async {
// //     try {
// //       final XFile? pickedFile = await _picker.pickImage(
// //         source: ImageSource.camera,
// //         imageQuality: 80,
// //       );
// //
// //       if (pickedFile == null) return null;
// //
// //       return File(pickedFile.path);
// //     } catch (e) {
// //       print('Error capturing image: $e');
// //       return null;
// //     }
// //   }
// //
// //   // Resize image to 800x600
// //   static Future<File?> resizeImage(File imageFile) async {
// //     try {
// //       final directory = await getTemporaryDirectory();
// //       final targetPath = path.join(
// //           directory.path,
// //           'resized_${DateTime.now().millisecondsSinceEpoch}.jpg'
// //       );
// //
// //       final result = await FlutterImageCompress.compressAndGetFile(
// //         imageFile.path,
// //         targetPath,
// //         quality: 85,
// //         minWidth: 800,
// //         minHeight: 600,
// //       );
// //
// //       if (result == null) return imageFile;
// //
// //       return File(result.path);
// //     } catch (e) {
// //       print('Error resizing image: $e');
// //       return imageFile;
// //     }
// //   }
// // }
//
//
//
//
//
// import 'dart:io';
// import 'package:flutter_image_compress/flutter_image_compress.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' as path;
// import 'package:image_picker/image_picker.dart';
//
// class ImageUtils {
//   static final ImagePicker _picker = ImagePicker();
//
//   // Pick image from gallery
//   static Future<File?> pickImage() async {
//     try {
//       final XFile? pickedFile = await _picker.pickImage(
//         source: ImageSource.gallery,
//         imageQuality: 80,
//       );
//
//       if (pickedFile == null) return null;
//
//       return File(pickedFile.path);
//     } catch (e) {
//       print('Error picking image: $e');
//       return null;
//     }
//   }
//
//   // Pick image from camera
//   static Future<File?> captureImage() async {
//     try {
//       final XFile? pickedFile = await _picker.pickImage(
//         source: ImageSource.camera,
//         imageQuality: 80,
//       );
//
//       if (pickedFile == null) return null;
//
//       return File(pickedFile.path);
//     } catch (e) {
//       print('Error capturing image: $e');
//       return null;
//     }
//   }
//
//   // Resize image to 800x600
//   static Future<File?> resizeImage(File imageFile) async {
//     try {
//       final directory = await getTemporaryDirectory();
//       final targetPath = path.join(
//           directory.path,
//           'resized_${DateTime.now().millisecondsSinceEpoch}.jpg'
//       );
//
//       final result = await FlutterImageCompress.compressAndGetFile(
//         imageFile.path,
//         targetPath,
//         quality: 85,
//         minWidth: 800,
//         minHeight: 600,
//         format: CompressFormat.jpeg,
//       );
//
//       if (result == null) return imageFile;
//
//       return File(result.path);
//     } catch (e) {
//       print('Error resizing image: $e');
//       return imageFile;
//     }
//   }
// }




import 'dart:io';
import 'dart:typed_data';
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
      return imageFile;
    }
  }
}