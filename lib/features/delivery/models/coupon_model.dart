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

  /// Promotional banner image. When present, the card renders this image
  /// instead of the text-based design.
  final String? couponImage;

  /// Optional rich content (currently unused in the card design).
  final String? couponContent;

  /// Downloadable promotion documents (e.g. PDFs). When present alongside
  /// [couponImage], a download button is overlaid on the banner image.
  final List<String> promotionFiles;

  /// True for coupons the backend issued automatically (e.g. the per-meal
  /// credit granted when a subscription is cancelled) rather than a campaign.
  final bool isSystemGenerated;

  /// Free-text note from the backend, shown to the user when present.
  final String remarks;

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
    this.couponImage,
    this.couponContent,
    this.promotionFiles = const [],
    this.isSystemGenerated = false,
    this.remarks = '',
  });

  /// True when a promotional banner image should be shown instead of the
  /// text-based card layout.
  bool get hasImage => couponImage != null && couponImage!.isNotEmpty;

  /// True when downloadable promotion files are attached.
  bool get hasPromotionFiles => promotionFiles.isNotEmpty;

  /// Human-readable label for [ruleType], e.g. 'subscription_buy' →
  /// 'Subscriptions'. Unknown types fall back to a title-cased version of the
  /// raw value so a new backend rule type still reads sensibly.
  String get ruleTypeLabel {
    switch (ruleType) {
      case 'subscription_buy':
      case 'subscription':
        return 'Subscriptions';
      case 'outlet':
        return 'Outlet orders';
      case '':
        return 'All orders';
      default:
        return ruleType
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
            .join(' ');
    }
  }

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    final rawType = (json['discountType'] as String? ?? '').toLowerCase();
    final rawImage = json['couponImage'] as String?;
    final rawContent = json['couponContent'] as String?;
    final rawFiles = json['promotionFiles'];
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
      couponImage: (rawImage != null && rawImage.isNotEmpty) ? rawImage : null,
      couponContent:
          (rawContent != null && rawContent.isNotEmpty) ? rawContent : null,
      promotionFiles: rawFiles is List
          ? rawFiles
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .toList()
          : const [],
      isSystemGenerated: json['isSystemGenerated'] as bool? ?? false,
      remarks: json['remarks'] as String? ?? '',
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

// ─── Grouping ────────────────────────────────────────────────────────────────

/// One row in a coupon list: a single coupon, or several interchangeable
/// system-generated ones collapsed into a single entry.
class CouponGroup {
  /// The coupon this row represents — the one applied when the row is tapped.
  final CouponModel coupon;

  /// Every interchangeable code this row stands for. Length 1 for an ordinary
  /// coupon; more for a collapsed system-generated group.
  final List<String> codes;

  CouponGroup({required this.coupon, required this.codes});

  /// How many coupons this row collapses. 1 means it is not a group.
  int get count => codes.length;

  bool get isGroup => codes.length > 1;

  /// True when [code] is one of the interchangeable codes in this row.
  bool contains(String? code) => code != null && codes.contains(code);
}

/// Collapses system-generated coupons into one row each.
///
/// The backend issues one auto-generated coupon per cancelled meal (e.g.
/// "Meal 1 of 120"), so a cancelled subscription can produce a hundred-plus
/// identical ₹50 credits. Listing them individually buries every real campaign
/// offer, so equivalent ones are shown once with a count.
///
/// Only [CouponModel.isSystemGenerated] coupons are grouped, and only with
/// others carrying the same offer — same name, discount type, value, cap and
/// minimum — so two different auto-issued denominations stay distinct rather
/// than being misreported under one figure. Everything else renders exactly as
/// before, and first-appearance order is preserved so the list does not
/// reshuffle relative to the API response.
///
/// Shared by the cart checkout sheet and the All Coupons screen so the two can
/// never disagree about what a group is.
List<CouponGroup> groupCoupons(List<CouponModel> coupons) {
  final entries = <CouponGroup>[];
  final indexByKey = <String, int>{};

  for (final c in coupons) {
    if (!c.isSystemGenerated) {
      entries.add(CouponGroup(coupon: c, codes: [c.code]));
      continue;
    }
    final key = '${c.name}|${c.discountType}|${c.discountValue}'
        '|${c.maxDiscountCap}|${c.minOrderAmount}';
    final at = indexByKey[key];
    if (at == null) {
      indexByKey[key] = entries.length;
      entries.add(CouponGroup(coupon: c, codes: [c.code]));
    } else {
      entries[at].codes.add(c.code);
    }
  }
  return entries;
}
