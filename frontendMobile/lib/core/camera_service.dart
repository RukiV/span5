import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class CameraService {
  static final ImagePicker _picker = ImagePicker();

  /// Neem 'n foto teen 1080p (FHD) resolusie.
  /// imageQuality: 70 sorg vir goeie kompressie sonder om detail te verloor.
  static Future<File?> takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920, // FHD Breedte
        maxHeight: 1080, // FHD Hoogte
        imageQuality: 70, // Kompressie om data te bespaar
      );

      if (image != null) {
        return File(image.path);
      }
    } catch (e) {
      debugPrint("Kamera Fout: $e");
    }
    return null;
  }

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
      debugPrint("Gallery Fout: $e");
    }
    return null;
  }
}
