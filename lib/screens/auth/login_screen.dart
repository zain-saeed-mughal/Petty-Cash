import 'package:petty_cash/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';
import '../../config/app_theme.dart';
import '../../config/app_constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: '');
  final _passwordController = TextEditingController(text: '');

  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final success = await auth.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      final user = auth.currentUser;
      final cleanedName = user?.name
          .replaceFirst(
            RegExp(r'^\s*super\s*admin\s*,?\s*', caseSensitive: false),
            '',
          )
          .trim();
      final displayName = cleanedName?.isNotEmpty == true
          ? cleanedName
          : user?.name.trim() ?? '';
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      final welcomeMessage = user?.isSuperAdmin == true
          ? '${lang.tr('welcome_admin')}$displayName!'
          : '${lang.tr('welcome_user')}$displayName!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(welcomeMessage),
          backgroundColor: isDark
              ? const Color(0xFF7C3AED)
              : AppTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider?>(context, listen: true);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final bgColor = isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight;

    return Directionality(
      textDirection: langProvider.currentLanguage == 'ur'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bgColor,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar: Theme Toggle & Language Toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Theme Switcher Button
                    _buildThemeBtn(themeProvider, isDark),

                    // Language Selector
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                        ),
                        boxShadow: isDark ? [] : AppTheme.premiumShadow,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildLangBtn('EN', 'en', langProvider, isDark),
                          const SizedBox(width: 3),
                          _buildLangBtn('اردو', 'ur', langProvider, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Main Form Content
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 480),
                          padding: EdgeInsets.all(isDesktop ? 44 : 28),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.surfaceDark : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.borderDark
                                  : AppTheme.borderLight,
                              width: 1,
                            ),
                            boxShadow: isDark
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF64748B)
                                          .withValues(alpha: 0.08),
                                      blurRadius: 28,
                                      offset: const Offset(0, 10),
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF64748B)
                                          .withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // App Brand Icon
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF8B5CF6)
                                              .withValues(alpha: 0.15)
                                          : AppTheme.primaryBlue
                                              .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF8B5CF6)
                                                .withValues(alpha: 0.3)
                                            : AppTheme.primaryBlue
                                                .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.account_balance_wallet_rounded,
                                      color: isDark
                                          ? const Color(0xFFA78BFA)
                                          : AppTheme.primaryBlue,
                                      size: 38,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Title & Subtitle
                                Center(
                                  child: Text(
                                    context.t(AppConstants.appName),
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.primaryNavy,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Center(
                                  child: Text(
                                    langProvider.tr('sign_in_to_continue'),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),

                                // Error Message
                                if (auth.errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.redAccent
                                              .withValues(alpha: 0.15)
                                          : const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.redAccent
                                                .withValues(alpha: 0.35)
                                            : const Color(0xFFFECACA),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline_rounded,
                                          color: isDark
                                              ? const Color(0xFFF87171)
                                              : const Color(0xFFDC2626),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            context.language.error(
                                              auth.errorMessage!,
                                            ),
                                            style: TextStyle(
                                              color: isDark
                                                  ? const Color(0xFFFCA5A5)
                                                  : const Color(0xFFB91C1C),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                // Email Field
                                TextFormField(
                                  controller: _emailController,
                                  textDirection: TextDirection.ltr,
                                  keyboardType: TextInputType.emailAddress,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.primaryNavy,
                                    fontSize: 15,
                                  ),
                                  decoration: _buildInputDecoration(
                                    langProvider.tr('email_address'),
                                    Icons.email_outlined,
                                    isDark: isDark,
                                    helperText: langProvider.isRtl
                                        ? 'مثال: name@example.com'
                                        : 'e.g. name@example.com',
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return langProvider.tr('empty_email');
                                    }
                                    if (!val.contains('@')) {
                                      return langProvider.tr('invalid_email');
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),

                                // Password Field
                                TextFormField(
                                  controller: _passwordController,
                                  textDirection: TextDirection.ltr,
                                  obscureText: _obscurePassword,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.primaryNavy,
                                    fontSize: 15,
                                  ),
                                  decoration: _buildInputDecoration(
                                    langProvider.tr('password'),
                                    Icons.lock_outline_rounded,
                                    isDark: isDark,
                                    helperText: langProvider.isRtl
                                        ? 'اپنا پاس ورڈ درج کریں'
                                        : 'Enter your password',
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return langProvider.tr(
                                        'empty_password',
                                      );
                                    }
                                    if (val.length < 6) {
                                      return langProvider.tr(
                                        'short_password',
                                      );
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),

                                // Forgot Password Link
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: TextButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            langProvider.tr('contact_admin'),
                                          ),
                                          backgroundColor: isDark
                                              ? AppTheme.surfaceDark
                                              : AppTheme.primaryNavy,
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(50, 30),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      langProvider.tr('forgot_password'),
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFFA78BFA)
                                            : AppTheme.primaryBlue,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Submit Button
                                Container(
                                  constraints:
                                      const BoxConstraints(minHeight: 52),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isDark
                                          ? const [
                                              Color(0xFF7C3AED),
                                              Color(0xFF8B5CF6),
                                            ]
                                          : const [
                                              AppTheme.primaryBlue,
                                              Color(0xFF1D4ED8),
                                            ],
                                      begin: AlignmentDirectional.centerStart,
                                      end: AlignmentDirectional.centerEnd,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isDark
                                                ? const Color(0xFF7C3AED)
                                                : AppTheme.primaryBlue)
                                            .withValues(alpha: 0.35),
                                        blurRadius: 14,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: auth.isLoading
                                        ? null
                                        : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          16,
                                        ),
                                      ),
                                    ),
                                    child: auth.isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Text(
                                            langProvider.tr('sign_in'),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Create Account Wrap
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment:
                                      WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      langProvider.tr('need_an_account'),
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  langProvider.tr(
                                                    'contact_super_admin',
                                                  ),
                                                ),
                                                backgroundColor: isDark
                                                    ? AppTheme.surfaceDark
                                                    : AppTheme.primaryNavy,
                                              ),
                                            );
                                      },
                                      child: Text(
                                        langProvider.tr('create_account'),
                                        style: TextStyle(
                                          color: isDark
                                              ? const Color(0xFFA78BFA)
                                              : AppTheme.primaryBlue,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeBtn(ThemeProvider? themeProvider, bool isDark) {
    if (themeProvider == null) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: themeProvider.toggleTheme,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
            ),
            boxShadow: isDark ? [] : AppTheme.premiumShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                size: 18,
                color: isDark ? const Color(0xFFA78BFA) : AppTheme.primaryBlue,
              ),
              const SizedBox(width: 6),
              Text(
                isDark ? 'Light' : 'Dark',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark ? const Color(0xFFCBD5E1) : AppTheme.primaryNavy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangBtn(
    String label,
    String code,
    LanguageProvider langProvider,
    bool isDark,
  ) {
    final isSelected = langProvider.currentLanguage == code;
    final primaryColor =
        isDark ? const Color(0xFF8B5CF6) : AppTheme.primaryBlue;
    return GestureDetector(
      onTap: () => langProvider.setLanguage(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B)),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon, {
    required bool isDark,
    Widget? suffixIcon,
    String? helperText,
  }) {
    final subColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final focusColor =
        isDark ? const Color(0xFF8B5CF6) : AppTheme.primaryBlue;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;
    final fillColor =
        isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF8FAFC);

    return InputDecoration(
      labelText: label,
      helperText: helperText,
      helperStyle: TextStyle(color: subColor, fontSize: 12),
      labelStyle: TextStyle(
        color: subColor,
        fontWeight: FontWeight.w400,
      ),
      floatingLabelStyle: TextStyle(
        color: focusColor,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: subColor),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: focusColor, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.6),
      ),
    );
  }
}
