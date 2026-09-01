/// Request model for creating a subscription via wallet.
/// POST /api/subscription/create
class SubscriptionRequest {
  final String planId;
  final bool cancelAnytimeSelected;

  /// Rule ids of the coupons to redeem. Omitted from the body when empty.
  final List<String> couponIds;

  const SubscriptionRequest({
    required this.planId,
    this.cancelAnytimeSelected = false,
    this.couponIds = const [],
  });

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() {
    return {
      'planId': planId,
      'cancelAnytimeSelected': cancelAnytimeSelected,
      if (couponIds.isNotEmpty) 'couponIds': couponIds,
    };
  }
}
