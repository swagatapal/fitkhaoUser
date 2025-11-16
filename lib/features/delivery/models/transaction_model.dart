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

  TransactionData({required this.transactions});

  factory TransactionData.fromJson(Map<String, dynamic> json) {
    return TransactionData(
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((e) => Transaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
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
      final date = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today, ${DateFormat('hh:mm a').format(date)}';
      } else if (difference.inDays == 1) {
        return 'Yesterday, ${DateFormat('hh:mm a').format(date)}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return DateFormat('dd MMM yyyy').format(date);
      }
    } catch (e) {
      return createdAt;
    }
  }
}

class TransactionMetadata {
  final String? orderId;
  final String? subscriptionId;

  TransactionMetadata({
    this.orderId,
    this.subscriptionId,
  });

  factory TransactionMetadata.fromJson(Map<String, dynamic> json) {
    return TransactionMetadata(
      orderId: json['orderId'] as String?,
      subscriptionId: json['subscriptionId'] as String?,
    );
  }
}
