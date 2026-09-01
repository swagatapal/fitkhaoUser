import 'order_preview_model.dart' show AppliedCoupon;
import 'subscription_plan_model.dart';

/// Response wrapper for GET /api/subscription/pricing-preview.
class SubscriptionPricingPreviewResponse {
  final bool success;
  final String message;
  final SubscriptionPricingPreview? data;

  const SubscriptionPricingPreviewResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory SubscriptionPricingPreviewResponse.fromJson(
      Map<String, dynamic> json) {
    final data = json['data'];
    return SubscriptionPricingPreviewResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: data is Map<String, dynamic>
          ? SubscriptionPricingPreview.fromJson(data)
          : null,
    );
  }
}

/// Everything the checkout screen needs — resolved server-side from
/// `planId` + `cancelAnytimeSelected`, so the screen never re-derives pricing.
class SubscriptionPricingPreview {
  /// Plan details + feature set (reused for the benefits list and the header).
  final SubscriptionPlan plan;

  /// Server-authoritative pricing breakdown.
  final PricingPreview pricing;

  /// Flat any-time cancellation fee echoed at the top level of `data`.
  final double cancelAnytimeFee;

  const SubscriptionPricingPreview({
    required this.plan,
    required this.pricing,
    this.cancelAnytimeFee = 0,
  });

  factory SubscriptionPricingPreview.fromJson(Map<String, dynamic> json) {
    final planJson = json['plan'] as Map<String, dynamic>? ?? const {};
    final pricingJson = json['pricing'] as Map<String, dynamic>? ?? const {};
    return SubscriptionPricingPreview(
      plan: SubscriptionPlan.fromJson(planJson),
      pricing: PricingPreview.fromJson(pricingJson),
      cancelAnytimeFee: (json['cancelAnytimeFee'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// The `pricing` block from the preview response.
class PricingPreview {
  final double planAmount;
  final bool cancelAnytimeSelected;
  final double cancelAnytimeFee;
  final double subtotal;

  /// Fractional GST rate (e.g. 0.1 = 10%).
  final double gstRate;
  final double gstAmount;
  final double totalAmount;
  final double pricePerMeal;

  /// Total coupon discount the backend actually applied.
  final double discount;

  /// The coupons the backend honoured. May be shorter than the ids that were
  /// sent — the server is free to reject one that is no longer valid.
  final List<AppliedCoupon> appliedCoupons;

  const PricingPreview({
    this.planAmount = 0,
    this.cancelAnytimeSelected = false,
    this.cancelAnytimeFee = 0,
    this.subtotal = 0,
    this.gstRate = 0,
    this.gstAmount = 0,
    this.totalAmount = 0,
    this.pricePerMeal = 0,
    this.discount = 0,
    this.appliedCoupons = const [],
  });

  /// GST as a whole-number percentage for display (0.1 → 10).
  double get gstPercent => gstRate * 100;

  /// True when a coupon actually reduced the payable amount.
  bool get hasDiscount => discount > 0;

  factory PricingPreview.fromJson(Map<String, dynamic> json) {
    return PricingPreview(
      planAmount: (json['planAmount'] as num?)?.toDouble() ?? 0,
      cancelAnytimeSelected: json['cancelAnytimeSelected'] as bool? ?? false,
      cancelAnytimeFee: (json['cancelAnytimeFee'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      gstRate: (json['gstRate'] as num?)?.toDouble() ?? 0,
      gstAmount: (json['gstAmount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      pricePerMeal: (json['pricePerMeal'] as num?)?.toDouble() ?? 0,
      // The backend has used both keys for this field; accept either.
      discount: (json['discount'] as num?)?.toDouble() ??
          (json['couponDiscount'] as num?)?.toDouble() ??
          0,
      appliedCoupons: (json['appliedCoupons'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(AppliedCoupon.fromJson)
              .toList() ??
          const [],
    );
  }
}
