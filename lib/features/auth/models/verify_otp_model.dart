/// Request model for verifying OTP
class VerifyOtpRequestModel {
  final String phoneNumber;
  final String countryCode;
  final String otp;
  final String? otpId;

  const VerifyOtpRequestModel({
    required this.phoneNumber,
    required this.countryCode,
    required this.otp,
    this.otpId,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone_number': phoneNumber,
      'country_code': countryCode,
      'otp': otp,
      if (otpId != null) 'otp_id': otpId,
    };
  }
}

/// Response model for OTP verification
class VerifyOtpResponseModel {
  final bool success;
  final String message;
  final String? authToken;
  final String? refreshToken;
  final UserData? user;

  const VerifyOtpResponseModel({
    required this.success,
    required this.message,
    this.authToken,
    this.refreshToken,
    this.user,
  });

  factory VerifyOtpResponseModel.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponseModel(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      authToken: json['auth_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      user: json['user'] != null
          ? UserData.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// User data model
class UserData {
  final String id;
  final String phoneNumber;
  final String? name;
  final String? email;
  final bool isNewUser;

  const UserData({
    required this.id,
    required this.phoneNumber,
    this.name,
    this.email,
    this.isNewUser = false,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      name: json['name'] as String?,
      email: json['email'] as String?,
      isNewUser: json['is_new_user'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      'is_new_user': isNewUser,
    };
  }
}
