/// Response model for wallet balance API
class WalletBalanceResponse {
  final bool success;
  final String message;
  final WalletBalanceData? data;

  const WalletBalanceResponse({
    required this.success,
    required this.message,
    this.data,
  });

  /// Create from JSON response
  factory WalletBalanceResponse.fromJson(Map<String, dynamic> json) {
    return WalletBalanceResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? WalletBalanceData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Wallet balance data
class WalletBalanceData {
  final WalletInfo wallet;
  final SubscriptionInfo? subscription;
  final String message;

  const WalletBalanceData({
    required this.wallet,
    this.subscription,
    required this.message,
  });

  factory WalletBalanceData.fromJson(Map<String, dynamic> json) {
    return WalletBalanceData(
      wallet: WalletInfo.fromJson(json['wallet'] as Map<String, dynamic>),
      subscription: json['subscription'] != null
          ? SubscriptionInfo.fromJson(json['subscription'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String? ?? '',
    );
  }
}

/// Wallet information
class WalletInfo {
  final double couponBalance;
  final double frozenBalance;
  final double availableBalance;
  final bool canUseBalance;
  final double totalEarned;
  final double totalSpent;
  final String? lastTransactionAt;

  const WalletInfo({
    required this.couponBalance,
    required this.frozenBalance,
    required this.availableBalance,
    required this.canUseBalance,
    required this.totalEarned,
    required this.totalSpent,
    this.lastTransactionAt,
  });

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      couponBalance: (json['couponBalance'] as num?)?.toDouble() ?? 0.0,
      frozenBalance: (json['frozenBalance'] as num?)?.toDouble() ?? 0.0,
      availableBalance: (json['availableBalance'] as num?)?.toDouble() ?? 0.0,
      canUseBalance: json['canUseBalance'] as bool? ?? false,
      totalEarned: (json['totalEarned'] as num?)?.toDouble() ?? 0.0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
      lastTransactionAt: json['lastTransactionAt'] as String?,
    );
  }
}

/// Subscription information
class SubscriptionInfo {
  final String id;
  final String planType;
  final int planAmount;
  final String status;
  final String startDate;
  final String endDate;
  final int remainingDays;
  final bool isActive;

  const SubscriptionInfo({
    required this.id,
    required this.planType,
    required this.planAmount,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.remainingDays,
    required this.isActive,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      id: json['id'] as String? ?? '',
      planType: json['planType'] as String? ?? '',
      planAmount: json['planAmount'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      remainingDays: json['remainingDays'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? false,
    );
  }

  /// Get formatted plan name
  String get planName {
    if (planType == 'weekly') return '7 Days Plan';
    if (planType == 'monthly') return '30 Days Plan';
    return planType;
  }

  /// Get formatted price
  String get formattedPrice => '₹$planAmount';
}
