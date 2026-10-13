import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petty_cash/config/app_theme.dart';

double contrast(Color foreground, Color background) {
  final a = Color.alphaBlend(foreground, background).computeLuminance();
  final b = background.computeLuminance();
  return (a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05);
}

void main() {
  test('Dark foregrounds meet normal-text contrast on panels and tints', () {
    for (final foreground in [
      const Color(0xFF7C3AED), const Color(0xFF0D9488),
      const Color(0xFF64748B), const Color(0xFF94A3B8),
      AppTheme.roleFinance, AppTheme.roleOfficeBoy,
    ]) {
      final readable = AppTheme.onSurface(foreground, AppTheme.borderDark);
      for (final surface in [AppTheme.surfaceDark, AppTheme.borderDark]) {
        expect(contrast(readable, surface), greaterThanOrEqualTo(4.5));
      }
    }
  });
  test('Status text contrasts with the actual badge background', () {
    for (final pair in [
      (AppTheme.statusPending, AppTheme.statusPendingBg),
      (AppTheme.statusApproved, AppTheme.statusApprovedBg),
      (AppTheme.statusRejected, AppTheme.statusRejectedBg),
      (AppTheme.statusPaid, AppTheme.statusPaidBg),
    ]) {
      for (final background in [pair.$2,
        Color.alphaBlend(pair.$1.withValues(alpha: .18), AppTheme.surfaceDark)]) {
        expect(contrast(AppTheme.onSurface(pair.$1, background), background),
            greaterThanOrEqualTo(4.5));
      }
    }
  });
}
