import 'package:flutter_test/flutter_test.dart';
import 'package:petty_cash/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build PettyCashApp and trigger a frame.
    await tester.pumpWidget(const AppProviders(child: PettyCashApp(initializeServices: false)));
    expect(find.byType(PettyCashApp), findsOneWidget);
  });
}
