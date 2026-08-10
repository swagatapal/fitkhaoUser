/// Response wrapper for GET /api/subscriptions/:id/cancel-preview.
class SubscriptionCancelPreviewResponse {
  final bool success;
  final String message;
  final SubscriptionCancelPreview? data;

  const SubscriptionCancelPreviewResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory SubscriptionCancelPreviewResponse.fromJson(
      Map<String, dynamic> json) {
    final data = json['data'];
    return SubscriptionCancelPreviewResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: data is Map<String, dynamic>
          ? SubscriptionCancelPreview.fromJson(data)
          : null,
    );
  }
}

/// Refund preview shown before the user confirms a subscription cancellation.
///
/// All money fields are doubles (the API may send integers or decimals).
class SubscriptionCancelPreview {
  /// When true, the user chose "cancel anytime" → a money refund (wallet/bank).
  /// When false, the refund is issued as ₹50 coupons for the unconsumed meals.
  final bool cancelAnytimeSelected;
  final double planAmount;
  final double consultationFee;
  final int mealsPerDay;
  final int totalMeals;
  final int mealsConsumed;
  final double pricePerMeal;
  final double refundAmount;
  final List<String> availableRefundMethods;
  final CancelPreviewSubscription? subscription;

  const SubscriptionCancelPreview({
    this.cancelAnytimeSelected = true,
    this.planAmount = 0,
    this.consultationFee = 0,
    this.mealsPerDay = 0,
    this.totalMeals = 0,
    this.mealsConsumed = 0,
    this.pricePerMeal = 0,
    this.refundAmount = 0,
    this.availableRefundMethods = const [],
    this.subscription,
  });

  /// Total value of the meals already consumed — deducted from the refund.
  double get consumedMealsValue => pricePerMeal * mealsConsumed;

  /// Number of unconsumed meals — one ₹50 coupon is issued per meal when the
  /// refund is taken as coupons (cancelAnytimeSelected == false).
  int get remainingMeals {
    final r = totalMeals - mealsConsumed;
    return r > 0 ? r : 0;
  }

  /// Face value of a single meal coupon (₹).
  static const double couponValue = 50;

  factory SubscriptionCancelPreview.fromJson(Map<String, dynamic> json) {
    final sub = json['subscription'];
    return SubscriptionCancelPreview(
      cancelAnytimeSelected: json['cancelAnytimeSelected'] as bool? ?? true,
      planAmount: (json['planAmount'] as num?)?.toDouble() ?? 0,
      consultationFee: (json['consultationFee'] as num?)?.toDouble() ?? 0,
      mealsPerDay: (json['mealsPerDay'] as num?)?.toInt() ?? 0,
      totalMeals: (json['totalMeals'] as num?)?.toInt() ?? 0,
      mealsConsumed: (json['mealsConsumed'] as num?)?.toInt() ?? 0,
      pricePerMeal: (json['pricePerMeal'] as num?)?.toDouble() ?? 0,
      refundAmount: (json['refundAmount'] as num?)?.toDouble() ?? 0,
      availableRefundMethods: (json['availableRefundMethods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      subscription: sub is Map<String, dynamic>
          ? CancelPreviewSubscription.fromJson(sub)
          : null,
    );
  }
}

/// Minimal subscription identity echoed back in the cancel preview.
class CancelPreviewSubscription {
  final String id;
  final String planCode;
  final String planName;
  final String status;
  final String startDate;
  final String endDate;

  const CancelPreviewSubscription({
    this.id = '',
    this.planCode = '',
    this.planName = '',
    this.status = '',
    this.startDate = '',
    this.endDate = '',
  });

  factory CancelPreviewSubscription.fromJson(Map<String, dynamic> json) {
    return CancelPreviewSubscription(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      planCode: json['planCode'] as String? ?? '',
      planName: json['planName'] as String? ?? '',
      status: json['status'] as String? ?? '',
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
    );
  }
}
