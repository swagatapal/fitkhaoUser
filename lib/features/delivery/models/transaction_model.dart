import 'package:intl/intl.dart';

class TransactionResponse {
  final bool success;
  final String message;
  final TransactionData data;

  TransactionResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory TransactionResponse.fromJson(Map<String, dynamic> json) {
    return TransactionResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: TransactionData.fromJson(json['data'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class TransactionData {
  final List<Transaction> transactions;
  final TransactionPagination pagination;

  TransactionData({
    required this.transactions,
    this.pagination = const TransactionPagination(),
  });

  factory TransactionData.fromJson(Map<String, dynamic> json) {
    return TransactionData(
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((e) => Transaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pagination: TransactionPagination.fromJson(
        json['pagination'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class TransactionPagination {
  final int limit;
  final int offset;
  final int totalCount;
  final bool hasMore;

  const TransactionPagination({
    this.limit = 50,
    this.offset = 0,
    this.totalCount = 0,
    this.hasMore = false,
  });

  factory TransactionPagination.fromJson(Map<String, dynamic> json) {
    return TransactionPagination(
      limit: (json['limit'] as num?)?.toInt() ?? 50,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

class Transaction {
  final String id;
  final String type; // "debit" or "credit"
  final double amount;
  final double balanceAfter;
  final String category;
  final String description;
  final String status;
  final TransactionMetadata? metadata;
  final String createdAt;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.category,
    required this.description,
    required this.status,
    this.metadata,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? '',
      metadata: json['metadata'] != null
          ? TransactionMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  bool get isDebit => type.toLowerCase() == 'debit';
  bool get isCredit => type.toLowerCase() == 'credit';

  String get formattedAmount => '₹${amount.toStringAsFixed(2)}';
  String get formattedBalanceAfter => '₹${balanceAfter.toStringAsFixed(2)}';

  String get formattedDate {
    try {
      final date = DateTime.parse(createdAt);
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (e) {
      return createdAt;
    }
  }

  String get formattedDateShort {
    try {
      final utcDate = DateTime.parse(createdAt).toUtc();

      final istDate = utcDate.add(const Duration(hours: 5, minutes: 30));
      final istNow = DateTime.now().toUtc().add(
        const Duration(hours: 5, minutes: 30),
      );

      final difference = istNow.difference(istDate);

      if (difference.inDays == 0) {
        return 'Today, ${DateFormat('hh:mm a').format(istDate)}';
      } else if (difference.inDays == 1) {
        return 'Yesterday, ${DateFormat('hh:mm a').format(istDate)}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return DateFormat('dd MMM yyyy').format(istDate);
      }
    } catch (e) {
      return createdAt;
    }
  }
}

class TransactionMetadata {
  final String? orderId;
  final String? subscriptionId;
  final String? planCode;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final TransactionPricing? pricing;

  TransactionMetadata({
    this.orderId,
    this.subscriptionId,
    this.planCode,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.pricing,
  });

  factory TransactionMetadata.fromJson(Map<String, dynamic> json) {
    return TransactionMetadata(
      orderId: json['orderId'] as String?,
      subscriptionId: json['subscriptionId'] as String?,
      planCode: json['planCode'] as String?,
      razorpayOrderId: json['razorpayOrderId'] as String?,
      razorpayPaymentId: json['razorpayPaymentId'] as String?,
      pricing: json['pricing'] is Map<String, dynamic>
          ? TransactionPricing.fromJson(json['pricing'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Pricing breakdown attached to subscription-purchase transactions.
class TransactionPricing {
  final double planAmount;
  final bool cancelAnytimeSelected;
  final double cancelAnytimeFee;
  final double subtotal;
  final double gstRate;
  final double gstAmount;
  final double totalAmount;

  TransactionPricing({
    this.planAmount = 0,
    this.cancelAnytimeSelected = false,
    this.cancelAnytimeFee = 0,
    this.subtotal = 0,
    this.gstRate = 0,
    this.gstAmount = 0,
    this.totalAmount = 0,
  });

  factory TransactionPricing.fromJson(Map<String, dynamic> json) {
    return TransactionPricing(
      planAmount: (json['planAmount'] as num?)?.toDouble() ?? 0,
      cancelAnytimeSelected: json['cancelAnytimeSelected'] as bool? ?? false,
      cancelAnytimeFee: (json['cancelAnytimeFee'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      gstRate: (json['gstRate'] as num?)?.toDouble() ?? 0,
      gstAmount: (json['gstAmount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}
