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
    _showSnackBar(ScaffoldMessenger.of(context), context, message, type);
  }

  static void showGlobal(
    String message, {
    AppSnackbarType type = AppSnackbarType.info,
  }) {
    final state = messengerKey.currentState;
    if (state != null) {
      _showSnackBar(state, messengerKey.currentContext, message, type);
    }
  }

  static void _showSnackBar(
    ScaffoldMessengerState messengerState,
    BuildContext? context,
    String message,
    AppSnackbarType type,
  ) {
    final style = _style(type);
    final screenHeight = context != null
        ? MediaQuery.of(context).size.height
        : 800.0;

    final EdgeInsets customMargin = EdgeInsets.only(
      bottom: (screenHeight / 2) - 70,
      left: 32,
      right: 32,
    );

    messengerState.hideCurrentSnackBar();
    messengerState.showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        margin: customMargin,
        elevation: 0,
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.zero,
        content: GestureDetector(
          onPanEnd: (details) {
            final dx = details.velocity.pixelsPerSecond.dx.abs();
            final dy = details.velocity.pixelsPerSecond.dy.abs();

            if (dx > 100 || dy > 100) {
              messengerState.hideCurrentSnackBar();
            }
          },
          child: Container(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  style.$2,
                  color: style.$1,
                  size: 72,
                  shadows: const [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: style.$1,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    shadows: const [
                      Shadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static (Color, IconData) _style(AppSnackbarType type) {
    switch (type) {
      case AppSnackbarType.success:
        return (Colors.green, Icons.check_circle);
      case AppSnackbarType.error:
        return (Colors.red, Icons.cancel);
      case AppSnackbarType.warning:
        return (Colors.orange, Icons.warning);
      case AppSnackbarType.info:
        return (Colors.blue, Icons.info);
    }
  }
}
