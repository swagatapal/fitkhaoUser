import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/auth_state.dart';
import '../models/profile_update_model.dart';
import '../models/verify_otp_model.dart';
import '../repository/auth_repository.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  Timer? _resendTimer;
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AuthState());

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void updatePhoneNumber(String phoneNumber) {
    state = state.copyWith(phoneNumber: phoneNumber, errorMessage: null);
  }

  void updateCountryCode(String countryCode) {
    state = state.copyWith(countryCode: countryCode);
  }

  void updateOtp(String otp) {
    state = state.copyWith(otp: otp, errorMessage: null);
  }

  void toggleTermsAccepted() {
    state = state.copyWith(isTermsAccepted: !state.isTermsAccepted);
  }

  void setTermsAccepted(bool value) {
    state = state.copyWith(isTermsAccepted: value);
  }

  String? validatePhoneNumber() {
    // No need to check for empty since button is disabled until 10 digits entered
    if (state.phoneNumber.length != 10) {
      return 'Please enter a valid 10-digit phone number';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(state.phoneNumber)) {
      return 'Phone number should contain only digits';
    }
    return null;
  }

  String? validateOtp() {
    if (state.otp.isEmpty) {
      return 'Please enter OTP';
    }
    if (state.otp.length != 6) {
      return 'Please enter complete 6-digit OTP';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(state.otp)) {
      return 'OTP should contain only digits';
    }
    return null;
  }

  bool validateForm() {
    final phoneError = validatePhoneNumber();
    if (phoneError != null) {
      state = state.copyWith(errorMessage: phoneError);
      return false;
    }

    if (!state.isTermsAccepted) {
      state = state.copyWith(
        errorMessage: 'Please accept the terms and conditions',
      );
      return false;
    }

    state = state.copyWith(errorMessage: null);
    return true;
  }

  bool validateOtpForm() {
    final otpError = validateOtp();
    if (otpError != null) {
      state = state.copyWith(errorMessage: otpError);
      return false;
    }

    state = state.copyWith(errorMessage: null);
    return true;
  }

  /// Send OTP to the provided phone number
  Future<bool> sendOtp() async {
    if (!validateForm()) {
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _authRepository.sendOTP(
        phoneNumber: state.phoneNumber,
      );

      if (response.success) {
        // Start resend timer
        state = state.copyWith(
          isLoading: false,
          errorMessage: null,
          receivedOtpMessage: response.message,
        );
        _startResendTimer();
        return true;
      } else {
        debugPrint('[AuthNotifier] Send OTP failed: '
            '${response.error?.details ?? response.message}');
        state = state.copyWith(
          isLoading: false,
          errorMessage: response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Verify OTP
  /// Returns VerifyOtpResponseModel on success, null on failure
  Future<VerifyOtpResponseModel?> verifyOtp() async {
    if (!validateOtpForm()) {
      return null;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _authRepository.verifyOTP(
        phoneNumber: state.phoneNumber,
        countryCode: state.countryCode,
        otp: state.otp,
      );

      if (response.success) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: null,
        );
        return response;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: response.message,
        );
        return null;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return null;
    }
  }

  /// Resend OTP
  Future<bool> resendOtp() async {
    state = state.copyWith(isResendingOtp: true, errorMessage: null);

    try {
      final response = await _authRepository.resendOTP(
        phoneNumber: state.phoneNumber,
        countryCode: state.countryCode,
      );

      if (response.success) {
        state = state.copyWith(
          isResendingOtp: false,
          errorMessage: null,
          receivedOtpMessage: response.message,
        );
        _startResendTimer();
        return true;
      } else {
        state = state.copyWith(
          isResendingOtp: false,
          errorMessage: response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isResendingOtp: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Start resend timer
  void _startResendTimer() {
    _resendTimer?.cancel();
    state = state.copyWith(
      resendTimer: 60,
      canResend: false,
    );

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.resendTimer > 0) {
        state = state.copyWith(resendTimer: state.resendTimer - 1);
      } else {
        state = state.copyWith(canResend: true);
        timer.cancel();
      }
    });
  }

  /// Save user name
  void saveName(String name) {
    state = state.copyWith(name: name);
  }

  void saveImageUrl(String imgUrl){
    state = state.copyWith(imgUrl: imgUrl);
  }
  /// Save user gender and date of birth
  void savePersonalInfo({
    required String gender,
    required DateTime dateOfBirth,
    required double height,
    required double weight,
    required double age,
    required bool doesExercise,
  }) {
    state = state.copyWith(
      gender: gender,
      dateOfBirth: dateOfBirth,
      height: height,
      weight: weight,
      age: age,
      doesExercise: doesExercise,
    );
  }

  /// Save address information
  void saveAddress({
    required String buildingNameNumber,
    required String street,
    required String pincode,
    double? latitude,
    double? longitude,
  }) {
    state = state.copyWith(
      buildingNameNumber: buildingNameNumber,
      street: street,
      pincode: pincode,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Save BMI and health score
  void saveHealthData({
    required double bmi,
    required int healthScore,
  }) {
    state = state.copyWith(
      bmi: bmi,
      healthScore: healthScore,
    );
  }

  /// Save detailed health information
  void saveDetailedHealthInfo({
    required double height,
    required double weight,
    required double age,
    required String physicalActivityLevel,
    required bool doesExercise,
    int? exerciseDaysPerWeek,
    double? exerciseDurationHours,
    required String exerciseType,
    required bool pregnancy,
    String? pregnancyStage,
    required bool lactation,
    String? lactationStage,
    required bool diabetes,
    required bool hypertension,
    required bool cardiacProblem,
    required bool kidneyDisease,
    required bool liverRelatedProblem,
    required String otherConditions,
    required String regularityStatus,
    required String selectedGoal,
  }) {
    state = state.copyWith(
      height: height,
      weight: weight,
      age: age,
      physicalActivityLevel: physicalActivityLevel,
      doesExercise: doesExercise,
      exerciseDaysPerWeek: exerciseDaysPerWeek,
      exerciseDurationHours: exerciseDurationHours,
      exerciseType: exerciseType,
      pregnancy: pregnancy,
      pregnancyStage: pregnancyStage,
      lactation: lactation,
      lactationStage: lactationStage,
      diabetes: diabetes,
      hypertension: hypertension,
      cardiacProblem: cardiacProblem,
      kidneyDisease: kidneyDisease,
      liverRelatedProblem: liverRelatedProblem,
      otherConditions: otherConditions,
      regularityStatus: regularityStatus,
      selectedGoal: selectedGoal,
    );
  }

  /// Load user profile from API
  Future<bool> loadProfile() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _authRepository.getProfile();

      debugPrint('[AuthNotifier] Profile fetch response: $response');

      // Check if fetch was successful
      final success = response['success'] == true;
      final data = response['data'] as Map<String, dynamic>?;
      final user = data?['user'] as Map<String, dynamic>?;
      final profile = user?['profile'] as Map<String, dynamic>?;

      if (success && profile != null) {
        // Extract profile data
        final name = profile['name'] as String? ?? '';
        final imgUrl = profile['imgUrl'] as String? ?? "";
        final age = profile['age'] as int? ?? 0;
        final gender = profile['gender'] as String? ?? 'male';
        final weight = (profile['weight'] as num?)?.toDouble() ?? 0.0;
        final height = (profile['height'] as num?)?.toDouble() ?? 0.0;
        final doesWorkout = profile['doesWorkout'] as bool? ?? false;
        final workoutDaysPerWeek = profile['workoutDaysPerWeek'] as int? ?? 0;
        final workoutHoursPerDay = (profile['workoutHoursPerDay'] as num?)?.toDouble() ?? 0.0;
        final exerciseType = profile['exerciseType'] as String? ?? 'type-1';
        final profession = profile['profession'] as String? ?? 'type-1';
        final selectedGoal = profile['selectedGoal'] as String? ?? 'regular-bmi-maintenance';

        // Extract nutritional targets
        final targetProtein = (profile['targetProtein'] as num?)?.toDouble();
        final targetFat = (profile['targetFat'] as num?)?.toDouble();
        final targetCarbs = (profile['targetCarbs'] as num?)?.toDouble();
        final targetKCalories = (profile['targetKCalories'] as num?)?.toDouble();

        // Parse lastUpdatedTargetKCal
        DateTime? lastUpdatedTargetKCal;
        final lastUpdatedStr = profile['lastUpdatedTargetKCal'] as String?;
        if (lastUpdatedStr != null && lastUpdatedStr.isNotEmpty) {
          try {
            lastUpdatedTargetKCal = DateTime.parse(lastUpdatedStr);
          } catch (e) {
            debugPrint('[AuthNotifier] Error parsing lastUpdatedTargetKCal: $e');
          }
        }

        // Calculate date of birth from age (approximate)
        DateTime? dateOfBirth;
        if (age > 0) {
          final now = DateTime.now();
          dateOfBirth = DateTime(now.year - age, now.month, now.day);
        }

        // Extract address
        final address = profile['address'] as Map<String, dynamic>?;
        final buildingName = address?['buildingName'] as String? ?? '';
        final street = address?['street'] as String? ?? '';
        final pincode = address?['pincode'] as String? ?? '';
        final latitude = (address?['latitude'] as num?)?.toDouble();
        final longitude = (address?['longitude'] as num?)?.toDouble();

        // Extract special conditions
        final specialConditions = profile['specialConditions'] as Map<String, dynamic>?;
        final diabetes = specialConditions?['diabetes'] as bool? ?? false;
        final hyperTension = specialConditions?['hyperTension'] as bool? ?? false;
        final cardiacProblem = specialConditions?['cardiacProblem'] as bool? ?? false;
        final liverIssues = specialConditions?['liverIssues'] as bool? ?? false;
        final kidneyIssues = specialConditions?['kidneyIssues'] as bool? ?? false;
        final otherConditions = specialConditions?['other'] as String? ?? '';

        // Extract digestive issues
        final digestiveIssues = profile['digestiveIssues'] as Map<String, dynamic>?;
        final regularlyConstipated = digestiveIssues?['regularlyConstipated'] as bool? ?? false;
        final diarrhoeal = digestiveIssues?['diarrhoeal'] as bool? ?? false;
        final both = digestiveIssues?['both'] as bool? ?? false;
        final none = digestiveIssues?['none'] as bool? ?? false;

        // Map digestive issues to regularityStatus
        String regularityStatus = 'None';
        if (both) {
          regularityStatus = 'Both';
        } else if (regularlyConstipated) {
          regularityStatus = 'Constipated';
        } else if (diarrhoeal) {
          regularityStatus = 'Diarrhoeal';
        }

        // Extract pregnancy and lactation stages
        final pregnancyStage = profile['pregnancy'] as String?;
        final lactationStage = profile['lactation'] as String?;

        // Extract profile updatedAt timestamp
        DateTime? profileUpdatedAt;
        final updatedAtStr = user?['updatedAt'] as String?;
        if (updatedAtStr != null && updatedAtStr.isNotEmpty) {
          try {
            profileUpdatedAt = DateTime.parse(updatedAtStr);
          } catch (e) {
            debugPrint('[AuthNotifier] Error parsing profileUpdatedAt: $e');
          }
        }

        // Update state with fetched data
        state = state.copyWith(
          name: name,
          imgUrl: imgUrl,
          gender: gender,
          dateOfBirth: dateOfBirth,
          height: height > 0 ? height : null,
          weight: weight > 0 ? weight : null,
          age: double.parse(age.toString()),
          doesExercise: doesWorkout,
          exerciseDaysPerWeek: workoutDaysPerWeek > 0 ? workoutDaysPerWeek : null,
          exerciseDurationHours: workoutHoursPerDay > 0 ? workoutHoursPerDay : null,
          exerciseType: exerciseType,
          physicalActivityLevel: profession,
          buildingNameNumber: buildingName,
          street: street,
          pincode: pincode,
          latitude: latitude,
          longitude: longitude,
          diabetes: diabetes,
          hypertension: hyperTension,
          cardiacProblem: cardiacProblem,
          kidneyDisease: kidneyIssues,
          liverRelatedProblem: liverIssues,
          otherConditions: otherConditions,
          regularityStatus: regularityStatus,
          pregnancy: pregnancyStage != null && pregnancyStage.isNotEmpty,
          pregnancyStage: pregnancyStage,
          lactation: lactationStage != null && lactationStage.isNotEmpty,
          lactationStage: lactationStage,
          targetProtein: targetProtein,
          targetFat: targetFat,
          targetCarbs: targetCarbs,
          targetKCalories: targetKCalories,
          lastUpdatedTargetKCal: lastUpdatedTargetKCal,
          selectedGoal: selectedGoal,
          profession: profession,
          profileUpdatedAt: profileUpdatedAt,
          isLoading: false,
          errorMessage: null,
        );

        debugPrint('[AuthNotifier] Profile loaded successfully');
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load profile data.',
        );
        return false;
      }
    } catch (e) {
      debugPrint('[AuthNotifier] Profile load error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Update user profile (for editing existing profile)
  /// Allows partial updates without strict validation
  Future<bool> updateProfile() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Create profile update request from current state
      final profileData = ProfileUpdateRequest.fromAuthState(state);

      debugPrint('[AuthNotifier] Profile data prepared: ${profileData.toFullJson()}');

      // Call API to update profile
      final response = await _authRepository.updateProfile(
        profileData: profileData,
      );

      debugPrint('[AuthNotifier] Profile update API response: $response');

      // Check if update was successful
      final success = response['success'] == true;
      final message = response['message'] as String?;

      if (success) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: null,
        );
        debugPrint('[AuthNotifier] Profile updated successfully');
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: message ?? 'Failed to update profile. Please try again.',
        );
        return false;
      }
    } catch (e) {
      debugPrint('[AuthNotifier] Profile update error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Complete registration with all collected data
  /// Calls PUT API to update user profile
  /// Allows partial updates - users can skip optional fields
  Future<bool> completeRegistration() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Create profile update request from current state
      final profileData = ProfileUpdateRequest.fromAuthState(state);

      debugPrint('[AuthNotifier] Profile data prepared: ${profileData.toFullJson()}');

      // Call API to update profile
      final response = await _authRepository.updateProfile(
        profileData: profileData,
      );

      debugPrint('[AuthNotifier] Profile update API response: $response');

      // Check if update was successful
      final success = response['success'] == true;
      final message = response['message'] as String?;

      if (success) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: null,
        );
        debugPrint('[AuthNotifier] Profile updated successfully');
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: message ?? 'Failed to update profile. Please try again.',
        );
        return false;
      }
    } catch (e) {
      debugPrint('[AuthNotifier] Profile update error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Check if user exists by phone number
  /// Returns true if user is already logged in
  Future<bool> getUserByPhone(String phoneNumber) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Simulate processing delay
      await Future.delayed(const Duration(seconds: 1));

      // Check if user is logged in via repository
      final isLoggedIn = _authRepository.isLoggedIn();
      final storedPhone = _authRepository.getUserPhone();

      if (isLoggedIn && storedPhone == phoneNumber) {
        // User exists and is logged in
        state = state.copyWith(
          isLoading: false,
          phoneNumber: phoneNumber,
          errorMessage: null,
        );
        return true;
      } else {
        // User doesn't exist or not logged in
        state = state.copyWith(
          isLoading: false,
          errorMessage: null,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Logout user and clear all local data
  Future<bool> logout() async {
    try {
      // Clear local storage
      await _authRepository.logout();

      // Reset state
      _resendTimer?.cancel();
      state = const AuthState();

      debugPrint('[AuthNotifier] User logged out successfully');
      return true;
    } catch (e) {
      debugPrint('[AuthNotifier] Logout error: $e');
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void reset() {
    _resendTimer?.cancel();
    state = const AuthState();
  }
}

// Extension to capitalize first letter
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

// Provider for AuthNotifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository);
});
