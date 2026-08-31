<<<<<<< HEAD
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

// CameraService: Provides high-level methods to interact with the device's camera and gallery.
class CameraService {
  static final ImagePicker _picker = ImagePicker();

  /// Captures a photo using the device camera at 1080p (FHD) resolution.
  /// Uses imageQuality: 70 to balance between visual clarity and file size for uploads.
  static Future<File?> takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920, // FHD Width
        maxHeight: 1080, // FHD Height
        imageQuality: 70, // Compression to save mobile data
      );

      if (image != null) {
        return File(image.path);
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
    return null;
  }

  /// Picks an existing image from the device gallery (same compression as
  /// the camera so uploaded files stay small).
  static Future<File?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920, // FHD Width
        maxHeight: 1080, // FHD Height
        imageQuality: 70, // Compression to save mobile data
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
=======
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

// CameraService: Provides high-level methods to interact with the device's camera and gallery.
class CameraService {
  static final ImagePicker _picker = ImagePicker();

  /// Captures a photo using the device camera at 1080p (FHD) resolution.
  /// Uses imageQuality: 70 to balance between visual clarity and file size for uploads.
  static Future<File?> takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920, // FHD Width
        maxHeight: 1080, // FHD Height
        imageQuality: 70, // Compression to save mobile data
      );

      if (image != null) {
        return File(image.path);
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
    return null;
  }

  /// Allows the user to select an existing photo from their gallery.
  static Future<File?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 70,
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
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
