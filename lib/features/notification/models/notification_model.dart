/// Metadata attached to a notification (type, linked entity IDs, etc.)
class NotificationData {
  final String type;
  final String? orderId;
  final String? orderNumber;

  const NotificationData({
    required this.type,
    this.orderId,
    this.orderNumber,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      type: json['type'] as String? ?? '',
      orderId: json['orderId'] as String?,
      orderNumber: json['orderNumber'] as String?,
    );
  }
}

/// A single notification item
class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationData? data;
  final bool isRead;
  final bool isDeleted;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.data,
    required this.isRead,
    required this.isDeleted,
    required this.createdAt,
  });

  AppNotification copyWith({bool? isRead, bool? isDeleted}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      data: data,
      isRead: isRead ?? this.isRead,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: json['data'] is Map<String, dynamic>
          ? NotificationData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      isRead: json['isRead'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

/// Top-level API response wrapper
class NotificationResponse {
  final bool success;
  final String message;
  final List<AppNotification> notifications;

  const NotificationResponse({
    required this.success,
    required this.message,
    required this.notifications,
  });

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    final dataMap = json['data'] as Map<String, dynamic>?;
    final rawList = dataMap?['notifications'] as List<dynamic>? ?? [];
    return NotificationResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      notifications: rawList
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
