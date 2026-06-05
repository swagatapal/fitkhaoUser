import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_storage_service.dart';
import '../models/kitchen_model.dart';

/// Repository for kitchen discovery + open/close status.
///
/// Replaces the location-based serviceability flow: the active kitchen list is
/// fetched directly, and the selected kitchen's open status is resolved via the
/// dedicated open-status endpoint.
class KitchenRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  KitchenRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  Map<String, String> _authHeaders() {
    final token = _localStorage.getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// GET /api/adm/kitchen?isActive=true — all active kitchens.
  Future<KitchenListResponse> getActiveKitchens() async {
    debugPrint('[KitchenRepository] Fetching active kitchens…');
    try {
      final json = await _apiClient.getJson(
        '${AppConfig.kitchenOpenStatusPath}?isActive=true',
        headers: _authHeaders(),
      );
      return KitchenListResponse.fromJson(json);
    } catch (e) {
      debugPrint('[KitchenRepository] getActiveKitchens error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// GET /api/adm/kitchen/{kitchenId}/open-status.
  ///
  /// Returns null on any failure so callers can fail-open (treat as open) and
  /// never block ordering on a transient network error.
  Future<KitchenOpenStatus?> getKitchenOpenStatus(String kitchenId) async {
    debugPrint('[KitchenRepository] Checking open status: $kitchenId');
    try {
      final json = await _apiClient.getJson(
        '${AppConfig.kitchenOpenStatusPath}/$kitchenId/open-status',
        headers: _authHeaders(),
      );
      return KitchenOpenStatus.fromJson(json);
    } catch (e) {
      debugPrint('[KitchenRepository] open-status error (fail-open): $e');
      return null;
    }
  }
}
