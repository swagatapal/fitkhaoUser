/// Model for device registration request
class DeviceRegistrationRequest {
  final String deviceToken;
  final String deviceType;
  final String deviceId;
  final String appVersion;
  final String userType;

  const DeviceRegistrationRequest({
    required this.deviceToken,
    required this.deviceType,
    required this.deviceId,
    required this.appVersion,
    this.userType = 'user',
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceToken': deviceToken,
      'deviceType': deviceType,
      'deviceId': deviceId,
      'appVersion': appVersion,
      'userType': userType,
    };
  }
}

/// Model for device registration response
class DeviceRegistrationResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  const DeviceRegistrationResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory DeviceRegistrationResponse.fromJson(Map<String, dynamic> json) {
    return DeviceRegistrationResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}
