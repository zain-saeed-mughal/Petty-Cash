double paymentAmount(Object? value) =>
    value is num ? value.toDouble() : double.parse(value.toString());

DateTime paymentDate(Object? value) =>
    DateTime.parse(value.toString()).toLocal();

class AdvanceRecord {
  final String id, officeBoyId, givenBy, financeMethod, status;
  final String? receivedMethod, note;
  final double amount;
  final bool mismatchFlag;
  final DateTime createdAt;
  final DateTime? confirmedAt;

  const AdvanceRecord({
    required this.id,
    required this.officeBoyId,
    required this.givenBy,
    required this.financeMethod,
    required this.status,
    required this.amount,
    required this.mismatchFlag,
    required this.createdAt,
    this.receivedMethod,
    this.note,
    this.confirmedAt,
  });

  factory AdvanceRecord.fromMap(Map<String, dynamic> row) => AdvanceRecord(
    id: row['id'].toString(),
    officeBoyId: row['office_boy_id'].toString(),
    givenBy: row['given_by'].toString(),
    financeMethod: row['finance_method'].toString(),
    receivedMethod: row['received_method']?.toString(),
    status: row['status'].toString(),
    amount: paymentAmount(row['amount']),
    mismatchFlag: row['mismatch_flag'] == true,
    note: row['note']?.toString(),
    createdAt: paymentDate(row['created_at']),
    confirmedAt: row['confirmed_at'] == null
        ? null
        : paymentDate(row['confirmed_at']),
  );
}

class PaymentExpense {
  final String id, officeBoyId, flowType, itemDescription, reason, status;
  final String? advanceId;
  final String? billPath,
      paymentMethodFinance,
      paymentMethodReceived,
      rejectionReason;
  final double amount;
  final bool mismatchFlag;
  final DateTime createdAt, updatedAt;
  final DateTime? rejectionAcknowledgedAt, clearedAt, paidAt;

  const PaymentExpense({
    required this.id,
    required this.officeBoyId,
    required this.flowType,
    required this.itemDescription,
    required this.reason,
    required this.status,
    required this.amount,
    required this.mismatchFlag,
    required this.createdAt,
    required this.updatedAt,
    this.billPath,
    this.advanceId,
    this.paymentMethodFinance,
    this.paymentMethodReceived,
    this.rejectionReason,
    this.rejectionAcknowledgedAt,
    this.clearedAt,
    this.paidAt,
  });

  factory PaymentExpense.fromMap(Map<String, dynamic> row) => PaymentExpense(
    id: row['id'].toString(),
    officeBoyId: row['office_boy_id'].toString(),
    flowType: row['flow_type'].toString(),
    itemDescription: row['item_description'].toString(),
    reason: row['reason'].toString(),
    status: row['status'].toString(),
    amount: paymentAmount(row['amount']),
    mismatchFlag: row['mismatch_flag'] == true,
    createdAt: paymentDate(row['created_at']),
    updatedAt: paymentDate(row['updated_at']),
    billPath: row['bill_path']?.toString(),
    advanceId: row['advance_id']?.toString(),
    paymentMethodFinance: row['payment_method_finance']?.toString(),
    paymentMethodReceived: row['payment_method_received']?.toString(),
    rejectionReason: row['rejection_reason']?.toString(),
    rejectionAcknowledgedAt: row['rejection_acknowledged_at'] == null
        ? null
        : paymentDate(row['rejection_acknowledged_at']),
    clearedAt: row['cleared_at'] == null
        ? null
        : paymentDate(row['cleared_at']),
    paidAt: row['paid_at'] == null ? null : paymentDate(row['paid_at']),
  );
}

class AdvanceRequestRecord {
  final String id, officeBoyId, purpose, status;
  final String? rejectionReason, decidedBy, advanceId;
  final double amount;
  final DateTime createdAt;
  final DateTime? decidedAt;

  const AdvanceRequestRecord({
    required this.id,
    required this.officeBoyId,
    required this.purpose,
    required this.status,
    required this.amount,
    required this.createdAt,
    this.rejectionReason,
    this.decidedBy,
    this.decidedAt,
    this.advanceId,
  });

  factory AdvanceRequestRecord.fromMap(Map<String, dynamic> row) =>
      AdvanceRequestRecord(
        id: row['id'].toString(),
        officeBoyId: row['office_boy_id'].toString(),
        purpose: row['purpose'].toString(),
        status: row['status'].toString(),
        amount: paymentAmount(row['amount']),
        createdAt: paymentDate(row['created_at']),
        rejectionReason: row['rejection_reason']?.toString(),
        decidedBy: row['decided_by']?.toString(),
        advanceId: row['advance_id']?.toString(),
        decidedAt: row['decided_at'] == null
            ? null
            : paymentDate(row['decided_at']),
      );
}

class AdvanceBalance {
  final String advanceId, officeBoyId;
  final double amount, spent, onHold, available;
  final int expenseCount;

  const AdvanceBalance({
    required this.advanceId,
    required this.officeBoyId,
    required this.amount,
    required this.spent,
    required this.onHold,
    required this.available,
    required this.expenseCount,
  });

  factory AdvanceBalance.fromMap(Map<String, dynamic> row) => AdvanceBalance(
    advanceId: row['advance_id'].toString(),
    officeBoyId: row['office_boy_id'].toString(),
    amount: paymentAmount(row['amount']),
    spent: paymentAmount(row['spent']),
    onHold: paymentAmount(row['on_hold']),
    available: paymentAmount(row['available']),
    expenseCount: (row['expense_count'] as num).toInt(),
  );
}

class FloatSummary {
  final String officeBoyId, officeBoyName;
  final double totalReceived,
      totalSpent,
      onHold,
      availableBalance,
      totalReimbursed;
  final int advanceCount, expenseCount;

  const FloatSummary({
    required this.officeBoyId,
    required this.officeBoyName,
    required this.totalReceived,
    required this.totalSpent,
    required this.onHold,
    required this.availableBalance,
    required this.totalReimbursed,
    required this.advanceCount,
    required this.expenseCount,
  });

  factory FloatSummary.fromMap(Map<String, dynamic> row) => FloatSummary(
    officeBoyId: row['office_boy_id'].toString(),
    officeBoyName: row['office_boy_name'].toString(),
    totalReceived: paymentAmount(row['total_received']),
    totalSpent: paymentAmount(row['total_spent']),
    onHold: paymentAmount(row['on_hold']),
    availableBalance: paymentAmount(row['available_balance']),
    totalReimbursed: paymentAmount(row['total_reimbursed']),
    advanceCount: (row['advance_count'] as num).toInt(),
    expenseCount: (row['expense_count'] as num).toInt(),
  );
}

class PaymentActivity {
  final int id;
  final String? advanceId, expenseId;
  final String actorId, action;
  final Map<String, dynamic> detail;
  final DateTime createdAt;

  const PaymentActivity({
    required this.id,
    required this.actorId,
    required this.action,
    required this.detail,
    required this.createdAt,
    this.advanceId,
    this.expenseId,
  });

  factory PaymentActivity.fromMap(Map<String, dynamic> row) => PaymentActivity(
    id: (row['id'] as num).toInt(),
    actorId: row['actor_id'].toString(),
    action: row['action'].toString(),
    detail: Map<String, dynamic>.from(row['detail'] as Map),
    createdAt: paymentDate(row['created_at']),
    advanceId: row['advance_id']?.toString(),
    expenseId: row['expense_id']?.toString(),
  );
}
