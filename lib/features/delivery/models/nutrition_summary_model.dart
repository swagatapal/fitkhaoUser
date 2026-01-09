/// Response model for nutrition summary API
class NutritionSummaryResponse {
  final bool success;
  final String message;
  final NutritionSummaryData? data;

  const NutritionSummaryResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory NutritionSummaryResponse.fromJson(Map<String, dynamic> json) {
    return NutritionSummaryResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? NutritionSummaryData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Nutrition summary data
class NutritionSummaryData {
  final String userId;
  final String date;
  final NutritionTotals totals;

  const NutritionSummaryData({
    required this.userId,
    required this.date,
    required this.totals,
  });

  factory NutritionSummaryData.fromJson(Map<String, dynamic> json) {
    return NutritionSummaryData(
      userId: json['userId'] as String? ?? '',
      date: json['date'] as String? ?? '',
      totals: NutritionTotals.fromJson(
        json['totals'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// Daily nutrition totals
class NutritionTotals {
  final double calories;
  final double protein;
  final double fat;
  final double carbs;

  const NutritionTotals({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  factory NutritionTotals.fromJson(Map<String, dynamic> json) {
    return NutritionTotals(
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
