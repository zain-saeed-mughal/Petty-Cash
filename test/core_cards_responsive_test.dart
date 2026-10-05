import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petty_cash/models/core_flow_models.dart';
import 'package:petty_cash/models/user_model.dart';
import 'package:petty_cash/providers/auth_provider.dart';
import 'package:petty_cash/providers/core_flow_provider.dart';
import 'package:petty_cash/providers/language_provider.dart';
import 'package:petty_cash/providers/user_provider.dart';
import 'package:petty_cash/screens/core/core_dashboard_screens.dart';
import 'package:provider/provider.dart';

import 'core_flow_test_provider.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  AppUser get currentUser => AppUser(
    uid: 'staff',
    name: 'Zain Saeed Mughal',
    email: 'zain@example.test',
    role: UserRole.officeBoy,
    createdAt: DateTime.utc(2026),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Users extends ChangeNotifier implements UserProvider {
  @override
  List<AppUser> get allUsers => [
    AppUser(
      uid: 'staff',
      name: 'Zain Saeed Mughal',
      email: 'zain@example.test',
      role: UserRole.officeBoy,
      createdAt: DateTime.utc(2026),
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Monthly records counts only approved advance expenses', (
    tester,
  ) async {
    final now = DateTime.now();
    final flow = CoreFlowTestProvider()
      ..offices = const [OfficeRecord('main', 'Main Office')]
      ..advances = [
        CoreAdvance(
          id: 'advance',
          officeBoyId: 'staff',
          officeId: 'main',
          purpose: 'Office supplies',
          method: 'cash',
          status: 'cleared',
          amount: 5000,
          createdAt: now,
          clearedAt: now,
        ),
      ]
      ..items = [
        CoreAdvanceItem(
          id: 'approved',
          advanceId: 'advance',
          officeBoyId: 'staff',
          officeId: 'main',
          description: 'Approved purchase',
          amount: 200,
          createdAt: now,
          status: 'approved',
        ),
        CoreAdvanceItem(
          id: 'pending',
          advanceId: 'advance',
          officeBoyId: 'staff',
          officeId: 'main',
          description: 'Waiting for approval',
          amount: 300,
          createdAt: now,
          status: 'pending',
        ),
        CoreAdvanceItem(
          id: 'rejected',
          advanceId: 'advance',
          officeBoyId: 'staff',
          officeId: 'main',
          description: 'Rejected purchase',
          amount: 400,
          createdAt: now,
          status: 'rejected',
        ),
      ];
    final language = LanguageProvider(initialLanguage: 'en', loadSaved: false);
    await language.ready;
    tester.view.physicalSize = const Size(320, 150);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: _Auth()),
          ChangeNotifierProvider<UserProvider>.value(value: _Users()),
          ChangeNotifierProvider<CoreFlowProvider>.value(value: flow),
          ChangeNotifierProvider<LanguageProvider>.value(value: language),
        ],
        child: const MaterialApp(home: Scaffold(body: CoreMonthlyRecords())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rs. 200.00'), findsOneWidget);
    expect(find.text('Rs. 900.00'), findsNothing);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Monthly records filters fit phone and tablet widths', (
    tester,
  ) async {
    final now = DateTime.now();
    final flow = CoreFlowTestProvider()
      ..offices = const [OfficeRecord('main', 'Main Office')]
      ..advances = List.generate(
        20,
        (index) => CoreAdvance(
          id: 'advance-$index',
          officeBoyId: 'staff',
          officeId: 'main',
          purpose: 'Office supplies $index',
          method: 'cash',
          status: 'pending',
          amount: 1000,
          createdAt: now,
        ),
      )
      ..reimbursements = [
        CoreReimbursement(
          id: 'repayment',
          officeBoyId: 'staff',
          officeId: 'main',
          description: 'Bought printer paper',
          wantedMethod: 'cash',
          status: 'pending',
          amount: 500,
          createdAt: now,
        ),
      ];
    for (final width in [320.0, 768.0]) {
      for (final locale in ['en', 'ur']) {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        final language = LanguageProvider(
          initialLanguage: locale,
          loadSaved: false,
        );
        await language.ready;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: _Auth()),
              ChangeNotifierProvider<UserProvider>.value(value: _Users()),
              ChangeNotifierProvider<CoreFlowProvider>.value(value: flow),
              ChangeNotifierProvider<LanguageProvider>.value(value: language),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 700),
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: Directionality(
                  textDirection: locale == 'ur'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: const Scaffold(body: CoreMonthlyRecords()),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$locale at $width px');
        expect(find.byType(CoreMonthlyRecords), findsOneWidget);
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets(
    'Advance and repayment cards fit narrow English and Urdu screens',
    (tester) async {
      final flow = CoreFlowTestProvider()
        ..offices = const [OfficeRecord('main', 'Main Office')]
        ..advances = [
          CoreAdvance(
            id: 'advance',
            officeBoyId: 'staff',
            officeId: 'main',
            purpose: 'Printer paper and office stationery for the whole team',
            method: 'card',
            status: 'cleared',
            amount: 50000,
            createdAt: DateTime.utc(2026),
            accountName: 'Zain Saeed Mughal',
            accountDetails: 'PK12 1234567890',
          ),
        ]
        ..balances = const [
          CoreBalance(
            advanceId: 'advance',
            officeBoyId: 'staff',
            officeId: 'main',
            total: 50000,
            spent: 20000,
            remaining: 30000,
            itemCount: 1,
          ),
        ]
        ..reimbursements = [
          CoreReimbursement(
            id: 'repayment',
            officeBoyId: 'staff',
            officeId: 'main',
            description: 'Long description of tools bought with my own money',
            wantedMethod: 'card',
            status: 'rejected',
            amount: 12500,
            createdAt: DateTime.utc(2026),
            rejectionReason: 'Bill is unclear',
          ),
        ];
      for (final width in [320.0, 390.0, 768.0]) {
        for (final locale in ['en', 'ur']) {
          tester.view.physicalSize = Size(width, 700);
          tester.view.devicePixelRatio = 1;
          final language = LanguageProvider(
            initialLanguage: locale,
            loadSaved: false,
          );
          await language.ready;
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(value: _Auth()),
                ChangeNotifierProvider<UserProvider>.value(value: _Users()),
                ChangeNotifierProvider<CoreFlowProvider>.value(value: flow),
                ChangeNotifierProvider<LanguageProvider>.value(value: language),
              ],
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 700),
                    textScaler: const TextScaler.linear(1.3),
                  ),
                  child: Directionality(
                    textDirection: locale == 'ur'
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: Scaffold(
                      body: ListView(
                        children: [
                          CoreAdvanceCard(advance: flow.advances.first),
                          CoreReimbursementCard(
                            request: flow.reimbursements.first,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$locale at $width px',
          );
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
