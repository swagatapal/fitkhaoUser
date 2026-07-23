// Models for meal (dish) categories (GET /api/adm/dish-category)

class DishCategory {
  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;

  const DishCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
  });

  factory DishCategory.fromJson(Map<String, dynamic> json) {
    return DishCategory(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['dishCategory'] as String? ?? json['name'] as String? ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class DishCategoryResponse {
  final bool success;
  final String message;
  final List<DishCategory> categories;

  const DishCategoryResponse({
    required this.success,
    required this.message,
    required this.categories,
  });

  factory DishCategoryResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final raw = (data is Map<String, dynamic> ? data['dishCategories'] : data)
        as List<dynamic>?;
    return DishCategoryResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      categories: raw
              ?.whereType<Map<String, dynamic>>()
              .map(DishCategory.fromJson)
              .toList() ??
          const [],
    );
  }
}
