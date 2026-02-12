import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_storage_service.dart';
import '../models/subscription_request_model.dart';
import '../models/subscription_response_model.dart';

/// Repository for subscription related operations
class SubscriptionRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  SubscriptionRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  /// Create a new subscription
  Future<SubscriptionResponse> createSubscription({
    required String planType,
    required int amount,
  }) async {
    debugPrint('[SubscriptionRepository] Creating subscription via API...');
    debugPrint('[SubscriptionRepository] Plan: $planType, Amount: $amount');

    try {
      // Get auth token
      final token = _localStorage.getAuthToken();
      if (token == null || token.isEmpty) {
        throw AuthException(
          message: 'Authentication required. Please login again.',
        );
      }

      // Prepare request
      final request = SubscriptionRequest(
        planType: planType,
        amount: amount,
      );

      // Prepare headers with Bearer token
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      debugPrint('[SubscriptionRepository] Request payload: ${request.toJson()}');

      // Make POST request
      final json = await _apiClient.postJson(
        AppConfig.createSubscriptionPath,
        headers: headers,
        body: request.toJson(),
      );

      debugPrint('[SubscriptionRepository] Subscription response: $json');

      return SubscriptionResponse.fromJson(json);
    } catch (e) {
      debugPrint('[SubscriptionRepository] Subscription error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }
}
