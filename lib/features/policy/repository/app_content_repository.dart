import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../models/app_content_model.dart';

/// Repository for fetching app content (terms & conditions, privacy policy)
class AppContentRepository {
  final ApiClient _apiClient;

  AppContentRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// Fetch content by code — e.g. 'terms' or 'privacy_policy'
  Future<AppContentResponse> getContent(String code) async {
    debugPrint('[AppContentRepository] Fetching content: $code');
    try {
      final json = await _apiClient.getJson('${AppConfig.appContentPath}/$code');
      debugPrint('[AppContentRepository] Response for $code: $json');
      return AppContentResponse.fromJson(json);
    } catch (e) {
      debugPrint('[AppContentRepository] Error fetching $code: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }
}
