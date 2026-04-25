import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_storage_service.dart';
import '../models/meal_plan_model.dart';

class MealPlanRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  MealPlanRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  Future<MealPlanResponse> getMealPlanDetails() async {
    debugPrint('[MealPlanRepository] Fetching meal plan details...');

    try {
      final token = _localStorage.getAuthToken();
      if (token == null || token.isEmpty) {
        throw AuthException(message: 'Authentication required. Please login again.');
      }

      final userId = _localStorage.getUserId();
      if (userId == null || userId.isEmpty) {
        throw AuthException(message: 'User not found. Please login again.');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final json = await _apiClient.getJson(
        '/api/user/$userId/meal-plan-details',
        headers: headers,
      );

      debugPrint('[MealPlanRepository] Meal plan response received');
      return MealPlanResponse.fromJson(json);
    } catch (e) {
      debugPrint('[MealPlanRepository] Error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw Exception(message);
    }
  }
}
