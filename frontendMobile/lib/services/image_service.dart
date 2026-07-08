import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';

class ImageService {
  static Future<int?> uploadImage(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('\\').last.split('/').last,
        ),
      });
      final response = await ApiClient().client.post('/image/', data: formData);
      if (response.statusCode == 201) {
        final imageId = response.data['image_id'] as int?;
        debugPrint("✅ Image uploaded: $imageId");
        return imageId;
      }
    } on DioException catch (e) {
      debugPrint("❌ Image upload error: ${e.response?.statusCode} ${e.response?.data}");
    } catch (e) {
      debugPrint("❌ Image upload error: $e");
    }
    return null;
  }
}
