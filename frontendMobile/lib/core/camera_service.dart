import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class CameraService {
  static final ImagePicker _picker = ImagePicker();

  /// Takes a photo and returns the File.
  /// Limits resolution to FHD (approx 1920px) and applies 80% quality for efficiency.
  static Future<File?> takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (image != null) {
        return File(image.path);
      }
    } catch (e) {
      // Log error or handle appropriately
      debugPrint("Camera Error: $e");
    }
    return null;
  }

  /// Picks a photo from the gallery with similar FHD limits.
  static Future<File?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (image != null) {
        return File(image.path);
      }
    } catch (e) {
      debugPrint("Gallery Error: $e");
    }
    return null;
  }
}
