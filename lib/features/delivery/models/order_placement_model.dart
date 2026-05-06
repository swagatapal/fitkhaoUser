// Models for order placement

/// Request model for placing an order
class OrderPlacementRequest {
  final String kitchenId;
  final List<OrderItem> items;
  final DeliveryAddress deliveryAddress;
  final String paymentMethod;
  final String? specialInstructions;

  const OrderPlacementRequest({
    required this.kitchenId,
    required this.items,
    required this.deliveryAddress,
    required this.paymentMethod,
    this.specialInstructions,
  });

  Map<String, dynamic> toJson() {
    return {
      'kitchenId': kitchenId,
      'items': items.map((item) => item.toJson()).toList(),
      'deliveryAddress': deliveryAddress.toJson(),
      'paymentMethod': paymentMethod,
      if (specialInstructions != null && specialInstructions!.isNotEmpty)
        'specialInstructions': specialInstructions,
    };
  }
}

/// Order item in the request
class OrderItem {
  final String dishId;
  final int quantity;
  final int dishServing;
  final String? specialInstructions;

  const OrderItem({
    required this.dishId,
    required this.quantity,
    this.dishServing = 1,
    this.specialInstructions,
  });

  Map<String, dynamic> toJson() {
    return {
      'dishId': dishId,
      'quantity': quantity,
      'dishServing': dishServing,
      if (specialInstructions != null && specialInstructions!.isNotEmpty)
        'specialInstructions': specialInstructions,
    };
  }
}

/// Delivery address in the request
class DeliveryAddress {
  final String buildingName;
  final String street;
  final String pincode;
  final String contactNumber;
  final double latitude;
  final double longitude;
  final String? deliveryInstructions;

  const DeliveryAddress({
    required this.buildingName,
    required this.street,
    required this.pincode,
    required this.contactNumber,
    required this.latitude,
    required this.longitude,
    this.deliveryInstructions,
  });

  Map<String, dynamic> toJson() {
    return {
      'buildingName': buildingName,
      'street': street,
      'pincode': pincode,
      'contactNumber': contactNumber,
      'latitude': latitude,
      'longitude': longitude,
      if (deliveryInstructions != null && deliveryInstructions!.isNotEmpty)
        'deliveryInstructions': deliveryInstructions,
    };
  }
}

/// Response model for order placement
class OrderPlacementResponse {
  final bool success;
  final String message;
  final OrderPlacementData? data;

  const OrderPlacementResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory OrderPlacementResponse.fromJson(Map<String, dynamic> json) {
    return OrderPlacementResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? OrderPlacementData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Order data from placement response
class OrderPlacementData {
  final String orderId;
  final String orderNumber;
  final double total;
  final String paymentStatus;

  const OrderPlacementData({
    required this.orderId,
    required this.orderNumber,
    required this.total,
    required this.paymentStatus,
  });

  factory OrderPlacementData.fromJson(Map<String, dynamic> json) {
    return OrderPlacementData(
      orderId: json['orderId'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['paymentStatus'] as String? ?? '',
    );
  }
}

/// Placed order details
class PlacedOrder {
  final String id;
  final String orderNumber;
  final String kitchenId;
  final List<PlacedOrderItem> items;
  final double subtotal;
  final double deliveryCharge;
  final double tax;
  final double discount;
  final double total;
  final String paymentMethod;
  final String paymentStatus;
  final String orderStatus;
  final String createdAt;

  const PlacedOrder({
    required this.id,
    required this.orderNumber,
    required this.kitchenId,
    required this.items,
    required this.subtotal,
    required this.deliveryCharge,
    required this.tax,
    required this.discount,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.orderStatus,
    required this.createdAt,
  });

  factory PlacedOrder.fromJson(Map<String, dynamic> json) {
    return PlacedOrder(
      id: json['id'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? '',
      kitchenId: json['kitchenId'] as String? ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map(
                (item) =>
                    PlacedOrderItem.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryCharge: (json['deliveryCharge'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] as String? ?? '',
      paymentStatus: json['paymentStatus'] as String? ?? '',
      orderStatus: json['orderStatus'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

/// Item in placed order
class PlacedOrderItem {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final double subtotal;

  const PlacedOrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.subtotal,
  });

  factory PlacedOrderItem.fromJson(Map<String, dynamic> json) {
    return PlacedOrderItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
