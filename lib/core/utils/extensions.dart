import 'package:flutter/material.dart';
import 'package:pacelli/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Handy extension methods used throughout the app.

/// Quick access to localised strings via `context.l10n`.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// DateTime formatting shortcuts.
extension DateTimeExtensions on DateTime {
  /// "1 Mar 2026"
  String get formatted => DateFormat('d MMM yyyy').format(this);

  /// "1 Mar" (short, no year)
  String get shortFormatted => DateFormat('d MMM').format(this);

  /// "1 Mar 2026, 14:30"
  String get formattedWithTime => DateFormat('d MMM yyyy, HH:mm').format(this);

  /// "Monday" / "Tuesday" etc.
  String get dayName => DateFormat('EEEE').format(this);

  /// Whether this date is today.
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Whether this date is tomorrow.
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day;
  }

  /// Whether this date is in the past (before today).
  bool get isOverdue {
    final today = DateTime.now();
    return isBefore(DateTime(today.year, today.month, today.day));
  }
}

/// String validation shortcuts.
extension StringExtensions on String {
  /// Basic email format check.
  bool get isValidEmail => RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);

  /// Capitalise the first letter.
  String get capitalised =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

/// BuildContext shortcuts for accessing theme and screen size.
extension ContextExtensions on BuildContext {
  /// Quick access to the current theme.
  ThemeData get theme => Theme.of(this);

  /// Quick access to the current text theme.
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Quick access to the current color scheme.
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Screen width.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Screen height.
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Show a snackbar with a message.
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(this).colorScheme.error
            : Theme.of(this).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
