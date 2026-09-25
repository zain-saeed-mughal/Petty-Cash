import 'package:petty_cash/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../config/app_theme.dart';

class LanguageSelectionScreen extends StatelessWidget {
  final VoidCallback onLanguageSelected;

  const LanguageSelectionScreen({super.key, required this.onLanguageSelected});

  @override
  Widget build(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    final isUrdu = langProvider.currentLanguage == 'ur';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Directionality(
        textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.language,
                    size: 80,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    langProvider.tr('language_selection'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 48),
                  _buildLanguageButton(
                    context: context,
                    title: context.t('English'),
                    subtitle: context.t('English'),
                    isSelected: langProvider.currentLanguage == 'en',
                    onTap: () => langProvider.setLanguage('en'),
                  ),
                  const SizedBox(height: 16),
                  _buildLanguageButton(
                    context: context,
                    title: 'اردو',
                    subtitle: context.t('Urdu'),
                    isSelected: langProvider.currentLanguage == 'ur',
                    onTap: () => langProvider.setLanguage('ur'),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (!langProvider.isLanguageSelected) {
                        langProvider.setLanguage('en'); // default if not tapped
                      }
                      onLanguageSelected();
                    },
                    child: Text(
                      langProvider.tr('continue'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
              : Colors.white,
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : AppTheme.borderLight,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? AppTheme.primaryBlue
                        : AppTheme.primaryNavy,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primaryBlue,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}
