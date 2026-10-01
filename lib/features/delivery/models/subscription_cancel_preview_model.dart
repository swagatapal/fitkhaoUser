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
/// The API nests its figures in three blocks — `paymentBreakdown`,
/// `mealsBreakdown` and `refundBreakdown`. An older flat shape put the same
/// fields directly on `data`; both parse, so a server on either version works.
class SubscriptionCancelPreview {
  /// When true, the user chose "cancel anytime" → a money refund (wallet/bank).
  /// When false, the refund is issued as ₹50 coupons for the unconsumed meals.
  final bool cancelAnytimeSelected;

  /// What the user originally paid, itemised.
  final CancelPaymentBreakdown payment;

  /// Meal consumption, and what the consumed/unconsumed portions are worth.
  final CancelMealsBreakdown meals;

  /// What comes back and what does not.
  final CancelRefundBreakdown refund;

  final List<String> availableRefundMethods;
  final CancelPreviewSubscription? subscription;

  const SubscriptionCancelPreview({
    this.cancelAnytimeSelected = true,
    this.payment = const CancelPaymentBreakdown(),
    this.meals = const CancelMealsBreakdown(),
    this.refund = const CancelRefundBreakdown(),
    this.availableRefundMethods = const [],
    this.subscription,
  });

  double get refundAmount => refund.refundAmount;

  /// Everything withheld from [CancelPaymentBreakdown.totalPaid].
  ///
  /// The server's `nonRefundable.total` covers only the cancel fee, GST and
  /// consumed meals — the consultation fee is withheld too but sits outside
  /// that object (it is removed before the per-meal rate is derived). Omitting
  /// it would leave the on-screen figures failing to reconcile with the refund.
  double get totalDeducted => refund.nonRefundable.total + payment.consultationFee;

  /// True when the itemised deductions actually explain the gap between what
  /// was paid and what is refunded, so the breakdown can be shown as a sum.
  bool get deductionsReconcile =>
      payment.totalPaid > 0 &&
      (payment.totalPaid - totalDeducted - refund.refundAmount).abs() < 1.0;

  /// Number of unconsumed meals — one ₹50 coupon is issued per meal when the
  /// refund is taken as coupons (cancelAnytimeSelected == false).
  int get remainingMeals => meals.unconsumedMeals;

  /// Face value of a single meal coupon (₹).
  static const double couponValue = 50;

  factory SubscriptionCancelPreview.fromJson(Map<String, dynamic> json) {
    final sub = json['subscription'];
    Map<String, dynamic> block(String key) {
      final v = json[key];
      // Fall back to `data` itself for the older flat shape.
      return v is Map<String, dynamic> ? v : json;
    }

    return SubscriptionCancelPreview(
      cancelAnytimeSelected: json['cancelAnytimeSelected'] as bool? ?? true,
      payment: CancelPaymentBreakdown.fromJson(block('paymentBreakdown')),
      meals: CancelMealsBreakdown.fromJson(block('mealsBreakdown')),
      refund: CancelRefundBreakdown.fromJson(block('refundBreakdown')),
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

/// `data.paymentBreakdown` — what was originally paid.
class CancelPaymentBreakdown {
  final double planAmount;
  final double couponDiscount;
  final double referralDiscount;

  /// planAmount − couponDiscount − referralDiscount.
  final double paidPlanAmount;

  /// Included inside [paidPlanAmount]; withheld on cancellation.
  final double consultationFee;
  final double cancelAnytimeFee;
  final double subtotal;
  final double gstAmount;
  final double totalPaid;

  const CancelPaymentBreakdown({
    this.planAmount = 0,
    this.couponDiscount = 0,
    this.referralDiscount = 0,
    this.paidPlanAmount = 0,
    this.consultationFee = 0,
    this.cancelAnytimeFee = 0,
    this.subtotal = 0,
    this.gstAmount = 0,
    this.totalPaid = 0,
  });

  factory CancelPaymentBreakdown.fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return CancelPaymentBreakdown(
      planAmount: d('planAmount'),
      couponDiscount: d('couponDiscount'),
      referralDiscount: d('referralDiscount'),
      paidPlanAmount: d('paidPlanAmount'),
      consultationFee: d('consultationFee'),
      cancelAnytimeFee: d('cancelAnytimeFee'),
      subtotal: d('subtotal'),
      gstAmount: d('gstAmount'),
      totalPaid: d('totalPaid'),
    );
  }
}

/// `data.mealsBreakdown` — consumption and its value.
class CancelMealsBreakdown {
  final int mealsPerDay;
  final int totalMeals;
  final int mealsConsumed;
  final int unconsumedMeals;
  final double pricePerMeal;
  final double consumedValue;
  final double unconsumedValue;

  const CancelMealsBreakdown({
    this.mealsPerDay = 0,
    this.totalMeals = 0,
    this.mealsConsumed = 0,
    this.unconsumedMeals = 0,
    this.pricePerMeal = 0,
    this.consumedValue = 0,
    this.unconsumedValue = 0,
  });

  factory CancelMealsBreakdown.fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    int i(String k) => (j[k] as num?)?.toInt() ?? 0;
    final total = i('totalMeals');
    final consumed = i('mealsConsumed');
    return CancelMealsBreakdown(
      mealsPerDay: i('mealsPerDay'),
      totalMeals: total,
      mealsConsumed: consumed,
      // Derived when the older flat shape omits it.
      unconsumedMeals: j['unconsumedMeals'] != null
          ? i('unconsumedMeals')
          : (total - consumed > 0 ? total - consumed : 0),
      pricePerMeal: d('pricePerMeal'),
      consumedValue: d('consumedValue'),
      unconsumedValue: d('unconsumedValue'),
    );
  }
}

/// `data.refundBreakdown` — what comes back.
class CancelRefundBreakdown {
  final double refundableAmount;
  final CancelNonRefundable nonRefundable;
  final double refundAmount;

  const CancelRefundBreakdown({
    this.refundableAmount = 0,
    this.nonRefundable = const CancelNonRefundable(),
    this.refundAmount = 0,
  });

  factory CancelRefundBreakdown.fromJson(Map<String, dynamic> j) {
    final nr = j['nonRefundable'];
    return CancelRefundBreakdown(
      refundableAmount: (j['refundableAmount'] as num?)?.toDouble() ?? 0,
      nonRefundable: nr is Map<String, dynamic>
          ? CancelNonRefundable.fromJson(nr)
          : const CancelNonRefundable(),
      refundAmount: (j['refundAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// `refundBreakdown.nonRefundable` — note this does NOT include the
/// consultation fee; see [SubscriptionCancelPreview.totalDeducted].
class CancelNonRefundable {
  final double cancelAnytimeFee;
  final double gst;
  final double consumedMeals;
  final double total;

  const CancelNonRefundable({
    this.cancelAnytimeFee = 0,
    this.gst = 0,
    this.consumedMeals = 0,
    this.total = 0,
  });

  factory CancelNonRefundable.fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return CancelNonRefundable(
      cancelAnytimeFee: d('cancelAnytimeFee'),
      gst: d('gst'),
      consumedMeals: d('consumedMeals'),
      total: d('total'),
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
