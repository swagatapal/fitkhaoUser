/// Request model for wallet top-up
class WalletTopupRequest {
  final int amount;
  final String paymentMethod;
  final String transactionId;
  final String? description;

  const WalletTopupRequest({
    required this.amount,
    required this.paymentMethod,
    required this.transactionId,
    this.description,
  });

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
      if (description != null && description!.isNotEmpty) 'description': description,
    };
  }
}

/// Response model for wallet top-up
class WalletTopupResponse {
  final bool success;
  final String message;
  final WalletTopupData? data;

  const WalletTopupResponse({
    required this.success,
    required this.message,
    this.data,
  });

  /// Create from JSON response
  factory WalletTopupResponse.fromJson(Map<String, dynamic> json) {
    return WalletTopupResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? WalletTopupData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Wallet top-up data from API response
class WalletTopupData {
  final TopupWalletInfo wallet;
  final TopupSubscriptionInfo? subscription;

  const WalletTopupData({
    required this.wallet,
    this.subscription,
  });

  factory WalletTopupData.fromJson(Map<String, dynamic> json) {
    return WalletTopupData(
      wallet: TopupWalletInfo.fromJson(json['wallet'] as Map<String, dynamic>),
      subscription: json['subscription'] != null
          ? TopupSubscriptionInfo.fromJson(json['subscription'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Wallet info after top-up
class TopupWalletInfo {
  final double couponBalance;
  final double previousBalance;
  final double addedAmount;

  const TopupWalletInfo({
    required this.couponBalance,
    required this.previousBalance,
    required this.addedAmount,
  });

  factory TopupWalletInfo.fromJson(Map<String, dynamic> json) {
    return TopupWalletInfo(
      couponBalance: (json['couponBalance'] as num?)?.toDouble() ?? 0.0,
      previousBalance: (json['previousBalance'] as num?)?.toDouble() ?? 0.0,
      addedAmount: (json['addedAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Subscription info after top-up
class TopupSubscriptionInfo {
  final String id;
  final String planType;
  final String endDate;
  final int remainingDays;

  const TopupSubscriptionInfo({
    required this.id,
    required this.planType,
    required this.endDate,
    required this.remainingDays,
  });

  factory TopupSubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return TopupSubscriptionInfo(
      id: json['id'] as String? ?? '',
      planType: json['planType'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      remainingDays: json['remainingDays'] as int? ?? 0,
    );
  }
}
