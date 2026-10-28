import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/demo_guard.dart';

export '../../core/utils/demo_guard.dart' show DemoModeException, kDemoRestrictedMessage;

/// Base class for all repositories
/// Provides common functionality like Supabase access and error handling
abstract class BaseRepository {
  BaseRepository(this._ref);

  final Ref _ref;

  /// Riverpod ref for repositories that compose other repositories
  /// (LOGIC_PEOPLE: player flows that create/link accounts).
  @protected
  Ref get ref => _ref;

  /// Get Supabase client
  SupabaseClient get supabase => _ref.read(supabaseClientProvider);

  /// Get current tenant ID
  /// Throws if no tenant is selected
  int get currentTenantId {
    // This will be implemented by TenantRepository or injected
    throw UnimplementedError('Override in subclass or use mixin');
  }

  /// DEMO_GUARD: Ionic `checkDemoRestriction()`.
  ///
  /// Call at the start of every mutation that Ionic's db.service blocks for
  /// the demo account. Shows the warning toast
  /// "Diese Funktion ist im Demo-Modus nicht verfügbar." and throws
  /// [DemoModeException] when the signed-in user is the demo account.
  void ensureNotDemo(String operation) {
    DemoGuard.check(_currentUserEmail(), operation);
  }

  /// Ionic `isDemo()`.
  bool get isDemo => DemoGuard.isDemoEmail(_currentUserEmail());

  String? _currentUserEmail() {
    try {
      return supabase.auth.currentUser?.email;
    } catch (_) {
      // Supabase not initialised (tests) → never demo.
      return null;
    }
  }

  /// Handle Supabase errors consistently
  T handleError<T>(Object error, StackTrace stack, String operation) {
    // DEMO_GUARD: keep the typed demo error so the UI can show its text.
    if (error is DemoModeException) {
      Error.throwWithStackTrace(error, stack);
    }

    // SEC-006: Only log errors in debug mode to avoid exposing internal structure
    if (kDebugMode) {
      debugPrint('[$runtimeType] Error in $operation: $error');
      debugPrint('$stack');
    }

    // Rethrow with more context
    if (error is PostgrestException) {
      throw RepositoryException(
        message: error.message,
        code: error.code,
        operation: operation,
        originalError: error,
      );
    }

    throw RepositoryException(
      message: error.toString(),
      operation: operation,
      originalError: error,
    );
  }
}

/// Mixin for repositories that need tenant context
mixin TenantAwareRepository on BaseRepository {
  int? _tenantId;
  bool _tenantLocked = false;

  /// Set the current tenant ID
  ///
  /// SOL_FIX1: a repository instance bound to one tenant via
  /// [bindTenantId] never changes its tenant again, so a running
  /// multi-step operation cannot switch tenants between two queries
  /// (tenant switch A→B mid-flow).
  void setTenantId(int tenantId) {
    if (_tenantLocked && _tenantId != tenantId) {
      throw StateError(
        '$runtimeType is bound to tenant $_tenantId and cannot switch to '
        '$tenantId; use a per-tenant instance instead.',
      );
    }
    _tenantId = tenantId;
  }

  /// SOL_FIX1: binds this instance permanently to [tenantId] (per-tenant
  /// repository instances, see `*RepositoryForTenantProvider`).
  void bindTenantId(int tenantId) {
    setTenantId(tenantId);
    _tenantLocked = true;
  }

  /// Get tenant ID or throw if not set
  @override
  int get currentTenantId {
    if (_tenantId == null) {
      throw RepositoryException(
        message: 'Tenant ID not set',
        operation: 'getTenantId',
      );
    }
    return _tenantId!;
  }

  /// Check if tenant is set
  bool get hasTenantId => _tenantId != null;

  /// SEC-003: Sanitizes user input for use in ILIKE patterns
  /// Escapes SQL wildcards (%, _) to prevent pattern injection
  String sanitizeSearchQuery(String input) {
    // Escape SQL ILIKE wildcards using backslash (PostgreSQL default)
    return input
        .replaceAll(r'\', r'\\') // Escape backslash first
        .replaceAll('%', r'\%') // Escape %
        .replaceAll('_', r'\_'); // Escape _
  }
}

/// Custom exception for repository operations
class RepositoryException implements Exception {
  const RepositoryException({
    required this.message,
    required this.operation,
    this.code,
    this.originalError,
  });

  final String message;
  final String operation;
  final String? code;
  final Object? originalError;

  @override
  String toString() {
    return 'RepositoryException: $message (operation: $operation${code != null ? ', code: $code' : ''})';
  }
}

/// BL-002: Exception for duplicate attendance entries
class DuplicateAttendanceException extends RepositoryException {
  const DuplicateAttendanceException({
    required super.message,
    required this.existingId,
    required this.date,
  }) : super(operation: 'createAttendance', code: 'DUPLICATE');

  final int existingId;
  final String date;
}

/// Result type for operations that can fail
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

class Failure<T> extends Result<T> {
  const Failure(this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;
}

/// Extension methods for Result
extension ResultExtension<T> on Result<T> {
  /// Get data or throw
  T get dataOrThrow {
    return switch (this) {
      Success<T>(data: final data) => data,
      Failure<T>(error: final error) => throw error,
    };
  }

  /// Get data or null
  T? get dataOrNull {
    return switch (this) {
      Success<T>(data: final data) => data,
      Failure<T>() => null,
    };
  }

  /// Map success value
  Result<R> map<R>(R Function(T data) mapper) {
    return switch (this) {
      Success<T>(data: final data) => Success(mapper(data)),
      Failure<T>(error: final e, stackTrace: final s) => Failure(e, s),
    };
  }

  /// Handle both cases
  R when<R>({
    required R Function(T data) success,
    required R Function(Object error, StackTrace? stack) failure,
  }) {
    return switch (this) {
      Success<T>(data: final data) => success(data),
      Failure<T>(error: final e, stackTrace: final s) => failure(e, s),
    };
  }
}
