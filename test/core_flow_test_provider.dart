import 'package:flutter/foundation.dart';
import 'package:petty_cash/models/core_flow_models.dart';
import 'package:petty_cash/providers/core_flow_provider.dart';

class CoreFlowTestProvider extends ChangeNotifier implements CoreFlowProvider {
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
  String? get error => null;
  @override
  double balanceFor(String uid) => 0;
  @override
  CoreBalance? balanceForAdvance(String id) => null;
  @override
  bool isBusy(String key) => false;
  @override
  void refresh() {}
  @override
  Future<bool> requestAdvance({
    String? id,
    required String purpose,
    required double amount,
    required String method,
    String? accountName,
    String? accountDetails,
  }) async {
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
