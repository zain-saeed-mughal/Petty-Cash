double coreAmount(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;

DateTime coreDate(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();

class OfficeRecord {
  final String id, name;
  const OfficeRecord(this.id, this.name);
  factory OfficeRecord.fromMap(Map<String, dynamic> row) =>
      OfficeRecord(row['id'].toString(), row['name'].toString());
}

class CoreAdvance {
  final String id, officeBoyId, officeId, purpose, method, status;
  final String? accountName, accountDetails, clearedMethod, financeNote;
  final double amount;
  final DateTime createdAt;
  final DateTime? clearedAt;
  const CoreAdvance({
    required this.id,
    required this.officeBoyId,
    required this.officeId,
    required this.purpose,
    required this.method,
    required this.status,
    required this.amount,
    required this.createdAt,
    this.accountName,
    this.accountDetails,
    this.clearedMethod,
    this.financeNote,
    this.clearedAt,
  });
  factory CoreAdvance.fromMap(Map<String, dynamic> row) => CoreAdvance(
    id: row['id'].toString(),
    officeBoyId: row['office_boy_id'].toString(),
    officeId: row['office_id'].toString(),
    purpose: row['purpose'].toString(),
    method: row['payment_method_requested'].toString(),
    status: row['status'].toString(),
    amount: coreAmount(row['amount_requested']),
    createdAt: coreDate(row['created_at']),
    accountName: row['receiver_account_name']?.toString(),
    accountDetails: row['receiver_account_details']?.toString(),
    clearedMethod: row['cleared_method']?.toString(),
    financeNote: row['finance_note']?.toString(),
    clearedAt: row['cleared_at'] == null ? null : coreDate(row['cleared_at']),
  );
}

class CoreAdvanceItem {
  final String id, advanceId, officeBoyId, officeId, description, status;
  final String? billPath, reviewedBy, rejectionReason, taggedManagerId;
  final double amount;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  const CoreAdvanceItem({
    required this.id,
    required this.advanceId,
    required this.officeBoyId,
    required this.officeId,
    required this.description,
    required this.amount,
    required this.createdAt,
    required this.status,
    this.billPath,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    this.taggedManagerId,
  });
  factory CoreAdvanceItem.fromMap(Map<String, dynamic> row) => CoreAdvanceItem(
    id: row['id'].toString(),
    advanceId: row['advance_request_id'].toString(),
    officeBoyId: row['office_boy_id'].toString(),
    officeId: row['office_id'].toString(),
    description: row['item_description'].toString(),
    amount: coreAmount(row['amount_spent']),
    createdAt: coreDate(row['created_at']),
    status: row['status']?.toString() ?? 'approved',
    billPath: row['bill_path']?.toString(),
    reviewedBy: row['reviewed_by']?.toString(),
    reviewedAt: row['reviewed_at'] == null ? null : coreDate(row['reviewed_at']),
    rejectionReason: row['rejection_reason']?.toString(),
    taggedManagerId: row['tagged_manager_id']?.toString(),
  );
}

class CoreBalance {
  final String advanceId, officeBoyId, officeId;
  final double total, spent, remaining;
  final int itemCount;
  const CoreBalance({
    required this.advanceId,
    required this.officeBoyId,
    required this.officeId,
    required this.total,
    required this.spent,
    required this.remaining,
    required this.itemCount,
  });
  factory CoreBalance.fromMap(Map<String, dynamic> row) => CoreBalance(
    advanceId: row['advance_request_id'].toString(),
    officeBoyId: row['office_boy_id'].toString(),
    officeId: row['office_id'].toString(),
    total: coreAmount(row['total']),
    spent: coreAmount(row['spent']),
    remaining: coreAmount(row['remaining']),
    itemCount: (row['item_count'] as num?)?.toInt() ?? 0,
  );
}

class CoreReimbursement {
  final String id, officeBoyId, officeId, description, wantedMethod, status;
  final String? billPath,
      accountName,
      accountDetails,
      rejectionReason,
      paidMethod,
      taggedManagerId;
  final double amount;
  final DateTime createdAt;
  final DateTime? reviewedAt, paidAt;
  const CoreReimbursement({
    required this.id,
    required this.officeBoyId,
    required this.officeId,
    required this.description,
    required this.wantedMethod,
    required this.status,
    required this.amount,
    required this.createdAt,
    this.billPath,
    this.accountName,
    this.accountDetails,
    this.rejectionReason,
    this.paidMethod,
    this.taggedManagerId,
    this.reviewedAt,
    this.paidAt,
  });
  factory CoreReimbursement.fromMap(Map<String, dynamic> row) =>
      CoreReimbursement(
        id: row['id'].toString(),
        officeBoyId: row['office_boy_id'].toString(),
        officeId: row['office_id'].toString(),
        description: row['item_description'].toString(),
        wantedMethod: row['payment_method_wanted'].toString(),
        status: row['status'].toString(),
        amount: coreAmount(row['amount_spent']),
        createdAt: coreDate(row['created_at']),
        billPath: row['bill_path']?.toString(),
        accountName: row['receiver_account_name']?.toString(),
        accountDetails: row['receiver_account_details']?.toString(),
        rejectionReason: row['rejection_reason']?.toString(),
        paidMethod: row['paid_method']?.toString(),
        taggedManagerId: row['tagged_manager_id']?.toString(),
        reviewedAt: row['reviewed_at'] == null
            ? null
            : coreDate(row['reviewed_at']),
        paidAt: row['paid_at'] == null ? null : coreDate(row['paid_at']),
      );
}

class CoreActivity {
  final String? advanceId, reimbursementId;
  final String actorId, action;
  final DateTime createdAt;
  final Map<String, dynamic> detail;
  const CoreActivity({
    required this.actorId,
    required this.action,
    required this.createdAt,
    required this.detail,
    this.advanceId,
    this.reimbursementId,
  });
  factory CoreActivity.fromMap(Map<String, dynamic> row) => CoreActivity(
    advanceId: row['advance_request_id']?.toString(),
    reimbursementId: row['reimbursement_id']?.toString(),
    actorId: row['actor_id'].toString(),
    action: row['action'].toString(),
    createdAt: coreDate(row['created_at']),
    detail: Map<String, dynamic>.from(row['detail'] as Map? ?? {}),
  );
}
