/// Response model for subscription plans list API
class SubscriptionPlanResponse {
  final bool success;
  final String message;
  final SubscriptionPlanData? data;

  const SubscriptionPlanResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory SubscriptionPlanResponse.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? SubscriptionPlanData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Data wrapper with plans list and count
class SubscriptionPlanData {
  final List<SubscriptionPlan> plans;
  final int count;

  const SubscriptionPlanData({required this.plans, required this.count});

  factory SubscriptionPlanData.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanData(
      plans: (json['plans'] as List<dynamic>?)
          ?.map((e) =>
          SubscriptionPlan.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      count: json['count'] as int? ?? 0,
    );
  }
}

/// Individual subscription plan
class SubscriptionPlan {
  final String id;
  final String planCode;
  final String planName;
  final String planDescription;
  final String planValidity; // e.g. "7 days", "30 days"
  final double planAmount;
  final bool isActive;

  const SubscriptionPlan({
    required this.id,
    required this.planCode,
    required this.planName,
    required this.planDescription,
    required this.planValidity,
    required this.planAmount,
    required this.isActive,
  });

  /// Extracts the number of days from planValidity (e.g. "7 days" → "7")
  String get planDays {
    final match = RegExp(r'\d+').firstMatch(planValidity);
    return match?.group(0) ?? '';
  }

  /// Formatted price string for display (e.g. "₹1999")
  String get formattedPrice => '₹${planAmount.toStringAsFixed(0)}';

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['_id'] as String? ?? '',
      planCode: json['planCode'] as String? ?? '',
      planName: json['planName'] as String? ?? '',
      planDescription: json['planDescription'] as String? ?? '',
      planValidity: json['planValidity'] as String? ?? '',
      planAmount: (json['planAmount'] as num?)?.toDouble() ?? 0.0,
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}