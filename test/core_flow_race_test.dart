import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petty_cash/models/core_flow_models.dart';
import 'package:petty_cash/models/user_model.dart';
import 'package:petty_cash/providers/core_flow_provider.dart';
import 'package:petty_cash/providers/language_provider.dart';
import 'package:petty_cash/screens/core/core_dashboard_screens.dart';
import 'package:petty_cash/services/database_service.dart';
import 'package:provider/provider.dart';

class DelayedDatabase implements DatabaseService {
  final offices = StreamController<List<OfficeRecord>>.broadcast();
  final advances = StreamController<List<CoreAdvance>>.broadcast();
  final items = StreamController<List<CoreAdvanceItem>>.broadcast();
  final repayments = StreamController<List<CoreReimbursement>>.broadcast();
  final activity = StreamController<List<CoreActivity>>.broadcast();
  final balanceCalls = <Completer<List<CoreBalance>>>[];
  final officeCalls = <Completer<OfficeRecord>>[];
  final officeDeleteCalls = <Completer<void>>[];
  final advanceCalls = <Completer<CoreAdvance>>[];
  @override
  Stream<List<OfficeRecord>> streamOffices() => offices.stream;
  @override
  Stream<List<CoreAdvance>> streamCoreAdvances() => advances.stream;
  @override
  Stream<List<CoreAdvanceItem>> streamCoreAdvanceItems() => items.stream;
  @override
  Stream<List<CoreReimbursement>> streamCoreReimbursements() =>
      repayments.stream;
  @override
  Stream<List<CoreActivity>> streamCoreActivity() => activity.stream;
  @override
  Future<List<CoreBalance>> getCoreBalances() {
    final request = Completer<List<CoreBalance>>();
    balanceCalls.add(request);
    return request.future;
  }

  @override
  Future<OfficeRecord> createOffice(String name) {
    final request = Completer<OfficeRecord>();
    officeCalls.add(request);
    return request.future;
  }

  @override
  Future<void> deleteOffice(String id) {
    final request = Completer<void>();
    officeDeleteCalls.add(request);
    return request.future;
  }

  @override
  Future<CoreAdvance> requestCoreAdvance({
    required String id,
    required String purpose,
    required double amount,
    required String method,
    String? accountName,
    String? accountDetails,
  }) {
    final request = Completer<CoreAdvance>();
    advanceCalls.add(request);
    return request.future;
  }

  void emitFeeds() {
    offices.add([const OfficeRecord('main', 'Main Office')]);
    advances.add([]);
    items.add([]);
    repayments.add([]);
    activity.add([]);
  }

  Future<void> close() async {
    await Future.wait([
      offices.close(),
      advances.close(),
      items.close(),
      repayments.close(),
      activity.close(),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppUser user(String id) => AppUser(
  uid: id,
  name: id,
  email: '$id@example.test',
  role: UserRole.officeBoy,
  createdAt: DateTime(2026),
);
CoreBalance balance(double remaining) => CoreBalance(
  advanceId: 'advance',
  officeBoyId: 'b',
  officeId: 'main',
  total: 100,
  spent: 100 - remaining,
  remaining: remaining,
  itemCount: 1,
);
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late DelayedDatabase db;
  late CoreFlowProvider flow;
  setUp(() {
    db = DelayedDatabase();
    flow = CoreFlowProvider(database: db)..updateUser(user('a'));
  });
  tearDown(() async {
    flow.dispose();
    await db.close();
  });

  test(
    'old action cannot populate new account or clear its active operation',
    () async {
      final old = flow.createOffice('Old office');
      flow.updateUser(null);
      flow.updateUser(user('b'));
      final current = flow.createOffice('New office');
      expect(db.officeCalls.length, 2);
      db.officeCalls[0].complete(const OfficeRecord('old', 'Old office'));
      expect(await old, isFalse);
      expect(flow.offices, isEmpty);
      expect(flow.isBusy('create-office'), isTrue);
      db.officeCalls[1].complete(const OfficeRecord('new', 'New office'));
      expect(await current, isTrue);
      expect(flow.offices.single.id, 'new');
      expect(flow.isBusy('create-office'), isFalse);
    },
  );

  test('late advance response cannot enter a different account', () async {
    final old = flow.requestAdvance(
      purpose: 'Old user',
      amount: 1,
      method: 'cash',
    );
    flow.updateUser(user('b'));
    db.advanceCalls.single.complete(
      CoreAdvance(
        id: 'old',
        officeBoyId: 'a',
        officeId: 'main',
        purpose: 'Old user',
        method: 'cash',
        status: 'pending',
        amount: 1,
        createdAt: DateTime(2026),
      ),
    );
    expect(await old, isFalse);
    expect(flow.advances, isEmpty);
  });

  test('stale action error does not affect a new session', () async {
    final old = flow.createOffice('Old');
    flow.updateUser(user('b'));
    db.officeCalls.single.completeError(StateError('old account error'));
    expect(await old, isFalse);
    expect(flow.error, isNull);
  });

  test(
    'refresh invalidates old action commits even for the same account',
    () async {
      final old = flow.createOffice('Old');
      flow.refresh();
      db.officeCalls.single.complete(const OfficeRecord('old', 'Old'));
      expect(await old, isFalse);
      expect(flow.offices, isEmpty);
    },
  );

  test(
    'latest balance response wins when requests finish in reverse order',
    () async {
      db.advances.add([]);
      await flush();
      expect(db.balanceCalls.length, 2);
      db.balanceCalls[1].complete([balance(80)]);
      await flush();
      db.balanceCalls[0].complete([balance(20)]);
      await flush();
      expect(flow.balanceForAdvance('advance')!.remaining, 80);
      expect(flow.isBalanceLoading, isFalse);
    },
  );

  test('older balance failure cannot erase a newer success', () async {
    db.items.add([]);
    await flush();
    db.balanceCalls[1].complete([balance(80)]);
    await flush();
    db.balanceCalls[0].completeError(StateError('old failure'));
    await flush();
    expect(flow.loadError, isNull);
    expect(flow.balances.single.remaining, 80);
  });

  test('old success cannot hide latest balance failure', () async {
    db.items.add([]);
    await flush();
    db.balanceCalls[1].completeError(StateError('latest failure'));
    await flush();
    db.balanceCalls[0].complete([balance(20)]);
    await flush();
    expect(flow.loadError, isNotNull);
    expect(flow.balances, isEmpty);
  });

  test('old account balance cannot populate current account', () async {
    flow.updateUser(user('b'));
    db.balanceCalls[1].complete([balance(80)]);
    await flush();
    db.balanceCalls[0].complete([balance(20)]);
    await flush();
    expect(flow.balances.single.remaining, 80);
  });

  test('action validation errors do not become data loading errors', () async {
    final action = flow.createOffice('');
    db.officeCalls.single.completeError(StateError('invalid name'));
    expect(await action, isFalse);
    expect(flow.error, isNotNull);
    expect(flow.loadError, isNull);
  });

  test(
    'office remains visible until deletion succeeds and on failure',
    () async {
      flow.offices = [const OfficeRecord('unused', 'Unused')];
      final failed = flow.deleteOffice('unused');
      expect(flow.offices, hasLength(1));
      db.officeDeleteCalls[0].completeError(StateError('Office has history'));
      expect(await failed, isFalse);
      expect(flow.offices, hasLength(1));

      final succeeded = flow.deleteOffice('unused');
      db.officeDeleteCalls[1].complete();
      expect(await succeeded, isTrue);
      expect(flow.offices, isEmpty);
    },
  );

  testWidgets(
    'partial feed failure hides incomplete totals and retry recovers',
    (tester) async {
      final db = DelayedDatabase();
      final flow = CoreFlowProvider(database: db)..updateUser(user('a'));
      final language = LanguageProvider(loadSaved: false);
      await language.ready;
      db.emitFeeds();
      await tester.pump();
      db.balanceCalls.last.complete([balance(80)]);
      await tester.pump();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CoreFlowProvider>.value(value: flow),
            ChangeNotifierProvider<LanguageProvider>.value(value: language),
          ],
          child: const MaterialApp(
            home: Scaffold(body: CoreDataGate(child: Text('Complete totals'))),
          ),
        ),
      );
      expect(find.text('Complete totals'), findsOneWidget);
      db.items.addError(StateError('purchase feed unavailable'));
      await tester.pump();
      expect(flow.offices, isNotEmpty);
      expect(find.text('Complete totals'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      db.emitFeeds();
      await tester.pump();
      db.balanceCalls.last.complete([balance(80)]);
      await tester.pump();
      expect(find.text('Complete totals'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      language.dispose();
      flow.dispose();
      await db.close();
    },
  );

  test('disposed provider ignores late success without notifying', () async {
    final other = CoreFlowProvider(database: db)..updateUser(user('b'));
    final action = other.createOffice('Late');
    var notifications = 0;
    other.addListener(() => notifications++);
    other.dispose();
    db.officeCalls.single.complete(const OfficeRecord('late', 'Late'));
    expect(await action, isFalse);
    expect(other.offices, isEmpty);
    expect(notifications, 0);
  });
}
