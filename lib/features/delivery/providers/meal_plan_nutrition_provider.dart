import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Model for meal plan nutrition totals
class MealPlanNutrition {
  final double totalKcal;
  final double totalProtein;
  final double totalFat;
  final double totalCarbs;

  const MealPlanNutrition({
    required this.totalKcal,
    required this.totalProtein,
    required this.totalFat,
    required this.totalCarbs,
  });

  const MealPlanNutrition.empty()
      : totalKcal = 0,
        totalProtein = 0,
        totalFat = 0,
        totalCarbs = 0;
}

/// Provider to share meal plan nutrition data across widgets
final mealPlanNutritionProvider =
    StateProvider<MealPlanNutrition>((ref) => const MealPlanNutrition.empty());
