import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:petty_cash/models/expense_request_model.dart';
import 'package:petty_cash/models/notification_model.dart';
import 'package:petty_cash/models/user_model.dart';
import 'package:petty_cash/providers/expense_provider.dart';
import 'package:petty_cash/providers/language_provider.dart';

ExpenseRequest advance(RequestStatus status) => ExpenseRequest(
  id: 'advance',
  requestedBy: 'staff',
  requesterName: 'Ali',
  itemDescription: 'Stationery',
  amount: 10000,
  reason: 'Office',
  createdAt: DateTime.utc(2026, 8, 30),
  updatedAt: DateTime.utc(2026, 10, 1),
  paidAt: DateTime.utc(2026, 9, 1, 12),
  requestType: 'advance',
  status: status,
  settlementAmount: 6000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Payment date and disbursement survive both settlement stages', () {
    for (final status in [
      RequestStatus.paid,
      RequestStatus.pendingSettlement,
      RequestStatus.settled,
    ]) {
      final r = advance(status);
      expect(r.disbursedAmount, 10000);
      expect(r.reportingDate.month, 9);
    }
    expect(advance(RequestStatus.pendingSettlement).verifiedExpense, 0);
    expect(advance(RequestStatus.pendingSettlement).outstandingAdvance, 10000);
    expect(advance(RequestStatus.settled).verifiedExpense, 6000);
    expect(advance(RequestStatus.settled).verifiedReturn, 4000);
    expect(advance(RequestStatus.settled).outstandingAdvance, 0);
  });

  test(
    'Finance queue, counters and totals include a pending settlement',
    () async {
      final source = StreamController<List<ExpenseRequest>>();
      final provider = ExpenseProvider(requests: () => source.stream);
      provider.updateUser(
        AppUser(
          uid: 'finance',
          name: 'Finance',
          email: 'f@example.test',
          role: UserRole.finance,
          createdAt: DateTime.now(),
        ),
      );
      source.add([advance(RequestStatus.pendingSettlement)]);
      await Future<void>.delayed(Duration.zero);
      expect(provider.pendingRequests.single.id, 'advance');
      expect(provider.pendingCount, 1);
      expect(provider.totalSpent, 10000);
      expect(provider.approvedCount, 1);
      source.add([advance(RequestStatus.settled)]);
      await Future<void>.delayed(Duration.zero);
      expect(provider.pendingCount, 0);
      expect(provider.totalSpent, 10000);
      expect(provider.verifiedExpenses, 6000);
      expect(provider.returnedAmount, 4000);
      expect(provider.outstandingAdvances, 0);
      provider.dispose();
      await source.close();
    },
  );

  test('Override choices exclude settlement-only transitions', () {
    expect(ExpenseRequest.overrideStatuses, [
      RequestStatus.pending,
      RequestStatus.approved,
      RequestStatus.rejected,
      RequestStatus.paid,
    ]);
  });

  test(
    'Urdu preserves settlement notification meaning and requester name',
    () async {
      final language = LanguageProvider(
        initialLanguage: 'ur',
        loadSaved: false,
      );
      await language.ready;
      final message = AppNotification(
        userId: 'finance',
        title: 'Advance Settlement',
        message: 'Ali submitted a settlement update.',
      );
      expect(language.notificationTitle(message), 'پیشگی رقم کا حساب');
      expect(
        language.notificationBody(message),
        'Ali نے پیشگی رقم کا تازہ حساب جمع کیا ہے۔',
      );
      expect(language.text('Update Settlement'), 'حساب میں تبدیلی کریں');
      language.dispose();
    },
  );
}
