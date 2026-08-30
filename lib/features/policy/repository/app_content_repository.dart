import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../models/app_content_model.dart';
import '../models/app_constants_model.dart';
import '../models/app_version_model.dart';

/// Repository for fetching app content (terms & conditions, privacy policy)
/// and app-wide runtime constants.
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

  /// Fetch runtime constants from /api/app/constants.
  /// Never throws — returns [AppConstants.defaults] on any failure so the
  /// app always has a safe value to work with.
  ///
  /// Parses: data.order.cancellationTime (seconds).
  /// Falls back to [AppConstants.defaults] when the field is absent or the
  /// request fails.
  Future<AppConstants> getAppConstants() async {
    debugPrint('[AppContentRepository] Fetching app constants...');
    try {
      final json = await _apiClient.getJson(AppConfig.appConstant);
      debugPrint('[AppContentRepository] Constants response: $json');
      return AppConstants.fromApiResponse(json);
    } catch (e) {
      debugPrint(
          '[AppContentRepository] Constants fetch error (using defaults): $e');
      return AppConstants.defaults;
    }
  }

  /// Check app version against the server.
  /// Returns null on any failure — callers should treat null as "no update needed"
  /// so a network error never blocks the user from opening the app.
  Future<AppVersionModel?> checkAppVersion({
    required String currentVersion,
    String? platform,
  }) async {
    // Defaulting to 'android' made iOS ask the backend for the Android version
    // config, which 404s ("No version config found for platform: android") and
    // silently disabled the update gate on iOS.
    final resolvedPlatform = platform ??
        (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
    debugPrint('[AppContentRepository] Checking app version: $currentVersion');
    try {
      final json = await _apiClient.getJson(
        '${AppConfig.appVersionPath}?platform=$resolvedPlatform&currentVersion=$currentVersion',
      );
      debugPrint('[AppContentRepository] Version response: $json');
      return AppVersionModel.fromJson(json);
    } catch (e) {
      debugPrint('[AppContentRepository] Version check error (skipping): $e');
      return null;
    }
  }
}
