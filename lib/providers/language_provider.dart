import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/translations.dart';
import '../services/push_notification_service.dart';
import '../l10n/ui_translations.dart';
import '../models/notification_model.dart';

class LanguageProvider extends ChangeNotifier {
  String _currentLanguage;
  bool _isLanguageSelected = false, _disposed = false, _loaded = false;
  int _revision = 0;
  late final Future<void> ready;
  Future<void> _saveQueue = Future.value();

  LanguageProvider({String initialLanguage = 'en', bool loadSaved = true})
    : _currentLanguage = initialLanguage == 'ur' ? 'ur' : 'en' {
    ready = _initialize(loadSaved);
  }

  String get currentLanguage => _currentLanguage;
  Locale get locale => Locale(_currentLanguage);
  bool get isRtl => _currentLanguage == 'ur';
  bool get isLoaded => _loaded;
  bool get isLanguageSelected => _isLanguageSelected;
  static final _urdu = <String, String>{
    for (final entry in AppTranslations.translations['en']!.entries)
      if (AppTranslations.translations['ur']![entry.key] != null)
        entry.value: AppTranslations.translations['ur']![entry.key]!,
    ...UiTranslations.ur,
  };

  Future<void> _initialize(bool loadSaved) async {
    final revision = _revision;
    await initializeDateFormatting('ur');
    if (loadSaved) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString('language_code');
        if (!_disposed &&
            revision == _revision &&
            (saved == 'en' || saved == 'ur')) {
          _currentLanguage = saved!;
          _isLanguageSelected = true;
        }
      } catch (_) {
        // Storage may be unavailable in private browsing. The session still works.
      }
    }
    PushNotificationService().setLanguage(_currentLanguage);
    _loaded = true;
    if (!_disposed) notifyListeners();
  }

  Future<void> setLanguage(String languageCode) {
    if (languageCode != 'en' && languageCode != 'ur') {
      throw ArgumentError.value(languageCode, 'languageCode');
    }
    if (_disposed) return Future.value();
    _revision++;
    _currentLanguage = languageCode;
    _isLanguageSelected = true;
    PushNotificationService().setLanguage(languageCode);
    notifyListeners();
    return _saveQueue = _saveQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('language_code', languageCode);
      } catch (_) {
        // Keep the selected language usable even when persistence is unavailable.
      }
    });
  }

  String tr(String key) =>
      AppTranslations.translations[_currentLanguage]?[key] ??
      AppTranslations.translations['en']?[key] ??
      text(key);
  String text(String english) => isRtl ? (_urdu[english] ?? english) : english;
  String date(DateTime value, {String pattern = 'dd MMM yyyy'}) =>
      DateFormat(pattern, currentLanguage).format(value.toLocal());
  String money(num value) {
    final amount = NumberFormat('#,##0.00', currentLanguage).format(value);
    return isRtl ? '$amount روپے' : 'Rs. $amount';
  }

  String number(num value) =>
      NumberFormat.decimalPattern(currentLanguage).format(value);
  String format(String en, String ur, Map<String, Object?> args) {
    var result = isRtl ? ur : en;
    for (final entry in args.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value ?? ''}');
    }
    return result;
  }

  String error(String value) {
    final clean = value.replaceFirst(
      RegExp(r'^(Exception|Bad state|StateError|FormatException):\s*'),
      '',
    );
    // Only translate to Urdu when Urdu is the active language
    if (isRtl && _urdu.containsKey(clean)) return _urdu[clean]!;
    final lower = clean.toLowerCase();
    if (RegExp(
      r'network|connection|socket|fetch|timeout|clientexception',
    ).hasMatch(lower)) {
      return isRtl
          ? 'رابطہ نہیں ہو سکا۔ انٹرنیٹ چیک کر کے دوبارہ کوشش کریں۔'
          : 'Couldn\'t connect. Check your internet and try again.';
    }
    if (RegExp(r'duplicate|already exists|unique constraint').hasMatch(lower)) {
      return isRtl
          ? 'یہ چیز پہلے سے موجود ہے۔ فہرست چیک کر کے دوبارہ کوشش کریں۔'
          : 'This already exists. Check the list and try again.';
    }
    if (RegExp(r'jwt|session expired|token expired|\b401\b').hasMatch(lower)) {
      return isRtl
          ? 'آپ کا سیشن ختم ہو گیا۔ دوبارہ لاگ ان کریں۔'
          : 'Your session ended. Sign in again.';
    }
    if (RegExp(r'permission|not authorized|forbidden|row-level security|\b403\b')
        .hasMatch(lower)) {
      return isRtl
          ? 'آپ کو یہ کام کرنے کی اجازت نہیں۔ ایڈمن سے رابطہ کریں۔'
          : 'You can\'t do this. Ask your administrator for help.';
    }
    if (RegExp(
      r'postgrest|postgres|supabase|sqlstate|stack trace|internal server error|\b50[0-4]\b',
    ).hasMatch(lower)) {
      return isRtl
          ? 'کچھ مسئلہ ہو گیا۔ دوبارہ کوشش کریں۔'
          : 'Something went wrong. Please try again.';
    }
    if (!isRtl) return clean;
    if (RegExp(r'[\u0600-\u06ff]').hasMatch(clean)) return clean;
    return 'کارروائی مکمل نہیں ہو سکی۔ دوبارہ کوشش کریں۔';
  }

  String auditAction(String value) {
    if (!isRtl) return value;
    final match = RegExp(r'^Status (?:changed|overridden) to (.*)$')
        .firstMatch(value);
    return match == null ? text(value) : 'حیثیت ${text(match[1]!)} کر دی گئی';
  }

  String notificationTitle(AppNotification notification) {
    if (!isRtl) return notification.title;
    const coreTitles = {
      'Advance requested': 'ایڈوانس کی درخواست',
      'Advance sent': 'ایڈوانس کی رقم دے دی گئی',
      'Repayment requested': 'رقم واپسی کی درخواست',
      'Repayment approved': 'رقم واپسی منظور',
      'Repayment rejected': 'رقم واپسی مسترد',
      'Repayment paid': 'رقم واپس ادا کر دی گئی',
    };
    if (coreTitles.containsKey(notification.title)) {
      return coreTitles[notification.title]!;
    }
    final translated = text(notification.title);
    if (translated != notification.title) return translated;
    final match = RegExp(
      r'^Request (Pending|Approved|Rejected|Paid)$',
      caseSensitive: false,
    ).firstMatch(notification.title);
    if (match != null) {
      final status = match[1]!.toLowerCase();
      return 'درخواست ${text(status[0].toUpperCase() + status.substring(1))}';
    }
    return 'درخواست کی تازہ اطلاع';
  }

  String notificationBody(AppNotification notification) {
    final value = notification.message;
    if (!isRtl) return value;
    final coreAdvance = RegExp(r'^(.*?) requested PKR (.+)\.$')
        .firstMatch(value);
    if (coreAdvance != null) {
      return '${coreAdvance[1]} نے ${coreAdvance[2]} روپے ایڈوانس مانگے ہیں۔';
    }
    final coreRepayment = RegExp(r'^(.*?) requested PKR (.+) repayment\.$')
        .firstMatch(value);
    if (coreRepayment != null) {
      return '${coreRepayment[1]} نے ${coreRepayment[2]} روپے کی واپسی مانگی ہے۔';
    }
    if (value == 'Finance marked your advance as sent.') {
      return 'فنانس نے آپ کی ایڈوانس رقم دے دی ہے۔';
    }
    if (value == 'Finance approved your repayment request.') {
      return 'فنانس نے آپ کی رقم واپسی منظور کر لی ہے۔';
    }
    if (value == 'Finance marked your repayment as paid.') {
      return 'فنانس نے آپ کی رقم واپس ادا کر دی ہے۔';
    }
    if (value.startsWith('Finance rejected your request: ')) {
      return 'فنانس نے آپ کی درخواست مسترد کی۔ وجہ: ${value.replaceFirst('Finance rejected your request: ', '')}';
    }
    final advanceGiven = RegExp(
      r'^Finance gave you an advance of PKR (.+)\. Confirm receipt and method\.$',
    ).firstMatch(value);
    if (advanceGiven != null) {
      return 'فنانس نے آپ کو ${advanceGiven[1]} روپے پیشگی دیے ہیں۔ وصولی اور طریقے کی تصدیق کریں۔';
    }
    final advanceReceived = RegExp(
      r'^(.*?) confirmed an advance of PKR (.+) by (Cash|Card)\.$',
    ).firstMatch(value);
    if (advanceReceived != null) {
      return '${advanceReceived[1]} نے ${advanceReceived[2]} روپے کی پیشگی رقم ${advanceReceived[3] == 'Cash' ? 'نقد' : 'کارڈ'} سے وصول کرنے کی تصدیق کی۔';
    }
    final settlement = RegExp(r'^(.*?) submitted a settlement update\.$')
        .firstMatch(value);
    if (settlement != null) {
      return '${settlement[1]} نے پیشگی رقم کا تازہ حساب جمع کیا ہے۔';
    }
    final closed = RegExp(
      r"^(.*?)'s advance has been fully settled and closed\.$",
    ).firstMatch(value);
    if (closed != null) {
      return '${closed[1]} کی پیشگی رقم کا حساب مکمل اور بند ہو گیا ہے۔';
    }
    final submitted = RegExp(
      r'^(.*?) submitted a request for (?:PKR |Rs\. )(.+)$',
    ).firstMatch(value);
    if (submitted != null) {
      return '${submitted[1]} نے ${submitted[2]} روپے کی درخواست جمع کی ہے';
    }
    final changed = RegExp(
      r'^Your request for (.*?) (?:is now |was |was changed to )(pending|approved|rejected|paid)\.?$',
      caseSensitive: false,
    ).firstMatch(value);
    if (changed != null) {
      final status = changed[2]!.toLowerCase();
      return '${changed[1]} کی آپ کی درخواست ${text(status[0].toUpperCase() + status.substring(1))} ہے';
    }
    final rejected = RegExp(r'^Your request for (.*?) was rejected: (.*)$')
        .firstMatch(value);
    if (rejected != null) {
      return '${rejected[1]} کی آپ کی درخواست مسترد کر دی گئی: ${rejected[2]}';
    }
    return _urdu[value] ?? 'تازہ معلومات کے لیے درخواست کی تفصیلات دیکھیں۔';
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
