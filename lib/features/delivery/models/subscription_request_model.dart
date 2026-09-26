/// Request model for creating a subscription via wallet.
/// POST /api/subscription/create
class SubscriptionRequest {
  final String planId;
  final bool cancelAnytimeSelected;

  /// Rule ids of the coupons to redeem. Omitted from the body when empty.
  final List<String> couponIds;

  /// Partner/organisation referral code. Omitted when blank.
  final String referralCode;

  /// Chosen organisation member's id. Only applies when the referral resolved
  /// to an organisation; omitted when blank.
  final String consulterId;

  const SubscriptionRequest({
    required this.planId,
    this.cancelAnytimeSelected = false,
    this.couponIds = const [],
    this.referralCode = '',
    this.consulterId = '',
  });

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() {
    return {
      'planId': planId,
      'cancelAnytimeSelected': cancelAnytimeSelected,
      if (couponIds.isNotEmpty) 'couponIds': couponIds,
      if (referralCode.isNotEmpty) 'referralCode': referralCode,
      if (consulterId.isNotEmpty) 'consulterId': consulterId,
    };
  }
}
