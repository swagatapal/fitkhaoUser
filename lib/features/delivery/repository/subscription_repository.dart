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

  /// Create a subscription paid from the wallet.
  /// POST /api/subscription/create — body `{ planId, cancelAnytimeSelected }`.
  Future<SubscriptionResponse> createSubscription({
    required String planId,
    required bool cancelAnytimeSelected,
  }) async {
    debugPrint('[SubscriptionRepository] Creating subscription (wallet) — '
        'planId=$planId cancelAnytime=$cancelAnytimeSelected');
    try {
      final request = SubscriptionRequest(
        planId: planId,
        cancelAnytimeSelected: cancelAnytimeSelected,
      );
      final json = await _apiClient.postJson(
        AppConfig.createSubscriptionPath,
        headers: _authHeaders(),
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

  /// Cancels [subscriptionId] (POST). [refundMethod] is sent in the body when
  /// provided. Auth required.
  Future<SubscriptionResponse> cancelSubscription({
    required String subscriptionId,
    String? refundMethod,
  }) async {
    debugPrint(
        '[SubscriptionRepository] Cancelling $subscriptionId via $refundMethod...');
    try {
      final json = await _apiClient.postJson(
        AppConfig.subscriptionCancelPath(subscriptionId),
        headers: _authHeaders(),
        body: {
          if (refundMethod != null && refundMethod.isNotEmpty)
            'refundMethod': refundMethod,
        },
      );
      debugPrint('[SubscriptionRepository] Cancel response: $json');
      return SubscriptionResponse.fromJson(json);
    } catch (e) {
      debugPrint('[SubscriptionRepository] Cancel error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Fetches the invoice payload for [subscriptionId] (auth). The response
  /// schema is backend-defined, so the decoded `data` map is returned as-is.
  Future<Map<String, dynamic>> getInvoice(String subscriptionId) async {
    debugPrint('[SubscriptionRepository] Invoice for $subscriptionId...');
    try {
      final json = await _apiClient.getJson(
        AppConfig.subscriptionInvoicePath(subscriptionId),
        headers: _authHeaders(),
      );
      final data = json['data'];
      return data is Map<String, dynamic> ? data : json;
    } catch (e) {
      debugPrint('[SubscriptionRepository] Invoice error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Fetches the event history for [subscriptionId] (auth). Returns the list of
  /// event maps from the response (`data.events` / `data` / top-level list).
  Future<List<Map<String, dynamic>>> getEventHistory(
      String subscriptionId) async {
    debugPrint('[SubscriptionRepository] History for $subscriptionId...');
    try {
      final json = await _apiClient.getJson(
        AppConfig.subscriptionHistoryPath(subscriptionId),
        headers: _authHeaders(),
      );
      final data = json['data'];
      final list = data is List
          ? data
          : (data is Map<String, dynamic>
              ? (data['events'] ?? data['history'] ?? const [])
              : const []);
      return (list as List)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    } catch (e) {
      debugPrint('[SubscriptionRepository] History error: $e');
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