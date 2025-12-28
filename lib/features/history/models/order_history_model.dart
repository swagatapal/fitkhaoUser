/// Models for order history API response

/// Response model for order history
class OrderHistoryResponse {
  final bool success;
  final String message;
  final OrderHistoryData? data;

  const OrderHistoryResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory OrderHistoryResponse.fromJson(Map<String, dynamic> json) {
    return OrderHistoryResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? OrderHistoryData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Order history data with pagination
class OrderHistoryData {
  final int count;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;
  final List<OrderHistory> orders;

  const OrderHistoryData({
    required this.count,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
    required this.orders,
  });

  factory OrderHistoryData.fromJson(Map<String, dynamic> json) {
    return OrderHistoryData(
      count: json['count'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      limit: json['limit'] as int? ?? 20,
      offset: json['offset'] as int? ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
      orders: (json['orders'] as List<dynamic>?)
              ?.map((order) => OrderHistory.fromJson(order as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Order history item
class OrderHistory {
  final String id;
  final String orderNumber;
  final Kitchen kitchen;
  final String deliveryDate;
  final String deliverySlot;
  final DeliveryAddressHistory deliveryAddress;
  final List<OrderHistoryItem> items;
  final double subtotal;
  final double deliveryCharge;
  final double tax;
  final double discount;
  final double total;
  final String paymentMethod;
  final String paymentStatus;
  final String orderStatus;
  final String orderType;
  final List<String> mealTypes;
  final String? specialInstructions;
  final String createdAt;
  final String updatedAt;

  const OrderHistory({
    required this.id,
    required this.orderNumber,
    required this.kitchen,
    required this.deliveryDate,
    required this.deliverySlot,
    required this.deliveryAddress,
    required this.items,
    required this.subtotal,
    required this.deliveryCharge,
    required this.tax,
    required this.discount,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.orderStatus,
    required this.orderType,
    required this.mealTypes,
    this.specialInstructions,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderHistory.fromJson(Map<String, dynamic> json) {
    return OrderHistory(
      id: json['id'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? '',
      kitchen: Kitchen.fromJson(json['kitchen'] as Map<String, dynamic>? ?? {}),
      deliveryDate: json['deliveryDate'] as String? ?? '',
      deliverySlot: json['deliverySlot'] as String? ?? '',
      deliveryAddress: DeliveryAddressHistory.fromJson(
          json['deliveryAddress'] as Map<String, dynamic>? ?? {}),
      items: (json['items'] as List<dynamic>?)
              ?.map((item) =>
                  OrderHistoryItem.fromJson(item as Map<String, dynamic>))
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
      orderType: json['orderType'] as String? ?? '',
      mealTypes: (json['mealTypes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      specialInstructions: json['specialInstructions'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

/// Kitchen information
class Kitchen {
  final String id;
  final String name;
  final String? contactNumber;
  final KitchenAddress? address;

  const Kitchen({
    required this.id,
    required this.name,
    this.contactNumber,
    this.address,
  });

  factory Kitchen.fromJson(Map<String, dynamic> json) {
    return Kitchen(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      contactNumber: json['contactNumber'] as String?,
      address: json['address'] != null
          ? KitchenAddress.fromJson(json['address'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Kitchen address
class KitchenAddress {
  final String area;
  final String city;

  const KitchenAddress({
    required this.area,
    required this.city,
  });

  factory KitchenAddress.fromJson(Map<String, dynamic> json) {
    return KitchenAddress(
      area: json['area'] as String? ?? '',
      city: json['city'] as String? ?? '',
    );
  }
}

/// Delivery address from order history
class DeliveryAddressHistory {
  final String buildingName;
  final String street;
  final String pincode;
  final double latitude;
  final double longitude;
  final String contactNumber;
  final String? deliveryInstructions;

  const DeliveryAddressHistory({
    required this.buildingName,
    required this.street,
    required this.pincode,
    required this.latitude,
    required this.longitude,
    required this.contactNumber,
    this.deliveryInstructions,
  });

  factory DeliveryAddressHistory.fromJson(Map<String, dynamic> json) {
    return DeliveryAddressHistory(
      buildingName: json['buildingName'] as String? ?? '',
      street: json['street'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      contactNumber: json['contactNumber'] as String? ?? '',
      deliveryInstructions: json['deliveryInstructions'] as String?,
    );
  }
}

/// Order history item
class OrderHistoryItem {
  final String id;
  final String orderId;
  final String foodItemId;
  final String kitchenId;
  final String itemName;
  final double itemPrice;
  final int quantity;
  final double subtotal;
  final NutritionalInfo? nutritionalInfo;
  final String foodType;
  final String category;
  final String deliveryDate;
  final String deliverySlot;
  final String? specialInstructions;
  final List<dynamic> customizations;
  final String itemStatus;
  final String createdAt;
  final String updatedAt;

  const OrderHistoryItem({
    required this.id,
    required this.orderId,
    required this.foodItemId,
    required this.kitchenId,
    required this.itemName,
    required this.itemPrice,
    required this.quantity,
    required this.subtotal,
    this.nutritionalInfo,
    required this.foodType,
    required this.category,
    required this.deliveryDate,
    required this.deliverySlot,
    this.specialInstructions,
    required this.customizations,
    required this.itemStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderHistoryItem.fromJson(Map<String, dynamic> json) {
    return OrderHistoryItem(
      id: json['_id'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      foodItemId: json['foodItemId'] as String? ?? '',
      kitchenId: json['kitchenId'] as String? ?? '',
      itemName: json['itemName'] as String? ?? '',
      itemPrice: (json['itemPrice'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      nutritionalInfo: json['nutrition'] != null
          ? NutritionalInfo.fromJson(
              json['nutrition'] as Map<String, dynamic>)
          : null,
      foodType: json['foodType'] as String? ?? 'veg',
      category: json['category'] as String? ?? '',
      deliveryDate: json['deliveryDate'] as String? ?? '',
      deliverySlot: json['deliverySlot'] as String? ?? '',
      specialInstructions: json['specialInstructions'] as String?,
      customizations: json['customizations'] as List<dynamic>? ?? [],
      itemStatus: json['itemStatus'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

/// Nutritional information
class NutritionalInfo {
  final double carbGm;
  final double proteinGm;
  final double fatGm;
  final double energyKcal;

  const NutritionalInfo({
    required this.carbGm,
    required this.proteinGm,
    required this.fatGm,
    required this.energyKcal,
  });

  factory NutritionalInfo.fromJson(Map<String, dynamic> json) {
    return NutritionalInfo(
      carbGm: (json['carbGm'] as num?)?.toDouble() ?? 0.0,
      proteinGm: (json['proteinGm'] as num?)?.toDouble() ?? 0.0,
      fatGm: (json['fatGm'] as num?)?.toDouble() ?? 0.0,
      energyKcal: (json['energyKcal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
