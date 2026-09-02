import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';

class QuoteDocument {
  final int documentId;
  final int quoteId;
  final String filename;
  final String mimeType;
  final int sizeBytes;

  QuoteDocument({
    required this.documentId,
    required this.quoteId,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
  });

  factory QuoteDocument.fromJson(Map<String, dynamic> json) {
    return QuoteDocument(
      documentId: json['document_id'] ?? 0,
      quoteId: json['quote_id'] ?? 0,
      filename: json['filename'] ?? '',
      mimeType: json['mime_type'] ?? 'application/pdf',
      sizeBytes: json['size_bytes'] ?? 0,
    );
  }
}

class DocumentService {
  /// Laai 'n PDF vir 'n kwotasie op. Die backend verwerp enige nie-PDF-lêers.
  static Future<QuoteDocument?> uploadQuotePdf(int quoteId, File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('\\').last.split('/').last,
        ),
      });
      final response = await ApiClient().client.post(
        '/quotes/$quoteId/documents',
        data: formData,
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return QuoteDocument.fromJson(response.data);
      }
    } on DioException catch (e) {
      debugPrint("❌ PDF upload error: ${e.response?.statusCode} ${e.response?.data}");
    } catch (e) {
      debugPrint("❌ PDF upload error: $e");
    }
    return null;
  }

  static Future<List<QuoteDocument>> listQuoteDocuments(int quoteId) async {
    try {
      final response = await ApiClient().client.get('/quotes/$quoteId/documents');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((json) => QuoteDocument.fromJson(json))
            .toList();
      }
    } on DioException catch (e) {
      debugPrint("❌ PDF list error: ${e.response?.statusCode} ${e.response?.data}");
    } catch (e) {
      debugPrint("❌ PDF list error: $e");
    }
    return [];
  }

  /// Laai die rou PDF-bytes af vir vertoning in 'n eksterne besigtiger.
  static Future<Uint8List?> downloadQuotePdf(int documentId) async {
    try {
      final response = await ApiClient().client.get(
        '/documents/$documentId/file',
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200) {
        return response.data is Uint8List
            ? response.data
            : Uint8List.fromList(response.data as List<int>);
      }
    } on DioException catch (e) {
      debugPrint("❌ PDF download error: ${e.response?.statusCode} ${e.response?.data}");
    } catch (e) {
      debugPrint("❌ PDF download error: $e");
    }
    return null;
  }
}
