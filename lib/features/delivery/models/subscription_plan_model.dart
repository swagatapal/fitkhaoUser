/// Features included in a subscription plan
class PlanFeatures {
  final bool dietChart;
  final bool suggestedPlan;
  final int consultationCount;
  final int mealCountPerDay;
  final bool freeDelivery;
  final bool snacks;
  final int discountPercent;
  final bool planBasedMealsAssgn;

  const PlanFeatures({
    this.dietChart = false,
    this.suggestedPlan = false,
    this.consultationCount = 0,
    this.mealCountPerDay = 0,
    this.freeDelivery = false,
    this.snacks = false,
    this.discountPercent = 0,
    this.planBasedMealsAssgn = false,
  });

  factory PlanFeatures.fromJson(Map<String, dynamic> json) {
    return PlanFeatures(
      dietChart: json['dietChart'] as bool? ?? false,
      suggestedPlan: json['suggestedPlan'] as bool? ?? false,
      consultationCount: (json['consultationCount'] as num?)?.toInt() ?? 0,
      mealCountPerDay: (json['mealCountPerDay'] as num?)?.toInt() ?? 0,
      freeDelivery: json['freeDelivery'] as bool? ?? false,
      snacks: json['snacks'] as bool? ?? false,
      discountPercent: (json['discountPercent'] as num?)?.toInt() ?? 0,
      planBasedMealsAssgn: json['planBasedMealsAssgn'] as bool? ?? false,
    );
  }
}

/// Rules/permissions for a subscription plan
class PlanRules {
  final bool walletEnabled;
  final bool canUpgrade;
  final bool canSlotChoose;
  final bool canCancel;

  const PlanRules({
    this.walletEnabled = false,
    this.canUpgrade = false,
    this.canSlotChoose = false,
    this.canCancel = false,
  });

  factory PlanRules.fromJson(Map<String, dynamic> json) {
    return PlanRules(
      walletEnabled: json['walletEnabled'] as bool? ?? false,
      canUpgrade: json['canUpgrade'] as bool? ?? false,
      canSlotChoose: json['canSlotChoose'] as bool? ?? false,
      canCancel: json['canCancel'] as bool? ?? false,
    );
  }
}

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
              ?.map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
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
  final int durationInDays;
  final double price;
  final double consultationFee;
  final double gstPercentage;
  final double otherFeeAmt;
  final bool isActive;
  final PlanFeatures features;
  final PlanRules rules;

  const SubscriptionPlan({
    required this.id,
    required this.planCode,
    required this.planName,
    required this.durationInDays,
    required this.price,
    this.consultationFee = 0,
    this.gstPercentage = 0,
    this.otherFeeAmt = 0,
    required this.isActive,
    this.features = const PlanFeatures(),
    this.rules = const PlanRules(),
  });

  /// Number of days as a string — used by SubscriptionCheckoutScreen
  String get planDays => durationInDays.toString();

  /// Human-readable validity — used in the "Buy X Plan" button label
  String get planValidity => '$durationInDays Days';

  /// Formatted price string (e.g. "₹3999")
  String get formattedPrice => '₹${price.toStringAsFixed(0)}';

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['_id'] as String? ?? '',
      planCode: json['planCode'] as String? ?? '',
      // New API: 'name', legacy fallback: 'planName'
      planName: json['name'] as String? ?? json['planName'] as String? ?? '',
      // New API: 'durationInDays', legacy fallback: parse from 'planValidity'
      durationInDays: json['durationInDays'] as int? ??
          _parseDurationFromValidity(json['planValidity'] as String?),
      // New API: 'price', legacy fallback: 'planAmount'
      price: (json['price'] as num?)?.toDouble() ??
          (json['planAmount'] as num?)?.toDouble() ??
          0.0,
      consultationFee: (json['consultationFee'] as num?)?.toDouble() ?? 0.0,
      gstPercentage: (json['gstPercentage'] as num?)?.toDouble() ?? 0.0,
      otherFeeAmt: (json['otherFeeAmt'] as num?)?.toDouble() ?? 0.0,
      isActive: json['isActive'] as bool? ?? false,
      features: json['features'] != null
          ? PlanFeatures.fromJson(json['features'] as Map<String, dynamic>)
          : const PlanFeatures(),
      rules: json['rules'] != null
          ? PlanRules.fromJson(json['rules'] as Map<String, dynamic>)
          : const PlanRules(),
    );
  }

  static int _parseDurationFromValidity(String? validity) {
    if (validity == null) return 30;
    final match = RegExp(r'\d+').firstMatch(validity);
    return int.tryParse(match?.group(0) ?? '') ?? 30;
  }
}
