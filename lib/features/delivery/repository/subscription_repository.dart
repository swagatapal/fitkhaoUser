import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_storage_service.dart';
import '../models/subscription_cancel_preview_model.dart';
import '../models/subscription_plan_model.dart';
import '../models/subscription_pricing_preview_model.dart';
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

  /// Fetch all active subscription plans (public endpoint — no auth required)
  Future<SubscriptionPlanResponse> getSubscriptionPlans() async {
    debugPrint('[SubscriptionRepository] Fetching subscription plans...');
    try {
      final json = await _apiClient.getJson(
        '${AppConfig.subscriptionPlansPath}?isActive=true',
      );
      debugPrint('[SubscriptionRepository] Plans response: $json');
      return SubscriptionPlanResponse.fromJson(json);
    } catch (e) {
      debugPrint('[SubscriptionRepository] Error fetching plans: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Create a new subscription
  Future<SubscriptionResponse> createSubscription({
    required String planCode,
    String? paymentId,
  }) async {
    debugPrint('[SubscriptionRepository] Creating subscription via API...');
    debugPrint('[SubscriptionRepository] planCode: $planCode, paymentId: $paymentId');

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
        planCode: planCode,
        paymentId: paymentId,
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

  /// Fetches the refund preview for cancelling [subscriptionId]. Auth required.
  Future<SubscriptionCancelPreviewResponse> getCancellationPreview(
    String subscriptionId,
  ) async {
    debugPrint(
        '[SubscriptionRepository] Cancel preview for $subscriptionId...');
    try {
      final json = await _apiClient.getJson(
        AppConfig.subscriptionCancelPreviewPath(subscriptionId),
        headers: _authHeaders(),
      );
      debugPrint('[SubscriptionRepository] Cancel preview response: $json');
      return SubscriptionCancelPreviewResponse.fromJson(json);
    } catch (e) {
      debugPrint('[SubscriptionRepository] Cancel preview error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Cancels [subscriptionId], refunding via [refundMethod] (e.g. "wallet").
  /// Auth required.
  Future<SubscriptionResponse> cancelSubscription({
    required String subscriptionId,
    required String refundMethod,
  }) async {
    debugPrint(
        '[SubscriptionRepository] Cancelling $subscriptionId via $refundMethod...');
    try {
      final json = await _apiClient.postJson(
        AppConfig.subscriptionCancelPath(subscriptionId),
        headers: _authHeaders(),
        body: {'refundMethod': refundMethod},
      );
      debugPrint('[SubscriptionRepository] Cancel response: $json');
      return SubscriptionResponse.fromJson(json);
    } catch (e) {
      debugPrint('[SubscriptionRepository] Cancel error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Fetches the server-computed pricing preview for [planId], optionally with
  /// the "cancel anytime" add-on selected. Auth required.
  Future<SubscriptionPricingPreviewResponse> getPricingPreview({
    required String planId,
    required bool cancelAnytimeSelected,
  }) async {
    debugPrint(
        '[SubscriptionRepository] Pricing preview planId=$planId cancelAnytime=$cancelAnytimeSelected');
    try {
      final json = await _apiClient.getJson(
        '${AppConfig.subscriptionPricingPreviewPath}'
        '?planId=$planId&cancelAnytimeSelected=$cancelAnytimeSelected',
        headers: _authHeaders(),
      );
      debugPrint('[SubscriptionRepository] Pricing preview response: $json');
      return SubscriptionPricingPreviewResponse.fromJson(json);
    } catch (e) {
      debugPrint('[SubscriptionRepository] Pricing preview error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Bearer-auth headers; throws if the user is not logged in.
  Map<String, String> _authHeaders() {
    final token = _localStorage.getAuthToken();
    if (token == null || token.isEmpty) {
      throw AuthException(
        message: 'Authentication required. Please login again.',
      );
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
}