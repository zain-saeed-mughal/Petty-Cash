import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petty_cash/main.dart';
import 'package:petty_cash/providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
