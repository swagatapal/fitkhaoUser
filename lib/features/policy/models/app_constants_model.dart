/// Pricing constants from data.pricing in the /api/app/constants response.
class PricingConstants {
  /// Fixed platform fee added on top of the plan price (in ₹).
  final double platformFee;

  /// GST rate as a percentage (e.g. 18 means 18%). Applied on planPrice + platformFee.
  final double gstRate;

  /// Fixed delivery charge (in ₹).
  final double deliveryCharge;

  /// Minimum wallet top-up amount in ₹.
  final int minTopupAmount;

  /// Maximum wallet top-up amount in ₹.
  final int maxTopupAmount;

  const PricingConstants({
    this.platformFee = 7,
    this.gstRate = 5,
    this.deliveryCharge = 0,
    this.minTopupAmount = 1,
    this.maxTopupAmount = 10000,
  });

  static const PricingConstants defaults = PricingConstants();

  factory PricingConstants.fromMap(Map<String, dynamic> map) {
    return PricingConstants(
      platformFee: (map['platformFee'] as num?)?.toDouble() ?? 7,
      gstRate: (map['gstRate'] as num?)?.toDouble() ?? 5,
      deliveryCharge: (map['deliveryCharge'] as num?)?.toDouble() ?? 0,
      minTopupAmount: (map['minTopupAmount'] as num?)?.toInt() ?? 1,
      maxTopupAmount: (map['maxTopupAmount'] as num?)?.toInt() ?? 10000,
    );
  }
}

/// App-wide runtime constants fetched from /api/app/constants.
/// All values fall back to safe defaults so the app never breaks if the
/// API is unreachable or a field is absent.
class AppConstants {
  /// Default cancel window used when the API is unavailable or
  /// data.order.cancellationTime is missing.
  static const int _kDefaultCancelWindowSeconds = 30;

  /// Default cutoff hour (IST) for changing/cancelling a subscription-slot
  /// order on its delivery day.
  static const int _kDefaultSlotChangeCutoffHour = 6;

  /// How long (in seconds) after placing an order the user can cancel it.
  /// Sourced from data.order.cancellationTime in the constants API response.
  final int cancelOrderWindowSeconds;

  /// Latest hour (0–23, IST) on the delivery day a subscription-slot order can
  /// be changed or cancelled. Sourced from
  /// data.order.subscriptionSlotChangeCutoffHour.
  final int subscriptionSlotChangeCutoffHour;

  /// Pricing configuration (platform fee, GST rate, delivery charge).
  final PricingConstants pricing;

  /// Flat fee (in ₹) charged for any-time subscription cancellation.
  /// Sourced from data.subscription.anyTimeCancellationFees.
  final double subscriptionCancellationFee;

  const AppConstants({
    this.cancelOrderWindowSeconds = _kDefaultCancelWindowSeconds,
    this.subscriptionSlotChangeCutoffHour = _kDefaultSlotChangeCutoffHour,
    this.pricing = PricingConstants.defaults,
    this.subscriptionCancellationFee = 0,
  });

  static const AppConstants defaults = AppConstants();

  /// Parse directly from the top-level API response map.
  ///
  /// Expected shape:
  /// ```json
  /// {
  ///   "data": {
  ///     "order": { "cancellationTime": 30 },
  ///     "pricing": { "platformFee": 0, "gstRate": 18, "deliveryCharge": 0 },
  ///     ...
  ///   }
  /// }
  /// ```
  factory AppConstants.fromApiResponse(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;

    final order = data?['order'] as Map<String, dynamic>?;
    // API returns cancellationTime in milliseconds; convert to seconds.
    final cancellationMs = (order?['cancellationTime'] as num?)?.toInt();
    final cancellationTime = cancellationMs != null
        ? (cancellationMs / 1000).round()
        : _kDefaultCancelWindowSeconds;

    final slotCutoffHour =
        (order?['subscriptionSlotChangeCutoffHour'] as num?)?.toInt() ??
            _kDefaultSlotChangeCutoffHour;

    final pricingMap = data?['pricing'] as Map<String, dynamic>? ?? {};
    final pricing = PricingConstants.fromMap(pricingMap);

    final subscription = data?['subscription'] as Map<String, dynamic>?;
    final subscriptionCancellationFee =
        (subscription?['anyTimeCancellationFees'] as num?)?.toDouble() ?? 0;

    return AppConstants(
      cancelOrderWindowSeconds: cancellationTime,
      subscriptionSlotChangeCutoffHour: slotCutoffHour,
      pricing: pricing,
      subscriptionCancellationFee: subscriptionCancellationFee,
    );
  }
}
