import 'package:flutter/material.dart';

enum ToastType { success, error, info, warning }

void showAppToast(
  BuildContext context, {
  required String message,
  ToastType type = ToastType.success,
  IconData? icon,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();

  final Color bg;
  final Color fg;
  final IconData defaultIcon;

  switch (type) {
    case ToastType.success:
      bg = const Color(0xFF059669); // Emerald Green
      fg = Colors.white;
      defaultIcon = Icons.check_circle_rounded;
      break;
    case ToastType.error:
      bg = const Color(0xFFDC2626); // Crimson Red
      fg = Colors.white;
      defaultIcon = Icons.error_rounded;
      break;
    case ToastType.warning:
      bg = const Color(0xFFD97706); // Amber
      fg = Colors.white;
      defaultIcon = Icons.warning_rounded;
      break;
    case ToastType.info:
      bg = const Color(0xFF7C3AED); // Vibrant Purple
      fg = Colors.white;
      defaultIcon = Icons.info_rounded;
      break;
  }

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Row(
        children: [
          Icon(icon ?? defaultIcon, color: fg, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}
