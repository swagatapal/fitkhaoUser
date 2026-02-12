/// Request model for sending OTP
class OtpRequestModel {
  final String phoneNumber;

  const OtpRequestModel({
    required this.phoneNumber,
  });

  Map<String, dynamic> toJson() {
    // Legacy/default shape used in earlier mocks
    return {
      'phone_number': phoneNumber,
    };
  }

  /// API-specific shape expected by current backend
  Map<String, dynamic> toApiJson() {
    return {
      "mobileNumber": phoneNumber,
    };
  }
}

/// Response model for OTP sent
class OtpResponseModel {
  final bool success;
  final String message;
  final String? otpId;
  final int? expiresIn;
  final OtpData? data;
  final String? timestamp;
  final ApiError? error;

  const OtpResponseModel({
    required this.success,
    required this.message,
    this.otpId,
    this.expiresIn,
    this.data,
    this.timestamp,
    this.error,
  });

  factory OtpResponseModel.fromJson(Map<String, dynamic> json) {
    // Support both previous mock format and new API format
    final dataJson = json['data'];
    return OtpResponseModel(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      otpId: json['otp_id'] as String?, // legacy mock field
      expiresIn: json['expires_in'] as int?, // legacy mock field
      data: dataJson is Map<String, dynamic> ? OtpData.fromJson(dataJson) : null,
      timestamp: json['timestamp'] as String?,
      error: json['error'] is Map<String, dynamic>
          ? ApiError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }
}

class OtpData {
  final String? mobileNumber;
  final String? otp;
  final DateTime? expiresAt;

  const OtpData({this.mobileNumber, this.otp, this.expiresAt});

  factory OtpData.fromJson(Map<String, dynamic> json) {
    return OtpData(
      mobileNumber: json['mobileNumber'] as String?,
      otp: json['otp'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
    );
  }
}

class ApiError {
  final String? code;
  final String? details;

  const ApiError({this.code, this.details});

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      code: json['code'] as String?,
      details: json['details'] as String?,
    );
  }
}
