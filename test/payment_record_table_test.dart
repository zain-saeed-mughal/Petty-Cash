import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petty_cash/widgets/payment_record_table.dart';

void main() {
  testWidgets('Records remain usable as tables on a narrow Urdu screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                child: PaymentRecordTable<String>(
                  tableId: 'test-history',
                  records: const ['کاغذ', 'قلم'],
                  columns: [
                    PaymentRecordColumn(
                      label: 'سامان',
                      cell: (_, row) => Text(row),
                    ),
                    PaymentRecordColumn(
                      label: 'حالت',
                      cell: (_, row) =>
                          Text(row == 'کاغذ' ? 'منظور شدہ' : 'زیرِ جائزہ'),
                    ),
                  ],
                  idOf: (row) => row,
                  searchOf: (row) => row,
                  statusOf: (row) => row == 'کاغذ' ? 'Approved' : 'Pending',
                  statusLabel: (status) =>
                      status == 'Approved' ? 'منظور شدہ' : 'زیرِ جائزہ',
                  details: (_, row) => Text('تفصیل: $row'),
                  searchHint: 'تلاش کریں',
                  statusHint: 'حالت',
                  allStatusesLabel: 'تمام حالتیں',
                  recordsLabel: 'ریکارڈ',
                  noMatchesLabel: 'کوئی ریکارڈ نہیں ملا',
                  detailsLabel: 'تفصیل دیکھیں',
                  showMoreLabel: 'مزید دیکھیں',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(PaymentRecordTable<String>), findsOneWidget);
    expect(tester.getSize(find.byType(Scaffold)).width, lessThan(760));
    expect(find.text('کاغذ'), findsOneWidget);
    expect(find.byType(Table), findsNWidgets(2));

    await tester.tap(find.text('کاغذ'));
    await tester.pumpAndSettle();
    expect(find.text('تفصیل: کاغذ'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('test-history-search')),
      'قلم',
    );
    await tester.pumpAndSettle();
    expect(find.text('کاغذ'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('test-history-قلم')),
        matching: find.text('قلم'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const ValueKey('test-history-search')),
      '',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('منظور شدہ').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('test-history-کاغذ')), findsOneWidget);
    expect(find.byKey(const ValueKey('test-history-قلم')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
