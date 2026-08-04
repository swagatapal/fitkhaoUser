/// Subscription tier hierarchy: none < go < pro < achievers
enum PlanTier { none, go, pro, achievers }

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
          ? SubscriptionInfo.fromJson(
              json['subscription'] as Map<String, dynamic>)
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

/// Subscription information — handles both:
///   • /api/user/profile  → activeSubscription (uses `_id`, `planName`, `planCode`, `autoRenew`)
///   • /api/wallet/balance → subscription      (uses `id`, `planType`, `isActive`, `remainingDays`)
class SubscriptionInfo {
  final String id;
  final String planCode; // e.g. "PLN003"
  final String planName; // e.g. "Pro" — primary source for tier logic
  final String planType; // legacy field from wallet API (e.g. "pro")
  final int planAmount;
  final String status;
  final String startDate;

  /// When meal deliveries actually begin (profile API). May differ from
  /// [startDate]; empty when not provided.
  final String serviceStartDate;
  final String endDate;
  final int remainingDays;
  final bool isActive;
  final bool autoRenew;

  /// Meals included per day (profile API). 0 when unknown.
  final int mealsPerDay;

  /// Discount % subscribers get on outlet food orders (profile API). 0 = none.
  final int outletFoodDiscountPercent;

  const SubscriptionInfo({
    required this.id,
    required this.planCode,
    required this.planName,
    required this.planType,
    required this.planAmount,
    required this.status,
    required this.startDate,
    this.serviceStartDate = '',
    required this.endDate,
    required this.remainingDays,
    required this.isActive,
    required this.autoRenew,
    this.mealsPerDay = 0,
    this.outletFoodDiscountPercent = 0,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    // Profile API uses '_id'; wallet API uses 'id'
    final id = json['_id'] as String? ?? json['id'] as String? ?? '';
    final status = json['status'] as String? ?? '';
    // Profile API derives isActive from status; wallet API has explicit bool
    final isActive = json['isActive'] as bool? ?? (status == 'active');
    return SubscriptionInfo(
      id: id,
      planCode: json['planCode'] as String? ?? '',
      planName: json['planName'] as String? ?? '',
      planType: json['planType'] as String? ?? '',
      planAmount: (json['planAmount'] as num?)?.toInt() ?? 0,
      status: status,
      startDate: json['startDate'] as String? ?? '',
      serviceStartDate: json['serviceStartDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      remainingDays: (json['remainingDays'] as num?)?.toInt() ?? 0,
      isActive: isActive,
      autoRenew: json['autoRenew'] as bool? ?? false,
      mealsPerDay: (json['mealsPerDay'] as num?)?.toInt() ?? 0,
      outletFoodDiscountPercent:
          (json['outletFoodDiscountPercent'] as num?)?.toInt() ?? 0,
    );
  }

  /// Get formatted price
  String get formattedPrice => '₹$planAmount';

  /// Derive the tier — checks planName first (profile API), falls back to planType (wallet API)
  PlanTier get planTier {
    if (!isActive) return PlanTier.none;
    final t = (planName.isNotEmpty ? planName : planType).toLowerCase();
    if (t.contains('achiever')) return PlanTier.achievers;
    if (t.contains('pro')) return PlanTier.pro;
    if (t.contains('go')) return PlanTier.go;
    return PlanTier.none;
  }
}
