import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_storage_service.dart';
import '../models/delivery_slot_model.dart';
import '../models/dish_category_model.dart';
import '../models/weekly_delivery_slot_model.dart';

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

  // ── Weekly delivery-slot preferences ──

  /// GET /api/user/weekly-delivery-slots
  Future<WeeklyDeliverySlotsResponse> getWeeklyDeliverySlots() async {
    debugPrint('[DeliverySlotRepository] Fetching weekly delivery slots...');
    try {
      final json = await _apiClient.getJson(
        AppConfig.weeklyDeliverySlotsPath,
        headers: _authHeaders(),
      );
      return WeeklyDeliverySlotsResponse.fromJson(json);
    } catch (e) {
      throw _wrap(e, 'weekly-get');
    }
  }

  /// POST (first-time) or PUT (replace) /api/user/weekly-delivery-slots.
  /// [days] is the `weeklyDeliverySlots` array already shaped for the API.
  Future<WeeklyDeliverySlotsResponse> saveWeeklyDeliverySlots({
    required List<Map<String, dynamic>> days,
    required bool isUpdate,
  }) async {
    debugPrint('[DeliverySlotRepository] '
        '${isUpdate ? 'Updating' : 'Saving'} weekly delivery slots...');
    try {
      final body = {'weeklyDeliverySlots': days};
      final headers = _authHeaders();
      final json = isUpdate
          ? await _apiClient.putJson(AppConfig.weeklyDeliverySlotsPath,
              headers: headers, body: body)
          : await _apiClient.postJson(AppConfig.weeklyDeliverySlotsPath,
              headers: headers, body: body);
      return WeeklyDeliverySlotsResponse.fromJson(json);
    } catch (e) {
      throw _wrap(e, 'weekly-save');
    }
  }

  /// GET /api/adm/dish-category — the meal categories (Breakfast/Lunch/…)
  /// a delivery slot can serve.
  Future<DishCategoryResponse> getDishCategories() async {
    debugPrint('[DeliverySlotRepository] Fetching dish categories...');
    try {
      final json = await _apiClient.getJson(
        AppConfig.dishCategoryPath,
        headers: _authHeaders(),
      );
      return DishCategoryResponse.fromJson(json);
    } catch (e) {
      throw _wrap(e, 'dish-categories');
    }
  }

  Map<String, String> _authHeaders() {
    final token = _localStorage.getAuthToken();
    if (token == null || token.isEmpty) {
      throw AuthException(
          message: 'Authentication required. Please login again.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  NetworkException _wrap(Object e, String label) {
    debugPrint('[DeliverySlotRepository] $label error: $e');
    return NetworkException(
        message: ExceptionHandler.getErrorMessage(e), originalError: e);
  }
}
