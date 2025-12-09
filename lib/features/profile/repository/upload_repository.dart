import 'dart:io';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/local_storage_service.dart';


/// Response model for image upload
class ImageUploadResponse {
  final bool success;
  final String message;
  final ImageUploadData data;
  final String timestamp;

  ImageUploadResponse({
    required this.success,
    required this.message,
    required this.data,
    required this.timestamp,
  });

  factory ImageUploadResponse.fromJson(Map<String, dynamic> json) {
    return ImageUploadResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: ImageUploadData.fromJson(json['data'] as Map<String, dynamic>? ?? {}),
      timestamp: json['timestamp'] as String? ?? '',
    );
  }
}

class ImageUploadData {
  final String imageUrl;
  final String blobName;
  final String originalFilename;
  final int size;
  final String contentType;

  ImageUploadData({
    required this.imageUrl,
    required this.blobName,
    required this.originalFilename,
    required this.size,
    required this.contentType,
  });

  factory ImageUploadData.fromJson(Map<String, dynamic> json) {
    return ImageUploadData(
      imageUrl: json['imageUrl'] as String? ?? '',
      blobName: json['blobName'] as String? ?? '',
      originalFilename: json['originalFilename'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      contentType: json['contentType'] as String? ?? '',
    );
  }
}

/// Repository for upload related operations
class UploadRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  UploadRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  /// Upload image file
  Future<ImageUploadResponse> uploadImage({
    required File imageFile,
  }) async {
    debugPrint('[UploadRepository] Uploading image via API...');

    try {
      // Get auth token
      final token = _localStorage.getAuthToken();
      if (token == null || token.isEmpty) {
        throw AuthException(
          message: 'Authentication required. Please login again.',
        );
      }

      // Prepare headers with Bearer token
      final headers = {
        'Authorization': 'Bearer $token',
      };

      // Make multipart POST request
      final json = await _apiClient.postMultipart(
        AppConfig.uploadImagePath,
        headers: headers,
        file: imageFile,
        fieldName: 'image',
      );

      debugPrint('[UploadRepository] Upload response: $json');

      final response = ImageUploadResponse.fromJson(json);

      // Print the imageUrl as requested
      debugPrint('[UploadRepository] Image URL: ${response.data.imageUrl}');

      return response;
    } catch (e) {
      debugPrint('[UploadRepository] Upload error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }
}
