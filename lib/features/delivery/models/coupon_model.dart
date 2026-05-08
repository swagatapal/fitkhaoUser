import 'dart:math';

enum CouponDiscountType { flat, percentage }

class CouponModel {
  final String id;
  final String code;
  final String name;
  final String description;
  final String ruleType;
  final CouponDiscountType discountType;
  final double discountValue;
  final double? maxDiscountCap;
  final double minOrderAmount;
  final bool stackable;
  final int priority;
  final String validFrom;
  final String validUntil;

  const CouponModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.ruleType,
    required this.discountType,
    required this.discountValue,
    this.maxDiscountCap,
    required this.minOrderAmount,
    required this.stackable,
    required this.priority,
    required this.validFrom,
    required this.validUntil,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    final rawType = (json['discountType'] as String? ?? '').toLowerCase();
    return CouponModel(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      ruleType: json['ruleType'] as String? ?? '',
      discountType: rawType == 'percentage'
          ? CouponDiscountType.percentage
          : CouponDiscountType.flat,
      discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0.0,
      maxDiscountCap: (json['maxDiscountCap'] as num?)?.toDouble(),
      minOrderAmount: (json['minOrderAmount'] as num?)?.toDouble() ?? 0.0,
      stackable: json['stackable'] as bool? ?? false,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      validFrom: json['validFrom'] as String? ?? '',
      validUntil: json['validUntil'] as String? ?? '',
    );
  }

  /// Compute the actual discount amount for a given order total.
  double computeDiscount(double orderTotal) {
    if (discountType == CouponDiscountType.flat) {
      return discountValue.clamp(0.0, orderTotal);
    }
    final raw = orderTotal * discountValue / 100.0;
    final capped =
        maxDiscountCap != null ? min(raw, maxDiscountCap!) : raw;
    return capped.clamp(0.0, orderTotal);
  }

  /// Human-readable discount label, e.g. "₹50 off" or "15% off (up to ₹100)".
  String get discountLabel {
    if (discountType == CouponDiscountType.flat) {
      return '₹${discountValue.toInt()} off';
    }
    final base = '${discountValue.toInt()}% off';
    if (maxDiscountCap != null) {
      return '$base (up to ₹${maxDiscountCap!.toInt()})';
    }
    return base;
  }

  /// Formatted expiry for display.
  String get formattedExpiry {
    if (validUntil.isEmpty) return '';
    try {
      final dt = DateTime.parse(validUntil).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return validUntil;
    }
  }
}

class CouponListResponse {
  final bool success;
  final String message;
  final List<CouponModel> coupons;

  const CouponListResponse({
    required this.success,
    required this.message,
    required this.coupons,
  });

  factory CouponListResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    List<dynamic> list = const [];
    if (data is List) {
      list = data;
    } else if (data is Map<String, dynamic>) {
      final nested = data['coupons'];
      if (nested is List) list = nested;
    }
    return CouponListResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      coupons: list
          .map((e) => CouponModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
