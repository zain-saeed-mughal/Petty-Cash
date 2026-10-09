import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petty_cash/main.dart';
import 'package:petty_cash/models/payment_models.dart';
import 'package:petty_cash/models/user_model.dart';
import 'package:petty_cash/providers/auth_provider.dart';
import 'package:petty_cash/providers/expense_provider.dart';
import 'package:petty_cash/providers/language_provider.dart';
import 'package:petty_cash/providers/payment_provider.dart';
import 'package:petty_cash/providers/user_provider.dart';
import 'package:petty_cash/providers/core_flow_provider.dart';
import 'package:petty_cash/providers/notification_provider.dart';

import 'core_flow_test_provider.dart';

import 'package:petty_cash/screens/payments/payment_center_screen.dart';
import 'package:petty_cash/screens/office_boy/new_request_screen.dart';
import 'package:petty_cash/screens/office_boy/office_boy_dashboard.dart';
import 'package:petty_cash/screens/reports/monthly_reporting_screen.dart';
import 'package:petty_cash/widgets/submit_payment_expense_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FinanceAuth extends ChangeNotifier implements AuthProvider {
  @override
  AppUser? get currentUser => AppUser(
    uid: 'finance',
    name: 'Finance',
    email: 'finance@example.test',
    role: UserRole.finance,
    createdAt: DateTime.utc(2026),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OfficeAuth extends ChangeNotifier implements AuthProvider {
  @override
  AppUser? get currentUser => AppUser(
    uid: 'office-boy',
    name: 'Office Boy',
    email: 'office@example.test',
    role: UserRole.officeBoy,
    createdAt: DateTime.utc(2026),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestNotifications extends ChangeNotifier
    implements NotificationProvider {
  @override
  int get unreadCount => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PaymentUsers extends ChangeNotifier implements UserProvider {
  @override
  List<AppUser> get allUsers => [
    AppUser(
      uid: 'office-boy',
      name: 'Office Boy',
      email: 'office@example.test',
      role: UserRole.officeBoy,
      createdAt: DateTime.utc(2026),
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PaymentActions extends ChangeNotifier implements PaymentProvider {
  String? givenTo;
  double? givenAmount;
  String? givenMethod;
  String? reviewedId;
  String? reviewDecision;
  String? reviewReason;
  double? requestedAmount;
  String? requestedPurpose;
  String? reviewedAdvanceId;
  String? advanceDecision;
  String? advanceMethod;
  List<PaymentExpense> testExpenses = const [];
  List<AdvanceRequestRecord> testRequests = const [];
  List<AdvanceRecord> testAdvances = const [];

  @override
  bool get isLoading => false;
  @override
  String? get error => null;
  @override
  List<AdvanceRecord> get advances => testAdvances;
  @override
  List<AdvanceRequestRecord> get advanceRequests => testRequests;
  @override
  List<AdvanceBalance> get advanceBalances => const [];
  @override
  List<Map<String, dynamic>> get ledger => const [];
  @override
  DateTime? get reportFrom => null;
  @override
  DateTime? get reportTo => null;
  @override
  List<PaymentExpense> get expenses => testExpenses;
  @override
  List<PaymentActivity> get activity => const [];
  @override
  List<FloatSummary> get overview => const [];
  @override
  bool isBusy(String id) => false;
  @override
  void refresh() {}

  @override
  Future<bool> requestAdvance({
    String? id,
    required double amount,
    required String purpose,
  }) async {
    requestedAmount = amount;
    requestedPurpose = purpose;
    return true;
  }

  @override
  Future<bool> reviewAdvanceRequest(
    String id,
    String decision, {
    String? method,
    String? reason,
  }) async {
    reviewedAdvanceId = id;
    advanceDecision = decision;
    advanceMethod = method;
    return true;
  }

  @override
  Future<bool> giveAdvance({
    String? id,
    required String officeBoyId,
    required double amount,
    required String method,
    String? note,
  }) async {
    givenTo = officeBoyId;
    givenAmount = amount;
    givenMethod = method;
    return true;
  }

  @override
  Future<bool> reviewExpense(
    String id,
    String decision, {
    String? reason,
  }) async {
    reviewedId = id;
    reviewDecision = decision;
    reviewReason = reason;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const AppProviders(child: PettyCashApp(initializeServices: false)),
    );
    expect(find.byType(PettyCashApp), findsOneWidget);
  });

  testWidgets('Selecting Urdu updates app locale and RTL direction', (
    WidgetTester tester,
  ) async {
    final languageProvider = LanguageProvider();
    await languageProvider.setLanguage('ur');

    expect(languageProvider.currentLanguage, 'ur');
    expect(languageProvider.isRtl, isTrue);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: languageProvider,
        child: Builder(
          builder: (context) {
            final lang = context.watch<LanguageProvider>();
            return MaterialApp(
              locale: lang.locale,
              home: Directionality(
                textDirection: lang.isRtl
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: const Scaffold(body: SizedBox()),
              ),
            );
          },
        ),
      ),
    );

    final materialApps = tester.widgetList<MaterialApp>(
      find.byType(MaterialApp),
    );
    final directionalityWidgets = tester.widgetList<Directionality>(
      find.byType(Directionality),
    );

    expect(materialApps, isNotEmpty);
    expect(directionalityWidgets, isNotEmpty);
    expect(materialApps.last.locale?.languageCode, 'ur');
    expect(directionalityWidgets.last.textDirection, TextDirection.rtl);
  });

  testWidgets('Finance can give an advance without a dialog lifecycle error', (
    WidgetTester tester,
  ) async {
    final auth = _FinanceAuth();
    final users = _PaymentUsers();
    final payments = _PaymentActions();
    final language = LanguageProvider(initialLanguage: 'en', loadSaved: false);
    await language.ready;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<UserProvider>.value(value: users),
          ChangeNotifierProvider<PaymentProvider>.value(value: payments),
          ChangeNotifierProvider<LanguageProvider>.value(value: language),
        ],
        child: const MaterialApp(home: Scaffold(body: PaymentCenterScreen())),
      ),
    );

    await tester.tap(find.text('Give Advance').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '50000');
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Card').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Give Advance'),
          )
          .last,
    );
    await tester.pumpAndSettle();

    expect(payments.givenTo, 'office-boy');
    expect(payments.givenAmount, 50000);
    expect(payments.givenMethod, 'Card');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Finance approval sends the RPC decision token', (
    WidgetTester tester,
  ) async {
    final payments = _PaymentActions()..testExpenses = [_pendingExpense()];
    final language = LanguageProvider(initialLanguage: 'en', loadSaved: false);
    await language.ready;
    await tester.pumpWidget(_financePaymentScreen(payments, language));

    await tester.ensureVisible(find.text('Approve').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve').first);
    await tester.pumpAndSettle();

    expect(payments.reviewedId, 'expense-test');
    expect(payments.reviewDecision, 'Approve');
  });

  testWidgets('Finance rejection requires and records a reason', (
    WidgetTester tester,
  ) async {
    final payments = _PaymentActions()..testExpenses = [_pendingExpense()];
    final language = LanguageProvider(initialLanguage: 'en', loadSaved: false);
    await language.ready;
    await tester.pumpWidget(_financePaymentScreen(payments, language));

    await tester.ensureVisible(find.text('Reject').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Incorrect amount');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog).last,
        matching: find.text('Reject'),
      ),
    );
    await tester.pumpAndSettle();

    expect(payments.reviewedId, 'expense-test');
    expect(payments.reviewDecision, 'Reject');
    expect(payments.reviewReason, 'Incorrect amount');
  });

  testWidgets('Office Boy can request an advance with a purpose', (
    tester,
  ) async {
    final payments = _PaymentActions();
    final language = LanguageProvider(initialLanguage: 'en', loadSaved: false);
    await language.ready;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: _OfficeAuth()),
          ChangeNotifierProvider<PaymentProvider>.value(value: payments),
          ChangeNotifierProvider<LanguageProvider>.value(value: language),
        ],
        child: const MaterialApp(home: Scaffold(body: NewRequestScreen())),
      ),
    );
    await tester.tap(find.text('Request advance'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '5000');
    await tester.enterText(
      find.byType(TextFormField).last,
      'Buy office supplies',
    );
    await tester.tap(find.text('Send to Finance'));
    await tester.pumpAndSettle();
    expect(payments.requestedAmount, 5000);
    expect(payments.requestedPurpose, 'Buy office supplies');
  });

  testWidgets('Finance chooses a method when approving an advance request', (
    tester,
  ) async {
    final payments = _PaymentActions()
      ..testRequests = [
        AdvanceRequestRecord(
          id: 'request-test',
          officeBoyId: 'office-boy',
          purpose: 'Office supplies',
          status: 'Pending',
          amount: 5000,
          createdAt: DateTime.utc(2026),
        ),
      ];
    final language = LanguageProvider(initialLanguage: 'en', loadSaved: false);
    await language.ready;
    await tester.pumpWidget(_financePaymentScreen(payments, language));
    await tester.ensureVisible(find.text('Approve').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Card').last);
    await tester.pumpAndSettle();
    expect(payments.reviewedAdvanceId, 'request-test');
    expect(payments.advanceDecision, 'Approve');
    expect(payments.advanceMethod, 'Card');
  });

  testWidgets('Office Boy sees receipt and rejection actions before history', (
    tester,
  ) async {
    final payments = _PaymentActions()
      ..testAdvances = [
        AdvanceRecord(
          id: 'advance-test',
          officeBoyId: 'office-boy',
          givenBy: 'finance',
          financeMethod: 'Cash',
          status: 'Awaiting Confirmation',
          amount: 5000,
          mismatchFlag: false,
          createdAt: DateTime.utc(2026),
        ),
      ]
      ..testExpenses = [
        PaymentExpense(
          id: 'rejected-expense',
          officeBoyId: 'office-boy',
          flowType: 'float',
          itemDescription: 'Printer paper',
          reason: 'Office stationery',
          status: 'Rejected',
          amount: 750,
          mismatchFlag: false,
          rejectionReason: 'Please correct the bill',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ];
    final language = LanguageProvider(initialLanguage: 'en', loadSaved: false);
    await language.ready;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: _OfficeAuth()),
          ChangeNotifierProvider<UserProvider>.value(value: _PaymentUsers()),
          ChangeNotifierProvider<PaymentProvider>.value(value: payments),
          ChangeNotifierProvider<LanguageProvider>.value(value: language),
        ],
        child: const MaterialApp(home: Scaffold(body: PaymentCenterScreen())),
      ),
    );

    expect(find.text('Your next steps'), findsOneWidget);
    expect(find.text('Confirm Advance Received'), findsWidgets);
    expect(find.text('Acknowledge Rejection'), findsWidgets);
  });

  testWidgets('Monthly report includes new payment activity', (tester) async {
    final payments = _PaymentActions()
      ..testAdvances = [
        AdvanceRecord(
          id: 'monthly-advance',
          officeBoyId: 'office-boy',
          givenBy: 'finance',
          financeMethod: 'Cash',
          status: 'Awaiting Confirmation',
          amount: 4200,
          mismatchFlag: false,
          note: 'Month report advance',
          createdAt: DateTime.now(),
        ),
      ];
    final language = LanguageProvider(initialLanguage: 'en', loadSaved: false);
    await language.ready;
    final expense = ExpenseProvider(requests: () => const Stream.empty());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ExpenseProvider>.value(value: expense),
          ChangeNotifierProvider<PaymentProvider>.value(value: payments),
          ChangeNotifierProvider<UserProvider>.value(value: _PaymentUsers()),
          ChangeNotifierProvider<LanguageProvider>.value(value: language),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MonthlyReportingScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Advance & expense activity'), findsOneWidget);
    expect(find.text('Month report advance'), findsOneWidget);
  });

  testWidgets('Receipt source labels stay on one line on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final language = LanguageProvider(initialLanguage: 'en', loadSaved: false);
    await language.ready;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: _FinanceAuth()),
          ChangeNotifierProvider<PaymentProvider>.value(
            value: _PaymentActions(),
          ),
          ChangeNotifierProvider<LanguageProvider>.value(value: language),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const SubmitPaymentExpenseDialog(),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.text('Camera')).maxLines, 1);
    expect(tester.widget<Text>(find.text('Gallery')).maxLines, 1);
    expect(
      tester.getTopLeft(find.text('Gallery')).dy,
      greaterThan(tester.getTopLeft(find.text('Camera')).dy),
    );
  });

  testWidgets('Office Boy home has two clear money choices', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final language = LanguageProvider(initialLanguage: 'en', loadSaved: false);
    await language.ready;
    final expense = ExpenseProvider(requests: () => const Stream.empty());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: _OfficeAuth()),
          ChangeNotifierProvider<ExpenseProvider>.value(value: expense),
          ChangeNotifierProvider<PaymentProvider>.value(
            value: _PaymentActions(),
          ),
          ChangeNotifierProvider<UserProvider>.value(value: _PaymentUsers()),
          ChangeNotifierProvider<CoreFlowProvider>.value(
            value: CoreFlowTestProvider(),
          ),
          ChangeNotifierProvider<NotificationProvider>.value(
            value: _TestNotifications(),
          ),
          ChangeNotifierProvider<LanguageProvider>.value(value: language),
        ],
        child: const MaterialApp(home: OfficeBoyDashboard()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Request Advance'), findsOneWidget);
    expect(find.text('Reimbursement'), findsOneWidget);
  });
}

PaymentExpense _pendingExpense() => PaymentExpense(
  id: 'expense-test',
  officeBoyId: 'office-boy',
  flowType: 'float',
  itemDescription: 'Printer paper',
  reason: 'Office stationery',
  status: 'Pending',
  amount: 750,
  mismatchFlag: false,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Widget _financePaymentScreen(
  _PaymentActions payments,
  LanguageProvider language,
) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AuthProvider>.value(value: _FinanceAuth()),
    ChangeNotifierProvider<UserProvider>.value(value: _PaymentUsers()),
    ChangeNotifierProvider<PaymentProvider>.value(value: payments),
    ChangeNotifierProvider<LanguageProvider>.value(value: language),
  ],
  child: const MaterialApp(home: Scaffold(body: PaymentCenterScreen())),
);
