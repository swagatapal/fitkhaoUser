import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_storage_service.dart';
import '../models/menu_item.dart';

class MenuPageResult {
  final List<MenuItem> items;
  final int totalCount;
  final int totalPages;
  final int currentPage;

  const MenuPageResult({
    required this.items,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
  });
}

/// Repository for menu-related operations
class MenuRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  MenuRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  /// Fetch a single page of menu items.
  Future<MenuPageResult> getMenuPage({
    String? mealType,
    int pageIndex = 0,
    int pageSize = 5,
  }) async {
    debugPrint('[MenuRepository] Fetching menu page $pageIndex...');

    try {
      final token = _localStorage.getAuthToken();
      if (token == null || token.isEmpty) {
        throw AuthException(
          message: 'Authentication required. Please login again.',
        );
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final json = await _apiClient.getJson(
        '/api/adm/outlet-dish?pageIndex=$pageIndex&pageSize=$pageSize',
        headers: headers,
      );

      final data = json['data'] as Map<String, dynamic>? ?? {};
      final rawItems = data['dishes'] as List<dynamic>? ??
          data['items'] as List<dynamic>? ??
          [];
      final totalCount = (data['count'] as num?)?.toInt() ??
          (data['totalCount'] as num?)?.toInt() ??
          rawItems.length;
      final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;

      debugPrint('[MenuRepository] Page $pageIndex/$totalPages — ${rawItems.length} items');

      var menuItems = rawItems
          .map((item) => MenuItem.fromJson(item as Map<String, dynamic>))
          .toList();

      if (mealType != null && mealType.isNotEmpty) {
        final lower = mealType.toLowerCase();
        menuItems = menuItems.where((item) {
          if (item.applicableMealTypes.isNotEmpty) {
            return item.applicableMealTypes.contains(lower);
          }
          return item.mealType.toLowerCase() == lower;
        }).toList();
      }

      return MenuPageResult(
        items: menuItems,
        totalCount: totalCount,
        totalPages: totalPages,
        currentPage: pageIndex,
      );
    } catch (e) {
      debugPrint('[MenuRepository] Error fetching menu items: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw Exception(message);
    }
  }

  /// Convenience method — returns all items from page 1 (used by MenuListScreen).
  Future<List<MenuItem>> getMenuItems({String? mealType}) async {
    final result = await getMenuPage(mealType: mealType);
    return result.items;
  }
}
