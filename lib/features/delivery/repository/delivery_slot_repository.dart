import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/config/app_config.dart';
import '../models/delivery_slot_model.dart';

/// Repository for delivery slot operations
class DeliverySlotRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  DeliverySlotRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  /// Fetch delivery slots from API (old endpoint)
  Future<DeliverySlotListResponse> getDeliverySlots() async {
    debugPrint('[DeliverySlotRepository] Fetching delivery slots via API...');

    try {
      final token = _localStorage.getAuthToken();
      if (token == null || token.isEmpty) {
        throw AuthException(
          message: 'Authentication required. Please login again.',
        );
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final json = await _apiClient.getJson(
        AppConfig.deliverySlotListPath,
        headers: headers,
      );

      debugPrint('[DeliverySlotRepository] Delivery slots response: $json');

      return DeliverySlotListResponse.fromJson(json);
    } catch (e) {
      debugPrint('[DeliverySlotRepository] Delivery slots error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Fetch combined delivery slots with previous selections and available meals
  Future<DeliverySlotsResponse> getDeliverySlotsWithSelections({
    required String date,
  }) async {
    debugPrint('[DeliverySlotRepository] Fetching delivery slots for date: $date');

    try {
      final token = _localStorage.getAuthToken();
      if (token == null || token.isEmpty) {
        throw AuthException(
          message: 'Authentication required. Please login again.',
        );
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final json = await _apiClient.getJson(
        '${AppConfig.deliverySlotsPath}?date=$date',
        headers: headers,
      );

      debugPrint('[DeliverySlotRepository] Combined slots response: $json');

      return DeliverySlotsResponse.fromJson(json);
    } catch (e) {
      debugPrint('[DeliverySlotRepository] Combined slots error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Confirm delivery slot selections
  Future<ConfirmDeliverySlotResponse> confirmDeliverySlots({
    required ConfirmDeliverySlotRequest request,
  }) async {
    debugPrint('[DeliverySlotRepository] Confirming delivery slots via API...');

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

      // Make POST request
      final json = await _apiClient.postJson(
        AppConfig.deliverySlotConfirmPath,
        body: request.toJson(),
        headers: headers,
      );

      debugPrint('[DeliverySlotRepository] Confirm slots response: $json');

      return ConfirmDeliverySlotResponse.fromJson(json);
    } catch (e) {
      debugPrint('[DeliverySlotRepository] Confirm slots error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }
}
