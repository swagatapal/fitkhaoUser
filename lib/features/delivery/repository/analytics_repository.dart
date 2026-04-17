// import 'package:flutter/material.dart';
// import '../../../core/network/api_client.dart';
// import '../../../core/services/local_storage_service.dart';
// import '../../../core/errors/app_exception.dart';
// import '../../../core/config/app_config.dart';
// import '../models/trending_item.dart';
//
// class AnalyticsRepository {
//   final ApiClient _apiClient;
//   final LocalStorageService _localStorage;
//
//   AnalyticsRepository({
//     required ApiClient apiClient,
//     required LocalStorageService localStorage,
//   })  : _apiClient = apiClient,
//         _localStorage = localStorage;
//
//   Future<List<TrendingItem>> getTrendingItems({
//     required String kitchenId,
//     String timeSlot = 'morning',
//     int limit = 5,
//   }) async {
//     debugPrint('[AnalyticsRepository] Fetching trending items...');
//     try {
//       final token = _localStorage.getAuthToken();
//       if (token == null || token.isEmpty) {
//         throw const AuthException(message: 'Authentication required.');
//       }
//       final headers = {
//         'Authorization': 'Bearer $token',
//         'Accept': 'application/json',
//         'Content-Type': 'application/json',
//       };
//
//       final url = '${AppConfig.baseApiUrl}${AppConfig.trendingPath}'
//           '?kitchenId=$kitchenId&timeSlot=$timeSlot&limit=$limit';
//
//       final json = await _apiClient.getJson(url, headers: headers);
//       final response = TrendingResponse.fromJson(json);
//       if (!response.success) {
//         throw ProcessingException(message: response.message);
//       }
//       return response.items;
//     } catch (e) {
//       debugPrint('[AnalyticsRepository] Error: $e');
//       final msg = ExceptionHandler.getErrorMessage(e);
//       throw Exception(msg);
//     }
//   }
// }
//
