// Models for the assigned meal plan API response

/// Parses an API date string as a local date (date-only), stripping any
/// UTC offset so that "2026-04-25T00:00:00.000Z" always becomes 2026-04-25
/// regardless of the device timezone.
DateTime _parseApiDate(String raw) {
  if (raw.isEmpty) return DateTime.now();
  // Take only the date portion (YYYY-MM-DD) before any T/space
  final datePart = raw.split('T').first.split(' ').first;
  return DateTime.tryParse(datePart) ?? DateTime.now();
}

class MealPlanResponse {
  final bool success;
  final String message;
  final MealPlan? mealPlan;

  const MealPlanResponse({
    required this.success,
    required this.message,
    this.mealPlan,
  });

  factory MealPlanResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return MealPlanResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      mealPlan: data?['mealPlan'] != null
          ? MealPlan.fromJson(data!['mealPlan'] as Map<String, dynamic>)
          : null,
    );
  }
}

class MealPlan {
  final String id;
  final String userId;
  final String remarks;
  final List<MealPlanDay> days;

  const MealPlan({
    required this.id,
    required this.userId,
    required this.remarks,
    required this.days,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      id: json['_id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      remarks: json['remarks'] as String? ?? '',
      days: (json['days'] as List<dynamic>?)
              ?.where((d) => (d as Map<String, dynamic>)['isDeleted'] != true)
              .map((d) => MealPlanDay.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Sorted unique dates with available meal data
  List<DateTime> get availableDates {
    return days
        .map((d) => DateTime(d.date.year, d.date.month, d.date.day))
        .toSet()
        .toList()
      ..sort();
  }

  /// Returns the day entry for a given date (date-only comparison)
  MealPlanDay? dayForDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    try {
      return days.firstWhere((d) {
        final dd = DateTime(d.date.year, d.date.month, d.date.day);
        return dd == target;
      });
    } catch (_) {
      return null;
    }
  }
}

class MealPlanDay {
  final DateTime date;
  final bool isDeleted;
  final List<MealPlanMeal> meals;

  const MealPlanDay({
    required this.date,
    required this.isDeleted,
    required this.meals,
  });

  factory MealPlanDay.fromJson(Map<String, dynamic> json) {
    return MealPlanDay(
      date: _parseApiDate(json['date'] as String? ?? ''),
      isDeleted: json['isDeleted'] as bool? ?? false,
      meals: (json['meals'] as List<dynamic>?)
              ?.map((m) => MealPlanMeal.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class MealPlanMeal {
  final MealCategory category;
  final List<MealPlanDish> dishes;

  const MealPlanMeal({required this.category, required this.dishes});

  factory MealPlanMeal.fromJson(Map<String, dynamic> json) {
    return MealPlanMeal(
      category: MealCategory.fromJson(
          json['category'] as Map<String, dynamic>? ?? {}),
      dishes: (json['dishes'] as List<dynamic>?)
              ?.map((d) => MealPlanDish.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class MealCategory {
  final String id;
  final String dishCategory;
  final bool isActive;

  const MealCategory({
    required this.id,
    required this.dishCategory,
    required this.isActive,
  });

  factory MealCategory.fromJson(Map<String, dynamic> json) {
    return MealCategory(
      id: json['_id'] as String? ?? '',
      dishCategory: json['dishCategory'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class MealPlanDish {
  final String id;
  final String dishCode;
  final String dishName;
  final List<DishTypeLabel> dishTypes;
  final MealNutrition nutrition;
  final double marketPrice;
  final String orderMeasuringUnit;
  final bool isActive;
  final int dishServing;

  const MealPlanDish({
    required this.id,
    required this.dishCode,
    required this.dishName,
    required this.dishTypes,
    required this.nutrition,
    required this.marketPrice,
    required this.orderMeasuringUnit,
    required this.isActive,
    required this.dishServing,
  });

  bool get isVeg {
    if (dishTypes.isEmpty) return true;
    final typeStr = dishTypes.first.dishType.toLowerCase();
    return typeStr == 'veg' || typeStr == 'vegan' || typeStr == 'smoothie';
  }

  factory MealPlanDish.fromJson(Map<String, dynamic> json) {
    return MealPlanDish(
      id: json['_id'] as String? ?? '',
      dishCode: json['dishCode'] as String? ?? '',
      dishName: json['dishName'] as String? ?? '',
      dishTypes: (json['dishType'] as List<dynamic>?)
              ?.map((t) => DishTypeLabel.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      nutrition: json['nutritionalValue'] != null
          ? MealNutrition.fromJson(
              json['nutritionalValue'] as Map<String, dynamic>)
          : const MealNutrition(kcal: 0, protein: 0, fat: 0, carbs: 0),
      marketPrice: (json['marketPrice'] as num?)?.toDouble() ?? 0.0,
      orderMeasuringUnit: json['orderMeasuringUnit'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      dishServing: json['dishServing'] as int? ?? 1,
    );
  }
}

class DishTypeLabel {
  final String id;
  final String dishType;

  const DishTypeLabel({required this.id, required this.dishType});

  factory DishTypeLabel.fromJson(Map<String, dynamic> json) {
    return DishTypeLabel(
      id: json['_id'] as String? ?? '',
      dishType: json['dishType'] as String? ?? '',
    );
  }
}

class MealNutrition {
  final double kcal;
  final double protein;
  final double fat;
  final double carbs;

  const MealNutrition({
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  factory MealNutrition.fromJson(Map<String, dynamic> json) {
    return MealNutrition(
      kcal: (json['kcal'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
