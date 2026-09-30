import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petty_cash/providers/core_flow_provider.dart';
import 'package:petty_cash/providers/language_provider.dart';
import 'package:petty_cash/screens/core/core_entry_dialog.dart';
import 'package:provider/provider.dart';

import 'core_flow_test_provider.dart';

Future<void> openForm(
  WidgetTester tester,
  CoreFlowTestProvider flow,
  String mode,
) async {
  final language = LanguageProvider(initialLanguage: 'en', loadSaved: false);
  await language.ready;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CoreFlowProvider>.value(value: flow),
        ChangeNotifierProvider<LanguageProvider>.value(value: language),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => CoreEntryDialog(mode: mode),
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
}

void main() {
  testWidgets('Card advance requires account details before sending', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final flow = CoreFlowTestProvider();
    await openForm(tester, flow, 'advance');
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Buy printer paper',
    );
    await tester.enterText(find.byType(TextFormField).at(1), '1200.50');
    await tester.tap(find.text('Card'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Send Request'));
    await tester.tap(find.text('Send Request'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the account name.'), findsOneWidget);
    expect(flow.lastPurpose, isNull);
    await tester.enterText(find.byType(TextFormField).at(2), 'Zain');
    await tester.enterText(find.byType(TextFormField).at(3), 'IBAN 123');
    await tester.ensureVisible(find.text('Send Request'));
    await tester.tap(find.text('Send Request'));
    await tester.pumpAndSettle();
    expect(flow.lastPurpose, 'Buy printer paper');
    expect(flow.lastAmount, 1200.50);
    expect(flow.lastMethod, 'card');
    expect(flow.lastAccountDetails, 'IBAN 123');
  });

  testWidgets('Own-money Card request allows account details later', (
    tester,
  ) async {
    final flow = CoreFlowTestProvider();
    await openForm(tester, flow, 'reimbursement');
    await tester.enterText(find.byType(TextFormField).at(0), 'Taxi fare');
    await tester.enterText(find.byType(TextFormField).at(1), '450');
    await tester.tap(find.text('Card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send Request'));
    await tester.pumpAndSettle();
    expect(flow.lastItem, 'Taxi fare');
    expect(flow.lastMethod, 'card');
    expect(flow.lastAccountName, '');
  });
}
