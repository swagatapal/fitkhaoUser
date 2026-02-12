import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Model for meal category from meal plan API
class MealCategoryItem {
  final String id;
  final String name;
  final bool isActive;

  const MealCategoryItem({
    required this.id,
    required this.name,
    required this.isActive,
  });
}

/// Provider to share meal categories from MealPlanWidget to DeliverySlotSelector
final mealCategoryListProvider =
    StateProvider<List<MealCategoryItem>>((ref) => []);
