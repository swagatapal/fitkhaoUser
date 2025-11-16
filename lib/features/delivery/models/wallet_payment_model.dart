/// Models for wallet payment processing

/// Request model for wallet payment
class WalletPaymentRequest {
  final String orderId;
  final double amount;
  final String paymentMethod;

  const WalletPaymentRequest({
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
  });

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'amount': amount,
      'paymentMethod': paymentMethod,
    };
  }
}

/// Response model for wallet payment
class WalletPaymentResponse {
  final bool success;
  final String message;
  final WalletPaymentData? data;

  const WalletPaymentResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory WalletPaymentResponse.fromJson(Map<String, dynamic> json) {
    return WalletPaymentResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? WalletPaymentData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Wallet payment data from response
class WalletPaymentData {
  final PaymentInfo payment;
  final WalletBalanceInfo wallet;

  const WalletPaymentData({
    required this.payment,
    required this.wallet,
  });

  factory WalletPaymentData.fromJson(Map<String, dynamic> json) {
    return WalletPaymentData(
      payment: PaymentInfo.fromJson(json['payment'] as Map<String, dynamic>),
      wallet: WalletBalanceInfo.fromJson(json['wallet'] as Map<String, dynamic>),
    );
  }
}

/// Payment information
class PaymentInfo {
  final String orderId;
  final double amountDeducted;
  final double previousBalance;
  final double newBalance;

  const PaymentInfo({
    required this.orderId,
    required this.amountDeducted,
    required this.previousBalance,
    required this.newBalance,
  });

  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    return PaymentInfo(
      orderId: json['orderId'] as String? ?? '',
      amountDeducted: (json['amountDeducted'] as num?)?.toDouble() ?? 0.0,
      previousBalance: (json['previousBalance'] as num?)?.toDouble() ?? 0.0,
      newBalance: (json['newBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Wallet balance information after payment
class WalletBalanceInfo {
  final double couponBalance;
  final double availableBalance;

  const WalletBalanceInfo({
    required this.couponBalance,
    required this.availableBalance,
  });

  factory WalletBalanceInfo.fromJson(Map<String, dynamic> json) {
    return WalletBalanceInfo(
      couponBalance: (json['couponBalance'] as num?)?.toDouble() ?? 0.0,
      availableBalance: (json['availableBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
