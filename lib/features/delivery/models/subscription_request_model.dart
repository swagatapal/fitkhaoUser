/// Request model for creating a subscription
class SubscriptionRequest {
  final String planType; // 'weekly' or 'monthly'
  final int amount;

  const SubscriptionRequest({
    required this.planType,
    required this.amount,
  });

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() {
    return {
      'planType': planType,
      'amount': amount,
    };
  }
}
