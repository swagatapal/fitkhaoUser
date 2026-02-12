/// Base class for all application exceptions
sealed class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => message;
}

/// Authentication related exceptions
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Validation related exceptions
class ValidationException extends AppException {
  final Map<String, String>? errors;

  const ValidationException({
    required super.message,
    this.errors,
    super.code,
    super.originalError,
  });
}

/// Cache/Storage related exceptions
class CacheException extends AppException {
  const CacheException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Processing related exceptions
class ProcessingException extends AppException {
  const ProcessingException({
    super.message = 'Processing error. Please try again.',
    super.code,
    super.originalError,
  });
}

/// Network related exceptions
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Data not found exceptions
class NotFoundException extends AppException {
  const NotFoundException({
    super.message = 'Data not found.',
    super.code,
    super.originalError,
  });
}

/// Utility class to convert exceptions to user-friendly messages
class ExceptionHandler {
  ExceptionHandler._();

  /// Convert exception to user-friendly message
  static String getErrorMessage(dynamic error) {
    if (error is AppException) {
      return error.message;
    } else if (error is Exception) {
      return 'An unexpected error occurred. Please try again.';
    } else {
      return error.toString();
    }
  }

  /// Check if error is an authentication error
  static bool isAuthError(dynamic error) {
    return error is AuthException;
  }

  /// Check if error is a validation error
  static bool isValidationError(dynamic error) {
    return error is ValidationException;
  }

  /// Check if error is a storage error
  static bool isStorageError(dynamic error) {
    return error is CacheException;
  }
}
