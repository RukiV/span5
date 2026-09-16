import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';

class ImageService {
  /// Upload an image and link it to a parent record.
  ///
  /// The backend (post-maintoets merge) requires parent_id + parent_type query
  /// params and creates the ImageAssetLink itself — so the parent (e.g. the
  /// fault/ticket) must already exist. parent_type is e.g. 'ticket', 'asset',
  /// 'stock', 'job'. Returns the new image_id, or null on failure.
  static Future<int?> uploadImage(File file, {required int parentId, required String parentType}) async {
    return _upload(
      parentId: parentId,
      parentType: parentType,
      prepare: () async => MultipartFile.fromFile(
        file.path,
        filename: file.path.split('\\').last.split('/').last,
      ),
    );
  }

  /// Upload raw image bytes (bv. 'n kaart-skermgreep) gekoppel aan 'n parent.
  static Future<int?> uploadImageBytes(Uint8List bytes, {required int parentId, required String parentType, String? filename}) async {
    return _upload(
      parentId: parentId,
      parentType: parentType,
      prepare: () async => MultipartFile.fromBytes(
        bytes,
        filename: filename ?? 'map_${DateTime.now().millisecondsSinceEpoch}.png',
      ),
    );
  }

  static Future<int?> _upload({
    required int parentId,
    required String parentType,
    required Future<MultipartFile> Function() prepare,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await prepare(),
      });
      final response = await ApiClient().client.post(
        '/image/',
        data: formData,
        queryParameters: {'parent_id': parentId, 'parent_type': parentType},
      );
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

  /// Fetch the image ids linked to a parent (e.g. every photo on a ticket).
  static Future<List<int>> getImagesForParent(String parentType, int parentId) async {
    try {
      final response = await ApiClient().client.get('/image/parent/$parentType/$parentId');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((item) => item is Map ? item['image_id'] as int? : null)
            .whereType<int>()
            .toList();
      }
    } on DioException catch (e) {
      debugPrint("❌ Image list error: ${e.response?.statusCode} ${e.response?.data}");
    } catch (e) {
      debugPrint("❌ Image list error: $e");
    }
    return [];
  }

  /// Delete an image by id (used when editing a ticket's photos).
  static Future<bool> deleteImage(int imageId) async {
    try {
      final response = await ApiClient().client.delete('/image/$imageId');
      return response.statusCode == 204 || response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint("❌ Image delete error: ${e.response?.statusCode} ${e.response?.data}");
    } catch (e) {
      debugPrint("❌ Image delete error: $e");
    }
    return false;
  }
}
