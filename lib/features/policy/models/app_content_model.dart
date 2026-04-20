/// Response model for app content API (terms / privacy policy)
class AppContentResponse {
  final bool success;
  final String message;
  final AppContentData? data;

  const AppContentResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory AppContentResponse.fromJson(Map<String, dynamic> json) {
    return AppContentResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? AppContentData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class AppContentData {
  final AppContent content;

  const AppContentData({required this.content});

  factory AppContentData.fromJson(Map<String, dynamic> json) {
    return AppContentData(
      content: AppContent.fromJson(json['content'] as Map<String, dynamic>),
    );
  }
}

class AppContent {
  final String id;
  final String code;
  final String details;

  const AppContent({
    required this.id,
    required this.code,
    required this.details,
  });

  factory AppContent.fromJson(Map<String, dynamic> json) {
    return AppContent(
      id: json['_id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      details: json['details'] as String? ?? '',
    );
  }
}
