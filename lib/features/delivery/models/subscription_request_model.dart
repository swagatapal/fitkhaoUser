/// Request model for creating a subscription via wallet.
/// POST /api/subscription/create
class SubscriptionRequest {
  final String planId;
  final bool cancelAnytimeSelected;

  const SubscriptionRequest({
    required this.planId,
    this.cancelAnytimeSelected = false,
  });

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() {
    return {
      'planId': planId,
      'cancelAnytimeSelected': cancelAnytimeSelected,
    };
  }
}
