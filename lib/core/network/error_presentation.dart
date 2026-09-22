import 'package:flutter/material.dart';

import '../../shared/tokens/app_colors.dart';
import 'app_exception.dart';

/// Which visual treatment an [AppException] gets — kept distinct from
/// the exception types themselves so the UI layer has one place to
/// decide "does this look like an error or like a neutral status",
/// per Milestone 1.3's requirement that offline is never visually
/// collapsed into a generic server-error look.
enum ErrorKind { offline, serverError, unauthorized, unauthenticated, unknown }

/// UI-ready presentation for an [AppException]: an icon, a tint, and
/// the exception's own plain-language message passed through
/// unchanged (that message is already UI-safe per `app_exception.dart`
/// — this layer only adds the icon/kind, never rewrites the text).
class ErrorPresentation {
  const ErrorPresentation({
    required this.kind,
    required this.icon,
    required this.color,
    required this.message,
  });

  final ErrorKind kind;
  final IconData icon;
  final Color color;
  final String message;

  /// The only place an [AppException] is mapped to its on-screen
  /// treatment — call sites never switch on the exception type
  /// themselves. Exhaustive over [AppException]'s sealed subtypes, so
  /// adding a new exception type is a compile error here until this
  /// mapping is updated too.
  factory ErrorPresentation.of(AppException exception) {
    return switch (exception) {
      NetworkUnreachableException() => ErrorPresentation(
        kind: ErrorKind.offline,
        icon: Icons.wifi_off_rounded,
        color: AppColors.textSecondary,
        message: exception.message,
      ),
      ServerErrorException() => ErrorPresentation(
        kind: ErrorKind.serverError,
        icon: Icons.cloud_off_rounded,
        color: AppColors.danger,
        message: exception.message,
      ),
      UnauthorizedException() => ErrorPresentation(
        kind: ErrorKind.unauthorized,
        icon: Icons.lock_outline_rounded,
        color: AppColors.danger,
        message: exception.message,
      ),
      UnauthenticatedException() => ErrorPresentation(
        kind: ErrorKind.unauthenticated,
        icon: Icons.login_rounded,
        color: AppColors.danger,
        message: exception.message,
      ),
      UnknownApiException() => ErrorPresentation(
        kind: ErrorKind.unknown,
        icon: Icons.error_outline_rounded,
        color: AppColors.danger,
        message: exception.message,
      ),
    };
  }
}
