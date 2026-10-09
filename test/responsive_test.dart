import 'package:petty_cash/widgets/settle_advance_dialog.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:petty_cash/config/app_theme.dart';
import 'package:petty_cash/providers/auth_provider.dart';
import 'package:petty_cash/providers/expense_provider.dart';
import 'package:petty_cash/providers/language_provider.dart';
import 'package:petty_cash/providers/theme_provider.dart';
import 'package:petty_cash/providers/user_provider.dart';
import 'package:petty_cash/providers/notification_provider.dart';
import 'package:petty_cash/providers/payment_provider.dart';
import 'package:petty_cash/providers/core_flow_provider.dart';

import 'core_flow_test_provider.dart';

import 'package:petty_cash/models/payment_models.dart';
import 'package:petty_cash/screens/payments/payment_center_screen.dart';
import 'package:petty_cash/screens/core/core_dashboard_screens.dart';
import 'package:petty_cash/models/user_model.dart';
import 'package:petty_cash/models/expense_request_model.dart';
import 'package:petty_cash/models/notification_model.dart';
import 'package:petty_cash/models/core_flow_models.dart';
import 'package:petty_cash/screens/auth/login_screen.dart';
import 'package:petty_cash/screens/reports/monthly_reporting_screen.dart';
import 'package:petty_cash/screens/super_admin/analytics_screen.dart';
import 'package:petty_cash/screens/finance/request_detail_screen.dart';
import 'package:petty_cash/screens/finance/payment_history_screen.dart';
import 'package:petty_cash/screens/finance/pending_requests_screen.dart';
import 'package:petty_cash/screens/finance/finance_overview_screen.dart';
import 'package:petty_cash/screens/admin/all_transactions_screen.dart';
import 'package:petty_cash/screens/admin/user_management_screen.dart';
import 'package:petty_cash/screens/office_boy/my_requests_screen.dart';
import 'package:petty_cash/screens/office_boy/new_request_screen.dart';
import 'package:petty_cash/widgets/notifications_panel.dart';
import 'package:petty_cash/widgets/rejection_reason_dialog.dart';
import 'package:petty_cash/widgets/user_account_dialog.dart';
import 'package:petty_cash/widgets/request_override_dialog.dart';
import 'package:petty_cash/screens/language_selection_screen.dart';
import 'package:petty_cash/screens/admin/admin_dashboard.dart';
import 'package:petty_cash/screens/finance/finance_dashboard.dart';
import 'package:petty_cash/screens/office_boy/office_boy_dashboard.dart';
import 'package:petty_cash/screens/super_admin/super_admin_dashboard.dart';

final dir = Directory('${Directory.current.path}/.dart_tool/fix_validation');
final staff = AppUser(
  uid: 'staff',
  name: 'Muhammad Abdullah Khan',
  email: 'abdullah@example.test',
  role: UserRole.officeBoy,
  createdAt: DateTime(2026),
  officeId: 'main',
);
final manager = AppUser(
  uid: 'manager',
  name: 'Sara Ahmed',
  email: 'sara@example.test',
  role: UserRole.superAdmin,
  createdAt: DateTime(2026),
);
final financeUser = AppUser(
  uid: 'finance',
  name: 'Finance Manager',
  email: 'finance@example.test',
  role: UserRole.finance,
  createdAt: DateTime(2026),
);
final rows = List.generate(
  6,
  (i) => ExpenseRequest(
    id: 'REQ-1234567$i',
    requestedBy: 'staff',
    requesterName: staff.name,
    requesterEmail: staff.email,
    itemDescription: 'Office stationery and printer service',
    amount: 12500.50 + i * 1000,
    reason: 'Paper and printer maintenance for the office.',
    billImageUrl: 'https://example.test/receipt.png',
    status: RequestStatus.values[i],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    paidAt: i >= 3 ? DateTime.now() : null,
    requestType: i >= 3 ? 'advance' : 'reimbursement',
    settlementAmount: i >= 4 ? 9000 : null,
    settlementMethod: i >= 4 ? 'Card' : null,
  ),
);

class A extends ChangeNotifier implements AuthProvider {
  AppUser user = manager;
  @override
  AppUser get currentUser => user;
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class E extends ChangeNotifier implements ExpenseProvider {
  @override
  List<ExpenseRequest> get allRequests => rows;
  @override
  List<ExpenseRequest> get filteredAllTransactions => rows;
  @override
  List<ExpenseRequest> getMyRequests(String uid) => rows;
  @override
  List<ExpenseRequest> get pendingRequests =>
      rows.where((r) => r.needsFinanceReview).toList();
  @override
  List<ExpenseRequest> get paymentHistory =>
      rows.where((r) => !r.isPending).toList();
  @override
  ExpenseRequest? findRequest(String id) =>
      rows.where((r) => r.id == id).firstOrNull;
  @override
  double get totalSpent => 29001;
  @override
  double get verifiedExpenses => 12000;
  @override
  double get returnedAmount => 2500;
  @override
  double get outstandingAdvances => 18000;
  @override
  double get pendingAmount => 12500.50;
  @override
  int get approvedCount => 2;
  @override
  int get pendingCount => 1;
  @override
  int get rejectedCount => 1;
  @override
  int get totalTransactionsCount => 4;
  @override
  double get approvalRate => 66.67;
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class U extends ChangeNotifier implements UserProvider {
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  List<AppUser> get allUsers => [staff, manager];
  @override
  List<AppUser> getManageableUsers(AppUser user) => allUsers;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class N extends ChangeNotifier implements NotificationProvider {
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  List<AppNotification> get notifications => [
    AppNotification(
      userId: 'manager',
      title: 'New Expense Request',
      message: 'A new request is awaiting review.',
    ),
  ];
  @override
  int get unreadCount => 1;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class LinkedNotifications extends ChangeNotifier
    implements NotificationProvider {
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  int get unreadCount => 1;
  @override
  List<AppNotification> get notifications => [
    AppNotification(
      id: 'linked-notification',
      userId: staff.uid,
      title: 'Advance sent',
      message: 'Finance marked your advance as sent.',
      relatedCoreAdvanceId: 'linked-advance',
    ),
  ];
  @override
  Future<bool> markAsRead(String id) async => true;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class P extends ChangeNotifier implements PaymentProvider {
  @override
  bool get isLoading => false;
  @override
  String? get error => null;
  @override
  bool isBusy(String id) => false;
  @override
  List<AdvanceRequestRecord> get advanceRequests => [];
  @override
  List<AdvanceBalance> get advanceBalances => [];
  @override
  List<Map<String, dynamic>> get ledger => [];
  @override
  DateTime? get reportFrom => null;
  @override
  DateTime? get reportTo => null;
  @override
  List<PaymentExpense> get expenses => [];
  @override
  List<AdvanceRecord> get advances => [
    AdvanceRecord(
      id: 'advance-test',
      officeBoyId: staff.uid,
      givenBy: manager.uid,
      financeMethod: 'Card',
      receivedMethod: 'Cash',
      status: 'Received',
      amount: 50000,
      mismatchFlag: true,
      createdAt: DateTime(2026, 9, 28),
      confirmedAt: DateTime(2026, 9, 28),
    ),
  ];
  @override
  List<PaymentActivity> get activity => [];
  @override
  List<FloatSummary> get overview => [
    FloatSummary(
      officeBoyId: staff.uid,
      officeBoyName: staff.name,
      totalReceived: 50000,
      totalSpent: 1000,
      onHold: 500,
      availableBalance: 48500,
      totalReimbursed: 0,
      advanceCount: 1,
      expenseCount: 1,
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async => '.',
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getAll':
              return <String, Object>{};
            case 'setString':
            case 'setBool':
            case 'setInt':
            case 'setDouble':
            case 'setStringList':
            case 'remove':
            case 'clear':
              return true;
            default:
              return null;
          }
        },
      );
  testWidgets('User cards show office, date, and edit action for admins', (
    tester,
  ) async {
    final language = LanguageProvider(initialLanguage: 'en', loadSaved: false);
    await language.ready;
    final auth = A();
    final users = U();
    final coreFlow = CoreFlowTestProvider()
      ..offices = const [OfficeRecord('main', 'Main Office')];

    for (final role in [UserRole.superAdmin, UserRole.admin]) {
      auth.user = manager.copyWith(role: role);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<UserProvider>.value(value: users),
            ChangeNotifierProvider<LanguageProvider>.value(value: language),
            ChangeNotifierProvider<CoreFlowProvider>.value(value: coreFlow),
          ],
          child: const MaterialApp(
            home: Scaffold(body: UserManagementScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Main Office'), findsWidgets);
      expect(find.text(language.date(staff.createdAt)), findsWidgets);
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
    }
  });
  testWidgets('All screens fit supported sizes and enlarged text', (t) async {
    await t.runAsync(() async {
      await dir.create(recursive: true);
      final inter = FontLoader('Inter')
        ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'));
      await inter.load();
      await (FontLoader(
        'NotoSansArabic',
      )..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf'))).load();
      await (FontLoader('JameelNooriNastaleeq')
            ..addFont(rootBundle.load('assets/fonts/JameelNooriNastaleeq.ttf')))
          .load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });

    final a = A(), e = E(), u = U(), n = N(), p = P();
    final key = GlobalKey();
    final results = <Map<String, dynamic>>[];
    final screens = <String, Widget Function()>{
      'login': () => const LoginScreen(),
      'language': () => LanguageSelectionScreen(onLanguageSelected: () {}),
      'override': () =>
          RequestOverrideDialog(request: rows.first, actor: manager),
      'reports': () => const MonthlyReportingScreen(),
      'analytics': () => const AnalyticsScreen(),
      'transactions': () => const AllTransactionsScreen(),
      'users': () => const UserManagementScreen(),
      'pending': () => const PendingRequestsScreen(),
      'history': () => const PaymentHistoryScreen(),
      'my_requests': () => const MyRequestsScreen(),
      'new_request': () => const NewRequestScreen(),
      'detail': () => RequestDetailScreen(request: rows.first),
      'settled_detail': () => RequestDetailScreen(request: rows.last),
      'settle_dialog': () => SettleAdvanceDialog(request: rows[3]),
      'update_settlement': () => SettleAdvanceDialog(request: rows[4]),
      'pending_settlement_detail': () => RequestDetailScreen(request: rows[4]),
      'notifications': () => const NotificationsPanel(),
      'reject': () => RejectionReasonDialog(
        requestTitle: rows.first.itemDescription,
        amount: rows.first.amount,
      ),
      'admin_dashboard': () => const AdminDashboard(),
      'finance_dashboard': () => const FinanceDashboard(),
      'finance_overview': () => FinanceOverviewScreen(
        onViewPendingTap: () {},
        onViewHistoryTap: () {},
        onViewPaymentsTap: () {},
      ),
      'office_dashboard': () => const OfficeBoyDashboard(),
      'super_dashboard': () => const SuperAdminDashboard(),
      'add_user': () => UserAccountDialog(actor: manager),
      'edit_user': () => UserAccountDialog(actor: manager, user: staff),
      'payment_center': () => const PaymentCenterScreen(),
      'payment_center_office': () => const PaymentCenterScreen(),
    };
    for (final locale in ['en', 'ur']) {
      final language = LanguageProvider(
        initialLanguage: locale,
        loadSaved: false,
      );
      await t.runAsync(() => language.ready);
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final theme = brightness == Brightness.dark
            ? AppTheme.darkTheme(locale)
            : AppTheme.forLanguage(locale);
        for (final size in [
          const Size(320, 568),
          const Size(360, 800),
          const Size(390, 844),
          const Size(768, 1024),
          const Size(1024, 768),
          const Size(1440, 900),
        ]) {
          if (brightness == Brightness.dark &&
              ![320.0, 360.0, 1024.0].contains(size.width)) {
            continue;
          }
          for (final scale in [
            1.0,
            if (size.width == 360 || size.width == 1024) 1.5,
          ]) {
            t.view.physicalSize = size;
            t.view.devicePixelRatio = 1;
            for (final entry in screens.entries) {
              a.user = entry.key == 'payment_center'
                  ? financeUser
                  : entry.key == 'new_request' ||
                        entry.key == 'my_requests' ||
                        entry.key == 'office_dashboard' ||
                        entry.key == 'payment_center_office'
                  ? staff
                  : manager;
              final errors = <String>[];
              final original = FlutterError.onError;
              FlutterError.onError = (d) {
                if (!d.toString().contains('HTTP request failed') &&
                    !d.toString().contains(
                      'Invalid argument(s): No host specified',
                    )) {
                  errors.add(d.toString());
                }
              };
              final name =
                  '${locale}_${brightness.name}_${entry.key}_${size.width.toInt()}_$scale';
              final child = entry.value();
              final englishTexts = <String>{};
              final standalone = [
                'login',
                'detail',
                'settled_detail',
                'settle_dialog',
                'reject',
                'override',
                'language',
                'notifications',
                'add_user',
                'edit_user',
                'admin_dashboard',
                'finance_dashboard',
                'office_dashboard',
                'super_dashboard',
              ].contains(entry.key);
              Widget home = standalone
                  ? ([
                          'login',
                          'detail',
                          'settled_detail',
                          'admin_dashboard',
                          'finance_dashboard',
                          'office_dashboard',
                          'super_dashboard',
                        ].contains(entry.key)
                        ? child
                        : Scaffold(
                            body: Align(
                              alignment: Alignment.bottomCenter,
                              child: child,
                            ),
                          ))
                  : Scaffold(
                      appBar: AppBar(title: const Text('Petty Cash')),
                      body: Row(
                        children: [
                          if (size.width >= 768)
                            SizedBox(width: size.width >= 1024 ? 201 : 73),
                          Expanded(child: child),
                        ],
                      ),
                      bottomNavigationBar: size.width < 768
                          ? const SizedBox(height: 80)
                          : null,
                    );
              await t.pumpWidget(
                MultiProvider(
                  providers: [
                    ChangeNotifierProvider<AuthProvider>.value(value: a),
                    ChangeNotifierProvider<ExpenseProvider>.value(value: e),
                    ChangeNotifierProvider<LanguageProvider>.value(
                      value: language,
                    ),
                    ChangeNotifierProvider<UserProvider>.value(value: u),
                    ChangeNotifierProvider<NotificationProvider>.value(
                      value: n,
                    ),
                    ChangeNotifierProvider<PaymentProvider>.value(value: p),
                    ChangeNotifierProvider<CoreFlowProvider>.value(
                      value: CoreFlowTestProvider()
                        ..offices = const [OfficeRecord('main', 'Main Office')],
                    ),
                  ],
                  child: RepaintBoundary(
                    key: key,
                    child: MaterialApp(
                      debugShowCheckedModeBanner: false,
                      theme: theme,
                      locale: Locale(locale),
                      supportedLocales: const [Locale('en'), Locale('ur')],
                      localizationsDelegates:
                          GlobalMaterialLocalizations.delegates,
                      builder: (c, w) => MediaQuery(
                        data: MediaQuery.of(c)
                            .copyWith(textScaler: TextScaler.linear(scale)),
                        child: w!,
                      ),
                      home: home,
                    ),
                  ),
                ),
              );
              await t.pump(const Duration(seconds: 1));
              if (entry.key == 'users') {
                expect(find.textContaining('Main Office'), findsWidgets);
              }
              if ([
                    'login',
                    'super_dashboard',
                    'office_dashboard',
                    'new_request',
                    'reports',
                    'detail',
                    'notifications',
                    'history',
                    'payment_center',
                    'payment_center_office',
                  ].contains(entry.key) &&
                  [360.0, 1024.0].contains(size.width)) {
                await t.runAsync(() async {
                  final b =
                      key.currentContext!.findRenderObject()
                          as RenderRepaintBoundary;
                  final img = await b.toImage();
                  final bytes = await img.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await File('${dir.path}/$name.png')
                      .writeAsBytes(bytes!.buffer.asUint8List());
                  img.dispose();
                });
              }
              if (entry.key == 'payment_center' && size.width == 320) {
                await t.tap(
                  find
                      .text(locale == 'ur' ? 'ایڈوانس دیں' : 'Give Advance')
                      .first,
                );
                await t.pumpAndSettle();
                await t.tap(
                  find.text(locale == 'ur' ? 'منسوخ' : 'Cancel').last,
                );
                await t.pumpAndSettle();
              }
              for (final s
                  in t
                      .stateList<ScrollableState>(find.byType(Scrollable))
                      .toList()) {
                if (s.position.axis != Axis.vertical) continue;
                for (
                  int i = 0;
                  i < 15 && s.position.pixels < s.position.maxScrollExtent;
                  i++
                ) {
                  s.position.jumpTo(
                    (s.position.pixels + size.height * .7).clamp(
                      0,
                      s.position.maxScrollExtent,
                    ),
                  );
                  await t.pump(const Duration(milliseconds: 200));
                }
              }
              if (locale == 'ur') {
                for (final text in t.widgetList<Text>(find.byType(Text))) {
                  final value = text.data ?? text.textSpan?.toPlainText() ?? '';
                  if (RegExp(r'[A-Za-z]{3}').hasMatch(value)) {
                    englishTexts.add(value);
                  }
                }
              }
              await t.pumpWidget(const SizedBox.shrink());
              await t.pump(const Duration(milliseconds: 400));
              FlutterError.onError = original;
              results.add({
                'case': name,
                'errors': errors.toSet().toList(),
                'englishTexts': englishTexts.toList(),
              });
            }
          }
        }
      }
      language.dispose();
    }
    await t.runAsync(
      () => File('${dir.path}/layout_results.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(results)),
    );
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    expect(results.length, screens.length * 26);
    final failures = results
        .where((r) => (r['errors'] as List).isNotEmpty)
        .toList();
    expect(
      failures,
      isEmpty,
      reason: const JsonEncoder.withIndent('  ').convert(failures),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('Urdu and English theme toggles keep key screens usable', (
    t,
  ) async {
    final auth = A();
    final expense = E();
    final users = U();
    final notifications = N();
    final payments = P();
    final core = CoreFlowTestProvider()
      ..offices = const [OfficeRecord('main', 'Main Office')];
    final language = LanguageProvider(initialLanguage: 'ur', loadSaved: false);
    final theme = ThemeProvider();
    await t.runAsync(() => language.ready);
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;

    final cases = <String, Widget Function()>{
      'login': () => const LoginScreen(),
      'language': () => LanguageSelectionScreen(onLanguageSelected: () {}),
      'office dashboard': () => const OfficeBoyDashboard(),
      'finance dashboard': () => const FinanceDashboard(),
      'admin dashboard': () => const AdminDashboard(),
      'super admin dashboard': () => const SuperAdminDashboard(),
      'finance overview': () => FinanceOverviewScreen(
        onViewPendingTap: () {},
        onViewHistoryTap: () {},
        onViewPaymentsTap: () {},
      ),
      'new request': () => const NewRequestScreen(),
      'my requests': () => const MyRequestsScreen(),
      'finance requests': () => const PendingRequestsScreen(),
      'payment history': () => const PaymentHistoryScreen(),
      'all transactions': () => const AllTransactionsScreen(),
      'reports': () => const MonthlyReportingScreen(),
      'analytics': () => const AnalyticsScreen(),
      'user management': () => const UserManagementScreen(),
      'create account': () => UserAccountDialog(actor: manager),
      'edit account': () => UserAccountDialog(actor: manager, user: staff),
      'request detail': () => RequestDetailScreen(request: rows.first),
      'settled detail': () => RequestDetailScreen(request: rows.last),
      'settlement form': () => SettleAdvanceDialog(request: rows[3]),
      'edit settlement': () => SettleAdvanceDialog(request: rows[4]),
      'pending settlement': () => RequestDetailScreen(request: rows[4]),
      'reject dialog': () => RejectionReasonDialog(
        requestTitle: rows.first.itemDescription,
        amount: rows.first.amount,
      ),
      'override dialog': () =>
          RequestOverrideDialog(request: rows.first, actor: manager),
      'notifications': () => const NotificationsPanel(),
      'payment center': () => const PaymentCenterScreen(),
      'office payment center': () => const PaymentCenterScreen(),
    };
    final errors = <String>[];
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.toString();
      if (!message.contains('HTTP request failed') &&
          !message.contains('Invalid argument(s): No host specified')) {
        errors.add(message);
      }
    };
    try {
      for (final locale in ['ur', 'en']) {
        await t.runAsync(() => language.setLanguage(locale));
        for (final entry in cases.entries) {
          auth.user =
              entry.key == 'office dashboard' ||
                  entry.key == 'new request' ||
                  entry.key == 'my requests' ||
                  entry.key == 'office payment center'
              ? staff
              : entry.key == 'finance dashboard' ||
                    entry.key == 'finance requests' ||
                    entry.key == 'payment center'
              ? financeUser
              : manager;
          await t.runAsync(() => theme.setThemeMode(ThemeMode.light));
          final child = entry.value();
          final home =
              [
                'login',
                'office dashboard',
                'finance dashboard',
                'admin dashboard',
                'super admin dashboard',
                'request detail',
                'settled detail',
                'pending settlement',
              ].contains(entry.key)
              ? child
              : Scaffold(body: child);
          await t.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(value: auth),
                ChangeNotifierProvider<ExpenseProvider>.value(value: expense),
                ChangeNotifierProvider<UserProvider>.value(value: users),
                ChangeNotifierProvider<NotificationProvider>.value(
                  value: notifications,
                ),
                ChangeNotifierProvider<PaymentProvider>.value(value: payments),
                ChangeNotifierProvider<CoreFlowProvider>.value(value: core),
                ChangeNotifierProvider<LanguageProvider>.value(value: language),
                ChangeNotifierProvider<ThemeProvider>.value(value: theme),
              ],
              child: Consumer2<LanguageProvider, ThemeProvider>(
                builder: (context, currentLanguage, currentTheme, _) =>
                    MaterialApp(
                      theme: AppTheme.forLanguage(
                        currentLanguage.currentLanguage,
                      ),
                      darkTheme: AppTheme.darkTheme(
                        currentLanguage.currentLanguage,
                      ),
                      themeMode: currentTheme.themeMode,
                      locale: currentLanguage.locale,
                      supportedLocales: const [Locale('en'), Locale('ur')],
                      localizationsDelegates:
                          GlobalMaterialLocalizations.delegates,
                      builder: (context, child) => Directionality(
                        textDirection: currentLanguage.isRtl
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        child: child!,
                      ),
                      home: home,
                    ),
              ),
            ),
          );
          await t.pump(const Duration(milliseconds: 400));
          for (final mode in [ThemeMode.dark, ThemeMode.light]) {
            await t.runAsync(() => theme.setThemeMode(mode));
            await t.pump(const Duration(milliseconds: 400));
            expect(errors, isEmpty, reason: '$locale ${entry.key} after $mode');
          }
          await t.pumpWidget(const SizedBox.shrink());
        }
      }
    } finally {
      FlutterError.onError = original;
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('Linked Urdu notification opens its detail page safely', (
    tester,
  ) async {
    final language = LanguageProvider(initialLanguage: 'ur', loadSaved: false);
    await language.ready;
    final flow = CoreFlowTestProvider()
      ..offices = const [OfficeRecord('main', 'Main Office')]
      ..advances = [
        CoreAdvance(
          id: 'linked-advance',
          officeBoyId: staff.uid,
          officeId: 'main',
          purpose: 'Printer paper',
          method: 'cash',
          status: 'awaiting_office_boy_approval',
          amount: 5000,
          createdAt: DateTime.utc(2026),
        ),
      ];
    final auth = A()..user = staff;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<UserProvider>.value(value: U()),
          ChangeNotifierProvider<CoreFlowProvider>.value(value: flow),
          ChangeNotifierProvider<NotificationProvider>.value(
            value: LinkedNotifications(),
          ),
          ChangeNotifierProvider<LanguageProvider>.value(value: language),
        ],
        child: MaterialApp(
          theme: AppTheme.forLanguage('ur'),
          locale: const Locale('ur'),
          supportedLocales: const [Locale('en'), Locale('ur')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const NotificationsPanel(),
                ),
                child: const Text('Open notifications'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ایڈوانس کی رقم دے دی گئی'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(CoreAdvanceCard), findsOneWidget);
    expect(find.text('تفصیل'), findsOneWidget);
    await tester.tap(find.text('منظور کریں').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(flow.advances.single.status, 'cleared');
  });
}
