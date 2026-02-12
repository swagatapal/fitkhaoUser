class TrendingItem {
  final int rank;
  final String foodItemId;
  final String itemName;
  final String menuType;
  final String mealType;
  final int totalQuantity;
  final double totalRevenue;
  final int orderFrequency;
  final double avgPrice;
  final double trendingScore;
  final List<String> deliverySlots;

  const TrendingItem({
    required this.rank,
    required this.foodItemId,
    required this.itemName,
    required this.menuType,
    required this.mealType,
    required this.totalQuantity,
    required this.totalRevenue,
    required this.orderFrequency,
    required this.avgPrice,
    required this.trendingScore,
    required this.deliverySlots,
  });

  factory TrendingItem.fromJson(Map<String, dynamic> json) {
    return TrendingItem(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      foodItemId: json['foodItemId'] as String? ?? '',
      itemName: json['itemName'] as String? ?? '',
      menuType: json['menuType'] as String? ?? '',
      mealType: json['mealType'] as String? ?? '',
      totalQuantity: (json['totalQuantity'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      orderFrequency: (json['orderFrequency'] as num?)?.toInt() ?? 0,
      avgPrice: (json['avgPrice'] as num?)?.toDouble() ?? 0.0,
      trendingScore: (json['trendingScore'] as num?)?.toDouble() ?? 0.0,
      deliverySlots: (json['deliverySlots'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
    );
  }
}

class TrendingResponse {
  final bool success;
  final String message;
  final int count;
  final String kitchenId;
  final String timeSlot;
  final List<TrendingItem> items;
  final String? timestamp;

  const TrendingResponse({
    required this.success,
    required this.message,
    required this.count,
    required this.kitchenId,
    required this.timeSlot,
    required this.items,
    this.timestamp,
  });

  factory TrendingResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final itemsJson = data?['items'] as List<dynamic>? ?? const [];
    return TrendingResponse(
      success: json['success'] == true,
      message: json['message'] as String? ?? '',
      count: (data?['count'] as num?)?.toInt() ?? itemsJson.length,
      kitchenId: data?['kitchenId'] as String? ?? '',
      timeSlot: data?['timeSlot'] as String? ?? '',
      items: itemsJson
          .map((e) => TrendingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      timestamp: json['timestamp'] as String?,
    );
  }
}

