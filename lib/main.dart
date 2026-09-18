import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'config/app_theme.dart';
import 'config/app_constants.dart';
import 'models/user_model.dart';
import 'providers/auth_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/user_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/office_boy/office_boy_dashboard.dart';
import 'screens/finance/finance_dashboard.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/super_admin/super_admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PettyCashApp());
}

class PettyCashApp extends StatefulWidget {
  final bool initializeServices;

  const PettyCashApp({super.key, this.initializeServices = true});

  @override
  State<PettyCashApp> createState() => _PettyCashAppState();
}

class _PettyCashAppState extends State<PettyCashApp> {
  bool _isInitialized = false;

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
    await SupabaseService().initialize();
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const _StartupSplash(),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, auth, notif) => notif!..updateUser(auth.currentUser?.uid),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const RoleRouter(),
      ),
    );
  }
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 58),
              SizedBox(height: 14),
              Text(
                AppConstants.appName,
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  bool _isRestoring = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreSession();
    });
  }

  Future<void> _restoreSession() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.restoreSession();
    if (mounted) {
      setState(() {
        _isRestoring = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRestoring) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
