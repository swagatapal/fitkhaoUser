/// Response wrapper for POST /api/orders/preview.
class OrderPreviewResponse {
  final bool success;
  final String message;
  final OrderPreview? data;

  const OrderPreviewResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory OrderPreviewResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return OrderPreviewResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: data is Map<String, dynamic> ? OrderPreview.fromJson(data) : null,
    );
  }
}

/// Server-authoritative order preview — the single source of truth for the
/// checkout summary (pricing, applied coupons, subscription discount).
class OrderPreview {
  final String deliveryDate;
  final String kitchenId;
  final bool hasSubscription;
  final OrderPreviewPricing pricing;

  const OrderPreview({
    this.deliveryDate = '',
    this.kitchenId = '',
    this.hasSubscription = false,
    this.pricing = const OrderPreviewPricing(),
  });

  factory OrderPreview.fromJson(Map<String, dynamic> json) {
    return OrderPreview(
      deliveryDate: json['deliveryDate'] as String? ?? '',
      kitchenId: json['kitchenId'] as String? ?? '',
      hasSubscription: json['hasSubscription'] as bool? ?? false,
      pricing: json['pricing'] is Map<String, dynamic>
          ? OrderPreviewPricing.fromJson(json['pricing'] as Map<String, dynamic>)
          : const OrderPreviewPricing(),
    );
  }
}

/// The `pricing` block of the order preview.
class OrderPreviewPricing {
  final double subtotal;
  final double gstRate; // fractional (0.1 = 10%)
  final double gstAmount;
  final double platformFee;
  final double deliveryCharge;

  /// Total coupon discount.
  final double discount;
  final double subscriptionDiscountPercent;
  final double subscriptionDiscount;
  final List<AppliedCoupon> appliedCoupons;
  final double total;

  const OrderPreviewPricing({
    this.subtotal = 0,
    this.gstRate = 0,
    this.gstAmount = 0,
    this.platformFee = 0,
    this.deliveryCharge = 0,
    this.discount = 0,
    this.subscriptionDiscountPercent = 0,
    this.subscriptionDiscount = 0,
    this.appliedCoupons = const [],
    this.total = 0,
  });

  /// GST as a whole-number percentage for display (0.1 → 10).
  double get gstPercent => gstRate * 100;

  factory OrderPreviewPricing.fromJson(Map<String, dynamic> json) {
    double d(String k) => (json[k] as num?)?.toDouble() ?? 0;
    return OrderPreviewPricing(
      subtotal: d('subtotal'),
      gstRate: d('gstRate'),
      gstAmount: d('gstAmount'),
      platformFee: d('platformFee'),
      deliveryCharge: d('deliveryCharge'),
      discount: d('discount'),
      subscriptionDiscountPercent: d('subscriptionDiscountPercent'),
      subscriptionDiscount: d('subscriptionDiscount'),
      appliedCoupons: (json['appliedCoupons'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(AppliedCoupon.fromJson)
              .toList() ??
          const [],
      total: d('total'),
    );
  }
}

/// A coupon the backend actually applied to this preview.
class AppliedCoupon {
  final String ruleId;
  final String code;
  final String name;
  final double discountAmount;

  const AppliedCoupon({
    this.ruleId = '',
    this.code = '',
    this.name = '',
    this.discountAmount = 0,
  });

  factory AppliedCoupon.fromJson(Map<String, dynamic> json) {
    return AppliedCoupon(
      ruleId: json['ruleId'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}
