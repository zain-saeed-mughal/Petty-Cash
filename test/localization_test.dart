import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petty_cash/config/app_theme.dart';
import 'package:petty_cash/l10n/translations.dart';
import 'package:petty_cash/l10n/ui_translations.dart';
import 'package:petty_cash/models/notification_model.dart';
import 'package:petty_cash/models/expense_request_model.dart';
import 'package:petty_cash/providers/auth_provider.dart';
import 'package:petty_cash/providers/language_provider.dart';
import 'package:petty_cash/screens/auth/login_screen.dart';

class SignedOutAuth extends ChangeNotifier implements AuthProvider {
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Every literal translation used by the app has an Urdu entry', () {
    final language = LanguageProvider(initialLanguage: 'ur', loadSaved: false);
    final missing = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      for (final match in RegExp(
        r'''\.tr\(['"]([^'"]+)['"]\)''',
      ).allMatches(source)) {
        if (!AppTranslations.translations['ur']!.containsKey(match[1])) {
          missing.add('${file.path}: ${match[1]}');
        }
      }
      for (final match in RegExp(
        r'''\.t\(['"]([^'"]+)['"]\)''',
      ).allMatches(source)) {
        final value = match[1]!;
        if (value != 'English' && language.text(value) == value) {
          missing.add('${file.path}: $value');
        }
      }
    }
    language.dispose();
    expect(missing, isEmpty);
  });
  test('English and Urdu catalogs have matching keys and translated copy', () {
    final en = AppTranslations.translations['en']!;
    final ur = AppTranslations.translations['ur']!;
    expect(ur.keys.toSet(), en.keys.toSet());
    for (final entry in ur.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      if (entry.key != 'english') {
        expect(entry.value, isNot(en[entry.key]), reason: entry.key);
      }
    }
    final language = LanguageProvider(initialLanguage: 'ur', loadSaved: false);
    for (final entry in UiTranslations.ur.entries) {
      expect(language.text(entry.key), entry.value);
    }
    language.dispose();
  });
  test('Saved language restores, latest selection wins, invalid values are rejected', () async {
    SharedPreferences.setMockInitialValues({'language_code': 'ur'});
    final restored = LanguageProvider();
    await restored.ready;
    expect(restored.currentLanguage, 'ur');
    restored.dispose();
    final language = LanguageProvider();
    final saveEn = language.setLanguage('en');
    expect(language.currentLanguage, 'en');
    await Future.wait([language.ready, saveEn]);
    expect(language.currentLanguage, 'en');
    await Future.wait([
      language.setLanguage('ur'),
      language.setLanguage('en'),
      language.setLanguage('ur'),
    ]);
    expect(
      (await SharedPreferences.getInstance()).getString('language_code'),
      'ur',
    );
    expect(() => language.setLanguage('xx'), throwsArgumentError);
    language.dispose();
    final disposed = LanguageProvider();
    disposed.dispose();
    await disposed.ready;
  });
  test('System notifications translate without changing user content or API status', () async {
    final language = LanguageProvider(initialLanguage: 'ur', loadSaved: false);
    await language.ready;
    final notification = AppNotification(
      userId: 'x',
      title: 'Request Paid',
      message: 'Your request for Printer paper is now paid.',
    );
    expect(language.notificationTitle(notification), contains('ادا شدہ'));
    expect(language.notificationBody(notification), contains('Printer paper'));
    expect(language.notificationBody(notification), isNot(contains('is now')));
    expect(language.date(DateTime(2026, 9, 24)), contains('ستمبر'));
    expect(language.money(12500.5), contains('روپے'));
    expect(RequestStatus.paid.displayName, 'Paid');
    language.dispose();
  });
  testWidgets(
    'Login switch is tappable, changes RTL and persists both languages',
    (tester) async {
      final language = LanguageProvider(loadSaved: false);
      await tester.runAsync(() => language.ready);
      final auth = SignedOutAuth();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageProvider>.value(value: language),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: Consumer<LanguageProvider>(
            builder: (_, lang, _) => MaterialApp(
              theme: AppTheme.forLanguage(lang.currentLanguage),
              locale: lang.locale,
              supportedLocales: const [Locale('en'), Locale('ur')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: const LoginScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('اردو'));
      await tester.pumpAndSettle();
      expect(language.isRtl, isTrue);
      expect(find.text(language.tr('sign_in')), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(Form))),
        TextDirection.rtl,
      );
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();
      expect(language.isRtl, isFalse);
      expect(find.text(language.tr('sign_in')), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(Form))),
        TextDirection.ltr,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      language.dispose();
      auth.dispose();
    },
  );
}
