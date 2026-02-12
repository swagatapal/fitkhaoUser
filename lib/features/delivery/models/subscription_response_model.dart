/// Response model for subscription creation
class SubscriptionResponse {
  final bool success;
  final String message;
  final SubscriptionData? data;

  const SubscriptionResponse({
    required this.success,
    required this.message,
    this.data,
  });

  /// Create from JSON response
  factory SubscriptionResponse.fromJson(Map<String, dynamic> json) {
    return SubscriptionResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? SubscriptionData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Subscription data from API response
class SubscriptionData {
  final String? subscriptionId;
  final String? planType;
  final int? amount;
  final String? status;
  final String? startDate;
  final String? endDate;

  const SubscriptionData({
    this.subscriptionId,
    this.planType,
    this.amount,
    this.status,
    this.startDate,
    this.endDate,
  });

  /// Create from JSON
  factory SubscriptionData.fromJson(Map<String, dynamic> json) {
    return SubscriptionData(
      subscriptionId: json['subscriptionId'] as String?,
      planType: json['planType'] as String?,
      amount: json['amount'] as int?,
      status: json['status'] as String?,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
    );
  }
}
