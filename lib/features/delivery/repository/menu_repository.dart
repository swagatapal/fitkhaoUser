import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
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

  // ─── Auth helpers ──────────────────────────────────────────────────────────

  Map<String, String> _authHeaders() {
    final token = _localStorage.getAuthToken();
    if (token == null || token.isEmpty) {
      throw AuthException(
        message: 'Authentication required. Please login again.',
      );
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // ─── Categories ────────────────────────────────────────────────────────────

  /// Fetch all active dish categories, ordered by [displayOrder].
  /// Returns an empty list on any failure so callers can degrade gracefully.
  Future<List<DishCategory>> getCategories() async {
    debugPrint('[MenuRepository] Fetching dish categories…');
    try {
      final json = await _apiClient.getJson(
        '${AppConfig.outletDishCategoryPath}?isActive=true',
        headers: _authHeaders(),
      );

      // Response: { "data": { "categories": [...], "count": N } }
      final data = json['data'] as Map<String, dynamic>? ?? {};
      final rawList =
          data['categories'] as List<dynamic>?           // new API
          ?? json['categories'] as List<dynamic>?        // legacy flat
          ?? data['items'] as List<dynamic>?             // fallback key
          ?? [];

      final categories = rawList
          .whereType<Map<String, dynamic>>()
          .map(DishCategory.fromJson)
          .where((c) => c.id.isNotEmpty && c.name.isNotEmpty)
          .toList();

      // Preserve server ordering; fall back to alpha sort when displayOrder
      // is absent (all zeros) so the list is at least deterministic.
      final hasExplicitOrder = categories.any((c) => c.displayOrder > 0);
      if (hasExplicitOrder) {
        categories.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      }

      debugPrint('[MenuRepository] Fetched ${categories.length} categories');
      return categories;
    } catch (e) {
      debugPrint('[MenuRepository] Error fetching categories: $e');
      return [];
    }
  }

  // ─── Dishes ────────────────────────────────────────────────────────────────

  /// Fetch a single page of menu items.
  ///
  /// [categoryId] — when supplied, only items in that category are returned.
  /// [mealType]   — optional client-side meal-type filter (legacy support).
  Future<MenuPageResult> getMenuPage({
    String? categoryId,
    String? mealType,
    int pageIndex = 0,
    int pageSize = 20,
  }) async {
    debugPrint('[MenuRepository] Fetching dish page $pageIndex '
        '(category: $categoryId, pageSize: $pageSize)…');

    try {
      final buffer = StringBuffer(
        '${AppConfig.outletDishPath}?isActive=true'
        '&pageIndex=$pageIndex&pageSize=${200}',
        //'&pageIndex=$pageIndex&pageSize=$pageSize',
      );
      if (categoryId != null && categoryId.isNotEmpty) {
        buffer.write('&category=$categoryId');
      }

      final json = await _apiClient.getJson(
        buffer.toString(),
        headers: _authHeaders(),
      );

      final data = json['data'] as Map<String, dynamic>? ?? {};
      final rawItems = data['dishes'] as List<dynamic>?
          ?? data['items'] as List<dynamic>?
          ?? [];
      final totalCount = (data['count'] as num?)?.toInt()
          ?? (data['totalCount'] as num?)?.toInt()
          ?? rawItems.length;
      final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;

      debugPrint(
        '[MenuRepository] Page $pageIndex/$totalPages — ${rawItems.length} items',
      );

      var menuItems = rawItems
          .map((item) => MenuItem.fromJson(item as Map<String, dynamic>))
          .toList();

      // Legacy meal-type client-side filter (used by MenuListScreen)
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

  /// Convenience method — returns all items from page 0 (used by MenuListScreen).
  Future<List<MenuItem>> getMenuItems({String? mealType}) async {
    final result = await getMenuPage(mealType: mealType);
    return result.items;
  }
}
