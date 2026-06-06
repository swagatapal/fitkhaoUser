import 'cart_item.dart';
import 'menu_item.dart';

/// Parsed payload of the server cart (`data` block of GET/POST `/cart`).
class CartData {
  final List<CartItem> items;
  final int totalItems;
  final DateTime? updatedAt;

  const CartData({
    this.items = const [],
    this.totalItems = 0,
    this.updatedAt,
  });

  factory CartData.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];

    final items = rawItems.whereType<Map<String, dynamic>>().map((line) {
      final dish = line['outletDishId'];

      // The dish is normally populated as an object; if the backend ever
      // returns just the id string, fall back to a minimal placeholder so the
      // line still renders rather than crashing the parse.
      final MenuItem menuItem = dish is Map<String, dynamic>
          ? MenuItem.fromJson(dish)
          : MenuItem(
              id: dish?.toString() ?? '',
              name: 'Item',
              imageUrl: '',
              calories: 0,
              price: 0,
              category: '',
              isVeg: true,
            );

      return CartItem(
        menuItem: menuItem,
        quantity: (line['quantity'] as num?)?.toInt() ?? 0,
      );
    }).where((c) => c.menuItem.id.isNotEmpty && c.quantity > 0).toList();

    return CartData(
      items: items,
      totalItems: (json['totalItems'] as num?)?.toInt() ??
          items.fold<int>(0, (sum, c) => sum + c.quantity),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

/// Envelope for `/cart` responses.
class CartResponse {
  final bool success;
  final String message;
  final CartData? data;

  const CartResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory CartResponse.fromJson(Map<String, dynamic> json) {
    return CartResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] is Map<String, dynamic>
          ? CartData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}
