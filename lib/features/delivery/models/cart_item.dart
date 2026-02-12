import 'menu_item.dart';

/// Model representing an item in the cart
class CartItem {
  final MenuItem menuItem;
  final int quantity;

  const CartItem({
    required this.menuItem,
    required this.quantity,
  });

  CartItem copyWith({
    MenuItem? menuItem,
    int? quantity,
  }) {
    return CartItem(
      menuItem: menuItem ?? this.menuItem,
      quantity: quantity ?? this.quantity,
    );
  }

  double get totalPrice => menuItem.price * quantity;

  /// Convert CartItem to JSON
  Map<String, dynamic> toJson() {
    return {
      'menuItem': {
        'id': menuItem.id,
        'name': menuItem.name,
        'imageUrl': menuItem.imageUrl,
        'calories': menuItem.calories,
        'price': menuItem.price,
        'category': menuItem.category,
        'isVeg': menuItem.isVeg,
        'description': menuItem.description,
        'protein': menuItem.protein,
        'carbs': menuItem.carbs,
        'fats': menuItem.fats,
        'fiber': menuItem.fiber,
        'menuType': menuItem.menuType,
        'mealType': menuItem.mealType,
        'goalCategory': menuItem.goalCategory,
        'isAvailable': menuItem.isAvailable,
        'tags': menuItem.tags,
        'allergens': menuItem.allergens,
        'rating': menuItem.rating,
      },
      'quantity': quantity,
    };
  }

  /// Create CartItem from JSON
  factory CartItem.fromJson(Map<String, dynamic> json) {
    final menuItemData = json['menuItem'] as Map<String, dynamic>;

    return CartItem(
      menuItem: MenuItem(
        id: menuItemData['id'] as String? ?? '',
        name: menuItemData['name'] as String? ?? '',
        imageUrl: menuItemData['imageUrl'] as String? ?? '',
        calories: menuItemData['calories'] as int? ?? 0,
        price: (menuItemData['price'] as num?)?.toDouble() ?? 0.0,
        category: menuItemData['category'] as String? ?? '',
        isVeg: menuItemData['isVeg'] as bool? ?? true,
        description: menuItemData['description'] as String? ?? '',
        protein: menuItemData['protein'] as String? ?? '0g',
        carbs: menuItemData['carbs'] as String? ?? '0g',
        fats: menuItemData['fats'] as String? ?? '0g',
        fiber: menuItemData['fiber'] as String? ?? '0g',
        menuType: menuItemData['menuType'] as String? ?? 'veg',
        mealType: menuItemData['mealType'] as String? ?? 'lunch',
        goalCategory: (menuItemData['goalCategory'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [],
        isAvailable: menuItemData['isAvailable'] as bool? ?? true,
        tags: (menuItemData['tags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [],
        allergens: (menuItemData['allergens'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [],
        rating: (menuItemData['rating'] as num?)?.toDouble() ?? 0.0,
      ),
      quantity: json['quantity'] as int? ?? 1,
    );
  }
}
