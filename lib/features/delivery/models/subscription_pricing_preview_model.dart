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

  /// Discount granted by the referral code, from `data.referralDiscount`.
  ///
  /// This is a **sibling** of `pricing`, not part of it — the coupon discount
  /// lives at `pricing.couponDiscount`. The two are distinct concessions and
  /// are deliberately kept apart so the summary can itemise each.
  final double referralDiscount;

  /// Total saved versus [originalPricing], from `data.savings`.
  final double savings;

  /// Pricing before the referral was applied. Present only when a referral
  /// code was sent; identical to [pricing] when the referral gives nothing.
  final PricingPreview? originalPricing;

  /// The referral the server honoured, when one was sent.
  final AppliedReferral? referral;

  /// Coupons the server actually honoured, from `data.appliedCoupons`.
  ///
  /// NOTE this lives at `data` level, NOT inside `pricing` — parsing it from
  /// `pricing` yields an empty list and loses the coupon code on the summary.
  final List<AppliedCoupon> appliedCoupons;

  const SubscriptionPricingPreview({
    required this.plan,
    required this.pricing,
    this.cancelAnytimeFee = 0,
    this.referralDiscount = 0,
    this.savings = 0,
    this.originalPricing,
    this.referral,
    this.appliedCoupons = const [],
  });

  /// True when the referral actually reduced the price.
  bool get hasReferralDiscount => referralDiscount > 0;

  /// Coupon discount — the sum of what each honoured coupon actually took off,
  /// from `appliedCoupons[].discountAmount`, and nothing else.
  ///
  /// There is deliberately NO fallback to the aggregate `couponDiscount`
  /// fields. When a referral is applied the backend puts the referral's value
  /// in those aggregates, so falling back to them made a coupon row appear —
  /// showing the referral's amount — even when the user had chosen no coupon.
  /// No applied coupons means no coupon discount, full stop.
  double get couponDiscount =>
      appliedCoupons.fold<double>(0, (sum, c) => sum + c.discountAmount);

  /// True when a coupon actually reduced the price.
  bool get hasCouponDiscount => couponDiscount > 0;

  /// "Coupon discount (SAVE20)" — names the coupon(s) the server honoured.
  String get couponDiscountLabel {
    final codes = appliedCoupons
        .map((c) => c.code)
        .where((c) => c.isNotEmpty)
        .toList(growable: false);
    if (codes.isEmpty) return 'Coupon discount';
    return 'Coupon discount (${codes.join(', ')})';
  }

  factory SubscriptionPricingPreview.fromJson(Map<String, dynamic> json) {
    final planJson = json['plan'] as Map<String, dynamic>? ?? const {};
    final pricingJson = json['pricing'] as Map<String, dynamic>? ?? const {};
    final originalJson = json['originalPricing'];
    final referralJson = json['referral'];
    return SubscriptionPricingPreview(
      plan: SubscriptionPlan.fromJson(planJson),
      pricing: PricingPreview.fromJson(pricingJson),
      cancelAnytimeFee: (json['cancelAnytimeFee'] as num?)?.toDouble() ?? 0,
      referralDiscount: (json['referralDiscount'] as num?)?.toDouble() ?? 0,
      savings: (json['savings'] as num?)?.toDouble() ?? 0,
      originalPricing: originalJson is Map<String, dynamic>
          ? PricingPreview.fromJson(originalJson)
          : null,
      referral: referralJson is Map<String, dynamic>
          ? AppliedReferral.fromJson(referralJson)
          : null,
      // `data.appliedCoupons` is the real location; the `pricing` fallback
      // only covers a backend that ever nests it instead.
      appliedCoupons: _parseAppliedCoupons(
        json['appliedCoupons'] ?? pricingJson['appliedCoupons'],
      ),
    );
  }
}

List<AppliedCoupon> _parseAppliedCoupons(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(AppliedCoupon.fromJson)
      .toList(growable: false);
}

/// The referral echoed back by the pricing preview (`data.referral`).
class AppliedReferral {
  final String code;
  final String name;
  final String type;
  final String subType;

  const AppliedReferral({
    this.code = '',
    this.name = '',
    this.type = '',
    this.subType = '',
  });

  factory AppliedReferral.fromJson(Map<String, dynamic> json) {
    return AppliedReferral(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      subType: json['subType'] as String? ?? '',
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

  /// Coupon discount only, from `pricing.couponDiscount`.
  ///
  /// Does NOT include the referral discount, which the server reports
  /// separately as `data.referralDiscount` — see
  /// [SubscriptionPricingPreview.referralDiscount]. The two are itemised
  /// independently in the payment summary and must never be merged.
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
      // Coupon discount ONLY, and deliberately read from `couponDiscount`
      // alone. A generic `discount` key must not be used as a fallback here:
      // when a referral is applied the backend reports the *combined*
      // concession in it, which would silently merge the referral into the
      // coupon row. The referral figure is read separately from
      // `data.referralDiscount` by SubscriptionPricingPreview.
      discount: (json['couponDiscount'] as num?)?.toDouble() ?? 0,
      appliedCoupons: (json['appliedCoupons'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(AppliedCoupon.fromJson)
              .toList() ??
          const [],
    );
  }
}
