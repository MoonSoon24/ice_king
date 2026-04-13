import 'package:flutter/material.dart';

enum AppSnackbarType { info, success, error, warning }

class AppSnackbar {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void show(
    BuildContext context,
    String message, {
    AppSnackbarType type = AppSnackbarType.info,
  }) {
    final style = _style(type);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        backgroundColor: style.$1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(style.$2, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showGlobal(
    String message, {
    AppSnackbarType type = AppSnackbarType.info,
  }) {
    final style = _style(type);
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        backgroundColor: style.$1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(style.$2, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static (Color, IconData) _style(AppSnackbarType type) {
    switch (type) {
      case AppSnackbarType.success:
        return (Colors.green.shade700, Icons.check_circle);
      case AppSnackbarType.error:
        return (Colors.red.shade700, Icons.error_outline);
      case AppSnackbarType.warning:
        return (Colors.orange.shade700, Icons.warning_amber_rounded);
      case AppSnackbarType.info:
        return (const Color(0xFF1565C0), Icons.info_outline);
    }
  }
}
