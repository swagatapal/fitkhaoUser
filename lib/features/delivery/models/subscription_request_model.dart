/// Request model for creating a subscription
class SubscriptionRequest {
  final String planCode;
  final String? paymentId;

  const SubscriptionRequest({
    required this.planCode,
    this.paymentId,
  });

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() {
    return {
      'planCode': planCode,
      if (paymentId != null && paymentId!.isNotEmpty) 'paymentId': paymentId,
    };
  }
}
