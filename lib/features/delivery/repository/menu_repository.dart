import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_storage_service.dart';
import '../models/menu_item.dart';

/// Repository for menu-related operations
class MenuRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  MenuRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  /// Fetch menu items from API
  Future<List<MenuItem>> getMenuItems({String? mealType}) async {
    debugPrint('[MenuRepository] Fetching menu items...');

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
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      // Make GET request - fetch all items without mealType filter
      final json = await _apiClient.getJson(
        '/api/food/items',
        headers: headers,
      );

      debugPrint('[MenuRepository] Menu items response: $json');

      // Parse response - items are nested under 'data'
      final data = json['data'] as Map<String, dynamic>? ?? {};
      final items = data['items'] as List<dynamic>? ?? [];
      final count = data['count'] as int? ?? 0;

      debugPrint('[MenuRepository] Found $count items in response');

      // Convert to MenuItem list
      final menuItems = items
          .map((item) => MenuItem.fromJson(item as Map<String, dynamic>))
          .toList();

      debugPrint('[MenuRepository] Fetched ${menuItems.length} menu items from API');

      // Filter by meal type on frontend if provided
      if (mealType != null && mealType.isNotEmpty) {
        final filteredItems = menuItems
            .where((item) =>
                item.mealType.toLowerCase() == mealType.toLowerCase())
            .toList();
        debugPrint('[MenuRepository] Filtered to ${filteredItems.length} items for mealType: $mealType');
        return filteredItems;
      }

      return menuItems;
    } catch (e) {
      debugPrint('[MenuRepository] Error fetching menu items: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw Exception(message);
    }
  }
}
