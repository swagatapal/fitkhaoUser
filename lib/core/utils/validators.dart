/// Validation utility class for form inputs and business logic validation
class Validators {
  Validators._();

  /// Validates phone number
  /// Returns error message if invalid, null if valid
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Remove any whitespace
    final cleanedValue = value.replaceAll(RegExp(r'\s+'), '');

    if (cleanedValue.length != 10) {
      return 'Please enter a valid 10-digit phone number';
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(cleanedValue)) {
      return 'Phone number should contain only digits';
    }

    // Check if phone number starts with valid Indian mobile prefix (6-9)
    if (!RegExp(r'^[6-9]').hasMatch(cleanedValue)) {
      return 'Please enter a valid Indian mobile number';
    }

    return null;
  }

  /// Validates OTP code
  /// Returns error message if invalid, null if valid
  static String? validateOTP(String? value, {int length = 6}) {
    if (value == null || value.isEmpty) {
      return 'OTP is required';
    }

    if (value.length != length) {
      return 'Please enter a valid $length-digit OTP';
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'OTP should contain only digits';
    }

    return null;
  }

  /// Validates email address
  /// Returns error message if invalid, null if valid
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  /// Validates name (first name, last name, etc.)
  /// Returns error message if invalid, null if valid
  static String? validateName(String? value, {String fieldName = 'Name'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    if (value.length < 2) {
      return '$fieldName must be at least 2 characters';
    }

    if (value.length > 50) {
      return '$fieldName must be less than 50 characters';
    }

    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
      return '$fieldName should contain only letters';
    }

    return null;
  }

  /// Validates required field
  /// Returns error message if empty, null if valid
  static String? validateRequired(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates minimum length
  /// Returns error message if too short, null if valid
  static String? validateMinLength(String? value, int minLength, {String fieldName = 'This field'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    if (value.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }

    return null;
  }

  /// Validates maximum length
  /// Returns error message if too long, null if valid
  static String? validateMaxLength(String? value, int maxLength, {String fieldName = 'This field'}) {
    if (value != null && value.length > maxLength) {
      return '$fieldName must be less than $maxLength characters';
    }

    return null;
  }

  /// Validates address
  /// Returns error message if invalid, null if valid
  static String? validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Address is required';
    }

    if (value.length < 10) {
      return 'Please enter a complete address';
    }

    if (value.length > 200) {
      return 'Address must be less than 200 characters';
    }

    return null;
  }

  /// Validates pincode (6 digits)
  /// Returns error message if invalid, null if valid
  static String? validatePincode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Pincode is required';
    }

    if (value.length != 6) {
      return 'Please enter a valid 6-digit pincode';
    }

    if (!RegExp(r'^[0-9]{6}$').hasMatch(value)) {
      return 'Pincode should contain only digits';
    }

    return null;
  }
}
