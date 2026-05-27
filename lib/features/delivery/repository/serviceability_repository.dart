import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_storage_service.dart';
import '../models/serviceability_model.dart';

/// Repository for serviceability check operations
class ServiceabilityRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  ServiceabilityRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  /// Check if location is serviceable
  Future<ServiceabilityResponse> checkServiceability({
    required double latitude,
    required double longitude,
  }) async {
    debugPrint('[ServiceabilityRepository] Checking serviceability for lat: $latitude, long: $longitude');

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
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Make GET request with query parameters
      final json = await _apiClient.getJson(
        '/api/check-serviceability?latitude=$latitude&longitude=$longitude',
        //'/api/check-serviceability?latitude=22.8671&longitude=88.3674',
        headers: headers,
      );

      debugPrint('[ServiceabilityRepository] Serviceability response: $json');

      return ServiceabilityResponse.fromJson(json);
    } catch (e) {
      debugPrint('[ServiceabilityRepository] Serviceability check error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Fetch kitchen open/close status.
  /// Returns null on any failure — callers treat null as "kitchen is open"
  /// so a transient network error never blocks the user from ordering.
  Future<KitchenOpenStatusData?> checkKitchenOpenStatus(
      String kitchenId) async {
    debugPrint(
        '[ServiceabilityRepository] Checking kitchen open status: $kitchenId');
    try {
      final token = _localStorage.getAuthToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      };
      final json = await _apiClient.getJson(
        '${AppConfig.kitchenOpenStatusPath}/$kitchenId/open-status',
        headers: headers,
      );
      debugPrint('[ServiceabilityRepository] Kitchen open status: $json');
      return KitchenOpenStatusData.fromJson(json);
    } catch (e) {
      debugPrint(
          '[ServiceabilityRepository] Kitchen status error (fail-open): $e');
      return null;
    }
  }
}
