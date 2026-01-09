/// Response model for nutrition progress API
class NutritionProgressResponse {
  final bool success;
  final String message;
  final NutritionProgressData? data;

  const NutritionProgressResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory NutritionProgressResponse.fromJson(Map<String, dynamic> json) {
    return NutritionProgressResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? NutritionProgressData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Nutrition progress data
class NutritionProgressData {
  final String userId;
  final String date;
  final NutritionTargets targets;
  final NutritionProgress progress;

  const NutritionProgressData({
    required this.userId,
    required this.date,
    required this.targets,
    required this.progress,
  });

  factory NutritionProgressData.fromJson(Map<String, dynamic> json) {
    return NutritionProgressData(
      userId: json['userId'] as String? ?? '',
      date: json['date'] as String? ?? '',
      targets: NutritionTargets.fromJson(
        json['targets'] as Map<String, dynamic>? ?? {},
      ),
      progress: NutritionProgress.fromJson(
        json['progress'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// Nutrition targets
class NutritionTargets {
  final double calories;
  final double protein;
  final double fat;
  final double carbs;

  const NutritionTargets({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  factory NutritionTargets.fromJson(Map<String, dynamic> json) {
    return NutritionTargets(
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Overall nutrition progress
class NutritionProgress {
  final MacroProgress calories;
  final MacroProgress protein;
  final MacroProgress fat;
  final MacroProgress carbs;

  const NutritionProgress({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  factory NutritionProgress.fromJson(Map<String, dynamic> json) {
    return NutritionProgress(
      calories: MacroProgress.fromJson(
        json['calories'] as Map<String, dynamic>? ?? {},
      ),
      protein: MacroProgress.fromJson(
        json['protein'] as Map<String, dynamic>? ?? {},
      ),
      fat: MacroProgress.fromJson(
        json['fat'] as Map<String, dynamic>? ?? {},
      ),
      carbs: MacroProgress.fromJson(
        json['carbs'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// Progress for individual macro
class MacroProgress {
  final double consumed;
  final double remaining;
  final int percentage;

  const MacroProgress({
    required this.consumed,
    required this.remaining,
    required this.percentage,
  });

  factory MacroProgress.fromJson(Map<String, dynamic> json) {
    return MacroProgress(
      consumed: (json['consumed'] as num?)?.toDouble() ?? 0.0,
      remaining: (json['remaining'] as num?)?.toDouble() ?? 0.0,
      percentage: json['percentage'] as int? ?? 0,
    );
  }
}
