// import 'package:flutter/material.dart';
// import '../../../core/network/api_client.dart';
// import '../../../core/errors/app_exception.dart';
// import '../../../core/services/local_storage_service.dart';
// import '../models/nutrition_progress_model.dart';
//
// /// Repository for nutrition-related operations
// class NutritionRepository {
//   final ApiClient _apiClient;
//   final LocalStorageService _localStorage;
//
//   NutritionRepository({
//     required ApiClient apiClient,
//     required LocalStorageService localStorage,
//   })  : _apiClient = apiClient,
//         _localStorage = localStorage;
//
//   /// Get daily nutrition progress for a specific date
//   Future<NutritionProgressResponse> getDailyNutritionProgress({
//     required String date,
//   }) async {
//     debugPrint('[NutritionRepository] Fetching nutrition progress for date: $date');
//
//     try {
//       // Get auth token
//       final token = _localStorage.getAuthToken();
//       if (token == null || token.isEmpty) {
//         throw AuthException(
//           message: 'Authentication required. Please login again.',
//         );
//       }
//
//       // Prepare headers with Bearer token
//       final headers = {
//         'Content-Type': 'application/json',
//         'Authorization': 'Bearer $token',
//       };
//
//       // Make GET request with query parameters
//       final json = await _apiClient.getJson(
//         '/api/user/nutrition/progress?date=$date',
//         headers: headers,
//       );
//
//       debugPrint('[NutritionRepository] Nutrition progress response: $json');
//
//       return NutritionProgressResponse.fromJson(json);
//     } catch (e) {
//       debugPrint('[NutritionRepository] Nutrition progress error: $e');
//       final message = ExceptionHandler.getErrorMessage(e);
//       throw NetworkException(message: message, originalError: e);
//     }
//   }
// }
