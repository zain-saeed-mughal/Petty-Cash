import 'package:flutter/foundation.dart';
import 'package:petty_cash/models/core_flow_models.dart';
import 'package:petty_cash/providers/core_flow_provider.dart';

class CoreFlowTestProvider extends ChangeNotifier implements CoreFlowProvider {
  String? _error;
  String? lastPurpose,
      lastItem,
      lastMethod,
      lastAccountName,
      lastAccountDetails;
  double? lastAmount;
  @override
  List<OfficeRecord> offices = const [];
  @override
  List<CoreAdvance> advances = const [];
  @override
  List<CoreAdvanceItem> items = const [];
  @override
  List<CoreBalance> balances = const [];
  @override
  List<CoreReimbursement> reimbursements = const [];
  @override
  List<CoreActivity> activity = const [];
  @override
  bool get isLoading => false;
  @override
  String? get error => _error;
  @override
  double balanceFor(String uid) => 0;
  @override
  CoreBalance? balanceForAdvance(String id) => null;
  @override
  bool isBusy(String key) => false;
  @override
  void refresh() {}
  @override
  Future<bool> respondToDirectAdvance(String id, String decision) async {
    advances = advances.map((advance) {
      if (advance.id != id) return advance;
      return CoreAdvance(
        id: advance.id,
        officeBoyId: advance.officeBoyId,
        officeId: advance.officeId,
        purpose: advance.purpose,
        method: advance.method,
        status: decision == 'approve' ? 'cleared' : 'declined',
        amount: advance.amount,
        createdAt: advance.createdAt,
      );
    }).toList();
    notifyListeners();
    return true;
  }

  @override
  Future<bool> requestAdvance({
    String? id,
    required String purpose,
    required double amount,
    required String method,
    String? accountName,
    String? accountDetails,
  }) async {
    if (method == 'card' &&
        (accountName == null || accountName.trim().isEmpty)) {
      _error = 'Enter the account name.';
      return false;
    }
    _error = null;
    lastPurpose = purpose;
    lastAmount = amount;
    lastMethod = method;
    lastAccountName = accountName;
    lastAccountDetails = accountDetails;
    return true;
  }

  @override
  Future<bool> requestReimbursement({
    String? id,
    required String item,
    required double amount,
    required String method,
    String? billPath,
    String? accountName,
    String? accountDetails,
    String? taggedManagerId,
  }) async {
    lastItem = item;
    lastAmount = amount;
    lastMethod = method;
    lastAccountName = accountName;
    lastAccountDetails = accountDetails;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
