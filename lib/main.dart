import 'package:petty_cash/l10n/context_l10n.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'services/supabase_service.dart';
import 'config/app_theme.dart';
import 'config/app_constants.dart';
import 'models/user_model.dart';
import 'providers/auth_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/user_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/language_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/office_boy/office_boy_dashboard.dart';
import 'screens/finance/finance_dashboard.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/super_admin/super_admin_dashboard.dart';
import 'services/push_notification_service.dart';
import 'services/database_service.dart';
import 'screens/finance/request_detail_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppProviders(child: PettyCashApp()));
}

class AppProviders extends StatelessWidget {
  final Widget child;
  const AppProviders({super.key, required this.child});
  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProxyProvider<AuthProvider, ExpenseProvider>(
        create: (_) => ExpenseProvider(),
        update: (_, auth, expense) => expense!..updateUser(auth.currentUser),
      ),
      ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
        create: (_) => UserProvider(),
        update: (_, auth, users) => users!..updateUserSession(auth.currentUser),
      ),
      ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
        create: (_) => NotificationProvider(),
        update: (_, auth, notifications) =>
            notifications!..updateUser(auth.currentUser?.uid),
      ),
    ],
    child: child,
  );
}

class PettyCashApp extends StatefulWidget {
  final bool initializeServices;

  const PettyCashApp({super.key, this.initializeServices = true});

  @override
  State<PettyCashApp> createState() => _PettyCashAppState();
}

class _PettyCashAppState extends State<PettyCashApp> {
  bool _isInitialized = false;
  String? _startupError;
  var _navigatorKey = GlobalKey<NavigatorState>();
  String? _navigationIdentity;
  StreamSubscription? _pushMessages, _pushOpens;

  @override
  void initState() {
    super.initState();
    if (widget.initializeServices) {
      _initializeServices();
    } else {
      _isInitialized = true;
    }
  }

  Future<void> _initializeServices() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (mounted) setState(() => _startupError = null);
      await context.read<LanguageProvider>().ready;
      await SupabaseService().initialize();
      await auth.restoreSession();
      if (!mounted) return;
      _pushMessages ??= PushNotificationService().messages.stream.listen((
        message,
      ) {
        if (!mounted || !auth.isAuthenticated) return;
        final ctx = _navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(ctx.t('New notification')),
              action: message.data['request_id'] is String
                  ? SnackBarAction(
                      label: context.t('Open'),
                      onPressed: () => _openRequest(message.data['request_id']),
                    )
                  : null,
            ),
          );
        }
      });
      _pushOpens ??= PushNotificationService().openedRequests.stream.listen(
        _openRequest,
      );
      setState(() => _isInitialized = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) PushNotificationService().flushPendingOpen();
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _startupError = context.t(
            'Unable to connect. Check your connection and try again.',
          ),
        );
      }
    }
  }

  Future<void> _openRequest(String id) async {
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final request = await DatabaseService().getRequest(id);
      if (!mounted || auth.currentUser?.uid != uid) return;
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => RequestDetailScreen(request: request),
        ),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _pushMessages?.cancel();
    _pushOpens?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<AuthProvider>().currentUser;
    final language = context.watch<LanguageProvider>();
    final navigationIdentity = identity == null
        ? 'signed-out'
        : identity.uid + identity.role.roleCode;
    if (_navigationIdentity != navigationIdentity) {
      _navigationIdentity = navigationIdentity;
      _navigatorKey = GlobalKey<NavigatorState>();
    }
    return MaterialApp(
      key: ValueKey(
        identity == null ? 'signed-out' : identity.uid + identity.role.roleCode,
      ),
      navigatorKey: _navigatorKey,
      title: context.t(AppConstants.appName),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forLanguage(language.currentLanguage),
      locale: language.locale,
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final currentLanguage = context.watch<LanguageProvider>();
        return Directionality(
          textDirection: currentLanguage.isRtl
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child ?? const SizedBox(),
        );
      },
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: _startupError != null
            ? Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          context.language.error(_startupError!),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _initializeServices,
                          child: Text(context.t('Try again')),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : _isInitialized
            ? const RoleRouter()
            : const _StartupSplash(key: ValueKey('splash')),
      ),
    );
  }
}

class _StartupSplash extends StatefulWidget {
  const _StartupSplash({super.key});

  @override
  State<_StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<_StartupSplash>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F172A),
              Color(0xFF312E81),
            ], // Deep navy to indigo
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // Animated Logo
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoFade.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1)
                                .withValues(alpha: 0.5),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Animated Typography
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textFade,
                child: Column(
                  children: [
                    const Text(
                      AppConstants.appName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t('Smart expense tracking, simplified'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),

            // Loading Indicator
            FadeTransition(
              opacity: _textFade,
              child: const Padding(
                padding: EdgeInsets.only(bottom: 64),
                child: SizedBox(
                  width: 120,
                  height: 3,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white24,
                    color: Color(0xFF818CF8), // Soft indigo
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    if (!auth.isAuthenticated || user == null) {
      return const LoginScreen();
    }

    switch (user.role) {
      case UserRole.superAdmin:
        return const SuperAdminDashboard();
      case UserRole.admin:
        return const AdminDashboard();
      case UserRole.finance:
        return const FinanceDashboard();
      case UserRole.officeBoy:
        return const OfficeBoyDashboard();
    }
  }
}
