// Models for order history API response

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
              ?.map((order) =>
                  OrderHistory.fromJson(order as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Delivery slot details
class DeliverySlot {
  final String id;
  final String slotName;
  final String slotStartTime;
  final String slotEndTime;

  const DeliverySlot({
    required this.id,
    required this.slotName,
    required this.slotStartTime,
    required this.slotEndTime,
  });

  /// Human-readable display string e.g. "Morning (8:00 AM - 9:00 AM)"
  String get displayLabel => '$slotName ($slotStartTime - $slotEndTime)';

  factory DeliverySlot.fromJson(Map<String, dynamic> json) {
    return DeliverySlot(
      id: json['_id'] as String? ?? '',
      slotName: json['slotName'] as String? ?? '',
      slotStartTime: json['slotStartTime'] as String? ?? '',
      slotEndTime: json['slotEndTime'] as String? ?? '',
    );
  }

  /// Fallback: build a DeliverySlot from a plain string (legacy API)
  factory DeliverySlot.fromString(String value) {
    return DeliverySlot(
      id: '',
      slotName: value,
      slotStartTime: '',
      slotEndTime: '',
    );
  }
}

/// Delivery boy details (optional — present only when order is assigned)
class DeliveryBoy {
  final String id;
  final String name;
  final String mobileNumber;
  final String vehicleType;

  const DeliveryBoy({
    required this.id,
    required this.name,
    required this.mobileNumber,
    required this.vehicleType,
  });

  factory DeliveryBoy.fromJson(Map<String, dynamic> json) {
    return DeliveryBoy(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      mobileNumber: json['mobileNumber'] as String? ?? '',
      vehicleType: json['vehicleType'] as String? ?? '',
    );
  }
}

/// Order history item
class OrderHistory {
  final String id;
  final String orderNumber;
  final Kitchen kitchen;
  final String deliveryDate;
  final DeliverySlot deliverySlot;
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
  final List<String> categoryIds;
  final DeliveryBoy? deliveryBoy;
  final String? preparedAt;
  final String? assignedAt;
  final String? specialInstructions;
  final String createdAt;
  final String updatedAt;

  /// ISO-8601 timestamp (UTC) of when the kitchen accepted the order.
  final String? acceptedAt;

  /// Kitchen's estimated minutes to prepare the order.
  final int? preparationTimeMinutes;

  /// Estimated minutes for the rider to deliver after pickup.
  final int? deliveryTimeMinutes;

  /// Total estimated minutes from acceptance to delivery
  /// (preparation + delivery). Drives the live ETA countdown.
  final int? totalEstimatedDeliveryTimeMinutes;

  /// Whether the user has already submitted a review for this order.
  final bool isReviewed;

  /// Overall feedback text submitted by the user (null until reviewed).
  final String? feedback;

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
    this.categoryIds = const [],
    this.deliveryBoy,
    this.preparedAt,
    this.assignedAt,
    this.specialInstructions,
    required this.createdAt,
    required this.updatedAt,
    this.acceptedAt,
    this.preparationTimeMinutes,
    this.deliveryTimeMinutes,
    this.totalEstimatedDeliveryTimeMinutes,
    this.isReviewed = false,
    this.feedback,
  });

  /// Statuses during which a live delivery ETA is meaningful — i.e. after the
  /// kitchen accepts and before the order reaches a terminal state.
  static const Set<String> _etaActiveStatuses = {
    'accepted_by_kitchen',
    'preparing',
    'prepared',
    'assigned',
    'out_for_delivery',
  };

  /// Absolute (UTC) instant the order is estimated to be delivered:
  /// [acceptedAt] + [totalEstimatedDeliveryTimeMinutes]. Null when either
  /// input is missing/invalid.
  DateTime? get estimatedDeliveryAt {
    final accepted = acceptedAt;
    final mins = totalEstimatedDeliveryTimeMinutes;
    if (accepted == null || accepted.isEmpty || mins == null || mins <= 0) {
      return null;
    }
    try {
      return DateTime.parse(accepted).add(Duration(minutes: mins));
    } catch (_) {
      return null;
    }
  }

  /// Whether a live ETA countdown should be shown for this order.
  bool get hasLiveEta {
    final normalized = orderStatus.trim().toLowerCase().replaceAll('-', '_');
    return _etaActiveStatuses.contains(normalized) &&
        estimatedDeliveryAt != null;
  }

  factory OrderHistory.fromJson(Map<String, dynamic> json) {
    // deliverySlot: new API → object, legacy → string
    final slotRaw = json['deliverySlot'];
    final DeliverySlot slot;
    if (slotRaw is Map<String, dynamic>) {
      slot = DeliverySlot.fromJson(slotRaw);
    } else if (slotRaw is String) {
      slot = DeliverySlot.fromString(slotRaw);
    } else {
      slot = const DeliverySlot(id: '', slotName: '', slotStartTime: '', slotEndTime: '');
    }

    return OrderHistory(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? '',
      kitchen: Kitchen.fromJson(json['kitchen'] as Map<String, dynamic>? ?? {}),
      deliveryDate: json['deliveryDate'] as String? ?? '',
      deliverySlot: slot,
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
      // New API uses 'categoryIds'; legacy used 'mealTypes'
      categoryIds: (json['categoryIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          (json['mealTypes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      deliveryBoy: json['deliveryBoy'] != null
          ? DeliveryBoy.fromJson(json['deliveryBoy'] as Map<String, dynamic>)
          : null,
      preparedAt: json['preparedAt'] as String?,
      assignedAt: json['assignedAt'] as String?,
      specialInstructions: json['specialInstructions'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      acceptedAt: json['acceptedAt'] as String?,
      preparationTimeMinutes:
          (json['preparationTimeMinutes'] as num?)?.toInt(),
      deliveryTimeMinutes: (json['deliveryTimeMinutes'] as num?)?.toInt(),
      totalEstimatedDeliveryTimeMinutes:
          (json['totalEstimatedDeliveryTimeMinutes'] as num?)?.toInt(),
      isReviewed: json['isReviewed'] as bool? ?? false,
      feedback: json['feedback'] as String?,
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

  const KitchenAddress({required this.area, required this.city});

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
  final String contactNumber;
  final double? latitude;
  final double? longitude;
  final String? deliveryInstructions;

  const DeliveryAddressHistory({
    required this.buildingName,
    required this.street,
    required this.pincode,
    required this.contactNumber,
    this.latitude,
    this.longitude,
    this.deliveryInstructions,
  });

  factory DeliveryAddressHistory.fromJson(Map<String, dynamic> json) {
    return DeliveryAddressHistory(
      buildingName: json['buildingName'] as String? ?? '',
      street: json['street'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
      contactNumber: json['contactNumber'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      deliveryInstructions: json['deliveryInstructions'] as String?,
    );
  }
}

/// Dish review submitted by the user after delivery
class DishReview {
  final int rating;
  final String? review;

  const DishReview({required this.rating, this.review});

  factory DishReview.fromJson(Map<String, dynamic> json) {
    return DishReview(
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      review: json['review'] as String?,
    );
  }
}

/// Per-dish rating payload for the review submission API
class DishRatingInput {
  final String dishId;
  final int rating;
  final String? review;

  const DishRatingInput({
    required this.dishId,
    required this.rating,
    this.review,
  });

  Map<String, dynamic> toJson() => {
        'dishId': dishId,
        'rating': rating,
        if (review != null && review!.isNotEmpty) 'review': review,
      };
}

/// Individual order item
class OrderHistoryItem {
  final String id;
  final String orderId;
  final String dishId;
  final String kitchenId;
  final String itemName;
  final double itemPrice;
  final int quantity;
  final int dishServing;
  final double subtotal;
  final NutritionalInfo? nutritionalInfo;
  final String itemStatus;
  final String? specialInstructions;
  final String deliveryDate;
  final String deliverySlot;
  final String? dishImage;
  final DishReview? dishReview;
  final String createdAt;
  final String updatedAt;

  const OrderHistoryItem({
    required this.id,
    required this.orderId,
    required this.dishId,
    required this.kitchenId,
    required this.itemName,
    required this.itemPrice,
    required this.quantity,
    this.dishServing = 1,
    required this.subtotal,
    this.nutritionalInfo,
    required this.itemStatus,
    this.specialInstructions,
    required this.deliveryDate,
    required this.deliverySlot,
    this.dishImage,
    this.dishReview,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderHistoryItem.fromJson(Map<String, dynamic> json) {
    return OrderHistoryItem(
      id: json['_id'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      dishId: json['dishId'] as String? ?? json['foodItemId'] as String? ?? '',
      kitchenId: json['kitchenId'] as String? ?? '',
      itemName: json['itemName'] as String? ?? '',
      itemPrice: (json['itemPrice'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 0,
      dishServing: json['dishServing'] as int? ?? 1,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      nutritionalInfo: json['nutrition'] != null
          ? NutritionalInfo.fromJson(json['nutrition'] as Map<String, dynamic>)
          : null,
      itemStatus: json['itemStatus'] as String? ?? '',
      specialInstructions: json['specialInstructions'] as String?,
      deliveryDate: json['deliveryDate'] as String? ?? '',
      deliverySlot: json['deliverySlot'] as String? ?? '',
      dishImage: json['dishImage'] as String?,
      dishReview: json['dishReview'] is Map<String, dynamic>
          ? DishReview.fromJson(json['dishReview'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

/// Nutritional information per item
class NutritionalInfo {
  final double kcal;
  final double protein;
  final double fat;
  final double carbs;

  const NutritionalInfo({
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  factory NutritionalInfo.fromJson(Map<String, dynamic> json) {
    return NutritionalInfo(
      // New API: 'kcal', legacy fallback: 'energyKcal'
      kcal: (json['kcal'] as num?)?.toDouble() ??
          (json['energyKcal'] as num?)?.toDouble() ??
          0.0,
      // New API: 'protein', legacy fallback: 'proteinGm'
      protein: (json['protein'] as num?)?.toDouble() ??
          (json['proteinGm'] as num?)?.toDouble() ??
          0.0,
      // New API: 'fat', legacy fallback: 'fatGm'
      fat: (json['fat'] as num?)?.toDouble() ??
          (json['fatGm'] as num?)?.toDouble() ??
          0.0,
      // New API: 'carbs', legacy fallback: 'carbGm'
      carbs: (json['carbs'] as num?)?.toDouble() ??
          (json['carbGm'] as num?)?.toDouble() ??
          0.0,
    );
  }
}
