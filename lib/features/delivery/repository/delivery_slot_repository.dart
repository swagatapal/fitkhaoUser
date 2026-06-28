import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_storage_service.dart';
import '../models/delivery_slot_model.dart';

class DeliverySlotRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  DeliverySlotRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  /// GET /api/delivery-slot/list — the catalogue of selectable delivery slots.
  Future<DeliverySlotListResponse> getDeliverySlotList() async {
    debugPrint('[DeliverySlotRepository] Fetching delivery slot list...');
    try {
      final token = _localStorage.getAuthToken();
      if (token == null || token.isEmpty) {
        throw AuthException(
            message: 'Authentication required. Please login again.');
      }
      final json = await _apiClient.getJson(
        AppConfig.deliverySlotListPath,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return DeliverySlotListResponse.fromJson(json);
    } catch (e) {
      debugPrint('[DeliverySlotRepository] Slot list error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// POST /api/delivery-slots/confirm — confirm slots for many dates at once.
  Future<ConfirmDeliverySlotResponse> confirmDeliverySchedule(
      ConfirmDeliveryScheduleRequest request) async {
    debugPrint('[DeliverySlotRepository] Confirming delivery schedule '
        '(${request.deliveries.length} dates)...');
    try {
      final token = _localStorage.getAuthToken();
      if (token == null || token.isEmpty) {
        throw AuthException(
            message: 'Authentication required. Please login again.');
      }
      final json = await _apiClient.postJson(
        AppConfig.deliverySlotConfirmPath,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: request.toJson(),
      );
      return ConfirmDeliverySlotResponse.fromJson(json);
    } catch (e) {
      debugPrint('[DeliverySlotRepository] Confirm schedule error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// GET /api/delivery-slots?date=YYYY-MM-DD
  /// Returns slots, availableMeals, previousSelection, window info, history
  Future<DeliverySlotsResponse> getDeliverySlotsWithSelections({
    required String date,
  }) async {
    debugPrint('[DeliverySlotRepository] Fetching slots for date: $date');

    try {
      final token = _localStorage.getAuthToken();
      if (token == null || token.isEmpty) {
        throw AuthException(
            message: 'Authentication required. Please login again.');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final json = await _apiClient.getJson(
        '${AppConfig.deliverySlotsPath}?date=$date',
        headers: headers,
      );

      debugPrint('[DeliverySlotRepository] Slots response received');
      return DeliverySlotsResponse.fromJson(json);
    } catch (e) {
      debugPrint('[DeliverySlotRepository] Error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }
}
