enum OrderStatusStage {
  placed,
  confirmed,
  preparing,
  outForDelivery,
  delivered,
}

class OrderItemModel {
  final String name;
  final int quantity;
  final double price;

  const OrderItemModel({
    required this.name,
    required this.quantity,
    required this.price,
  });
}

class OrderModel {
  final String id;
  final String restaurantName;
  final String? restaurantImage;
  final DateTime orderTime;
  final DateTime? deliveredTime;
  final String address;
  final List<OrderItemModel> items;
  final double deliveryFee;
  final double tax;
  final OrderStatusStage statusStage;

  const OrderModel({
    required this.id,
    required this.restaurantName,
    this.restaurantImage,
    required this.orderTime,
    this.deliveredTime,
    required this.address,
    required this.items,
    required this.deliveryFee,
    required this.tax,
    required this.statusStage,
  });

  double get subtotal =>
      items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  double get total => subtotal + deliveryFee + tax;

  bool get isDelivered => statusStage == OrderStatusStage.delivered;
}
