/// Response of GET /api/subscription/upcoming.
///
/// ```json
/// { "success": true, "message": "Upcoming subscriptions",
///   "data": { "count": 2, "subscriptions": [ { ... } ] } }
/// ```
class UpcomingSubscriptionsResponse {
  final bool success;
  final String message;
  final List<UpcomingSubscription> subscriptions;

  const UpcomingSubscriptionsResponse({
    required this.success,
    required this.message,
    this.subscriptions = const [],
  });

  factory UpcomingSubscriptionsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final raw = data is Map<String, dynamic> ? data['subscriptions'] : null;
    return UpcomingSubscriptionsResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      subscriptions: raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(UpcomingSubscription.fromJson)
              .toList(growable: false)
          : const [],
    );
  }
}

/// A paid subscription that has not started yet — typically a renewal queued
/// behind the active plan.
class UpcomingSubscription {
  final String id;
  final String planCode;
  final String planName;
  final double planAmount;
  final bool cancelAnytimeSelected;
  final double cancelAnytimeFee;
  final double subtotal;

  /// Fractional GST rate (0.05 = 5%).
  final double gstRate;
  final double gstAmount;
  final double totalAmount;
  final int mealsPerDay;
  final double consultationFee;
  final double pricePerMeal;
  final String paymentMethod;
  final String paymentStatus;
  final String status;
  final String startDate;
  final String endDate;
  final String serviceStartDate;

  /// Days until this subscription starts.
  final int remainingDays;
  final bool isRenewal;

  const UpcomingSubscription({
    required this.id,
    this.planCode = '',
    this.planName = '',
    this.planAmount = 0,
    this.cancelAnytimeSelected = false,
    this.cancelAnytimeFee = 0,
    this.subtotal = 0,
    this.gstRate = 0,
    this.gstAmount = 0,
    this.totalAmount = 0,
    this.mealsPerDay = 0,
    this.consultationFee = 0,
    this.pricePerMeal = 0,
    this.paymentMethod = '',
    this.paymentStatus = '',
    this.status = '',
    this.startDate = '',
    this.endDate = '',
    this.serviceStartDate = '',
    this.remainingDays = 0,
    this.isRenewal = false,
  });

  /// GST as a whole-number percentage for display (0.05 → 5).
  double get gstPercent => gstRate * 100;

  /// Wallet payments read "Wallet"; anything else is an online payment.
  String get paymentMethodLabel =>
      paymentMethod.toLowerCase() == 'wallet' ? 'FitKhao Wallet' : 'Online';

  factory UpcomingSubscription.fromJson(Map<String, dynamic> json) {
    double d(String k) => (json[k] as num?)?.toDouble() ?? 0;
    return UpcomingSubscription(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      planCode: json['planCode'] as String? ?? '',
      planName: json['planName'] as String? ?? '',
      planAmount: d('planAmount'),
      cancelAnytimeSelected: json['cancelAnytimeSelected'] as bool? ?? false,
      cancelAnytimeFee: d('cancelAnytimeFee'),
      subtotal: d('subtotal'),
      gstRate: d('gstRate'),
      gstAmount: d('gstAmount'),
      totalAmount: d('totalAmount'),
      mealsPerDay: (json['mealsPerDay'] as num?)?.toInt() ?? 0,
      consultationFee: d('consultationFee'),
      pricePerMeal: d('pricePerMeal'),
      paymentMethod: json['paymentMethod'] as String? ?? '',
      paymentStatus: json['paymentStatus'] as String? ?? '',
      status: json['status'] as String? ?? '',
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      serviceStartDate: json['serviceStartDate'] as String? ?? '',
      remainingDays: (json['remainingDays'] as num?)?.toInt() ?? 0,
      isRenewal: json['isRenewal'] as bool? ?? false,
    );
  }
}

/// Response of POST /api/subscriptions/{id}/cancel-upcoming.
///
/// ```json
/// { "success": true, "message": "Upcoming subscription cancelled successfully",
///   "data": { "subscription": { ... }, "refundStatus": "pending",
///             "note": "Refund will be processed through a separate payment flow." } }
/// ```
class CancelUpcomingResponse {
  final bool success;
  final String message;
  final String refundStatus;

  /// Free-text note from the backend about the refund, shown to the user.
  final String note;

  const CancelUpcomingResponse({
    required this.success,
    required this.message,
    this.refundStatus = '',
    this.note = '',
  });

  factory CancelUpcomingResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    return CancelUpcomingResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      refundStatus: map['refundStatus'] as String? ?? '',
      note: map['note'] as String? ?? '',
    );
  }
}
