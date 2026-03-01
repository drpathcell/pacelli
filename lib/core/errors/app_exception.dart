/// Base exception class for Pacelli app errors.
///
/// Provides a consistent way to handle errors throughout the app
/// with user-friendly messages and optional error codes.
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'AppException($code): $message';
}

/// Thrown when authentication fails (login, signup, token refresh).
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Thrown when a database query fails.
class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Thrown when the user doesn't have permission for an action.
class PermissionException extends AppException {
  const PermissionException({
    required super.message,
    super.code,
    super.originalError,
  });
}
