const _unchanged = Object();

enum RequestStatus {
  pending,
  approved,
  rejected,
  paid,
  pendingSettlement,
  settled;

  String get displayName {
    switch (this) {
      case RequestStatus.pending:
        return 'Pending';
      case RequestStatus.approved:
        return 'Approved';
      case RequestStatus.rejected:
        return 'Rejected';
      case RequestStatus.paid:
        return 'Paid';
      case RequestStatus.pendingSettlement:
        return 'Pending Settlement';
      case RequestStatus.settled:
        return 'Settled';
    }
  }

  static RequestStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return RequestStatus.approved;
      case 'rejected':
        return RequestStatus.rejected;
      case 'paid':
        return RequestStatus.paid;
      case 'pending settlement':
      case 'pending_settlement':
      case 'pendingsettlement':
        return RequestStatus.pendingSettlement;
      case 'settled':
        return RequestStatus.settled;
      case 'pending':
      default:
        return RequestStatus.pending;
    }
  }
}

class ExpenseRequest {
  final String id;
  final String requestedBy;
  final String requesterName;
  final String requesterEmail;
  final String itemDescription;
  final double amount;
  final String reason;
  final String? billImageUrl;
  final RequestStatus status;
  final String? rejectionReason;
  final String? reviewedBy;
  final String? reviewedByName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AuditLogEntry> auditLogs;
  final int version;
  final DateTime? paidAt;

  // Advance & Settlement Fields
  final String requestType; // 'reimbursement' or 'advance'
  final double? settlementAmount;
  final String? settlementMethod; // 'Cash', 'Card', etc.
  final String? settlementNote;
  final DateTime? settlementDate;
  DateTime get reportingDate =>
      (hasDisbursement ? paidAt ?? updatedAt : createdAt).toLocal();
  String get displayId => id.startsWith("REQ-")
      ? id
      : "REQ-${id.substring(0, id.length < 8 ? id.length : 8).toUpperCase()}";

  ExpenseRequest({
    required this.id,
    required this.requestedBy,
    required this.requesterName,
    this.requesterEmail = '',
    required this.itemDescription,
    required this.amount,
    required this.reason,
    this.billImageUrl,
    this.status = RequestStatus.pending,
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedByName,
    required this.createdAt,
    required this.updatedAt,
    this.auditLogs = const [],
    this.version = 0,
    this.paidAt,
    this.requestType = 'reimbursement',
    this.settlementAmount,
    this.settlementMethod,
    this.settlementNote,
    this.settlementDate,
  });

  bool get isPending => status == RequestStatus.pending;
  bool get isApproved => status == RequestStatus.approved;
  bool get isRejected => status == RequestStatus.rejected;
  bool get isPaid => status == RequestStatus.paid;
  bool get isPendingSettlement => status == RequestStatus.pendingSettlement;
  bool get isSettled => status == RequestStatus.settled;
  // Settlement is a later stage of an already disbursed payment.
  bool get hasDisbursement => isPaid || isPendingSettlement || isSettled;
  bool get needsFinanceReview => isPending || isPendingSettlement;
  double get disbursedAmount => hasDisbursement ? amount : 0;
  double get verifiedExpense => !hasDisbursement
      ? 0
      : (isAdvance ? (isSettled ? settlementAmount ?? 0 : 0) : amount);
  double get verifiedReturn =>
      isAdvance && isSettled ? amount - (settlementAmount ?? amount) : 0;
  double get outstandingAdvance =>
      isAdvance && hasDisbursement && !isSettled ? (amount - (settlementAmount ?? 0)) : 0;
  static const overrideStatuses = [
    RequestStatus.pending,
    RequestStatus.approved,
    RequestStatus.rejected,
    RequestStatus.paid,
  ];
  bool get isAdvance => requestType == 'advance';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'version': version,
      'paidAt': paidAt?.toUtc().toIso8601String(),
      'requestedBy': requestedBy,
      'requesterName': requesterName,
      'requesterEmail': requesterEmail,
      'itemDescription': itemDescription,
      'amount': amount,
      'reason': reason,
      'billImageUrl': billImageUrl,
      'status': status.displayName,
      'rejectionReason': rejectionReason,
      'reviewedBy': reviewedBy,
      'reviewedByName': reviewedByName,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'auditLogs': auditLogs.map((e) => e.toMap()).toList(),
      'request_type': requestType,
      'settlement_amount': settlementAmount,
      'settlement_method': settlementMethod,
      'settlement_note': settlementNote,
      'settlement_date': settlementDate?.toUtc().toIso8601String(),
    };
  }

  factory ExpenseRequest.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parseDate(dynamic val) {
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    double parseAmount(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    return ExpenseRequest(
      id: (map['id'] ?? docId ?? '').toString(),
      version: (map['version'] as num?)?.toInt() ?? 0,
      paidAt: map['paidAt'] == null ? null : parseDate(map['paidAt']),
      requestedBy: (map['requestedBy'] ?? '').toString(),
      requesterName: (map['requesterName'] ?? 'Staff Member').toString(),
      requesterEmail: (map['requesterEmail'] ?? '').toString(),
      itemDescription: (map['itemDescription'] ?? '').toString(),
      amount: parseAmount(map['amount']),
      reason: (map['reason'] ?? '').toString(),
      billImageUrl: map['billImageUrl']?.toString(),
      status: RequestStatus.fromString(map['status']?.toString()),
      rejectionReason: map['rejectionReason']?.toString(),
      reviewedBy: map['reviewedBy']?.toString(),
      reviewedByName: map['reviewedByName']?.toString(),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      auditLogs: map['auditLogs'] != null
          ? (map['auditLogs'] as List)
                .map((e) => AuditLogEntry.fromMap(Map<String, dynamic>.from(e)))
                .toList()
          : [],
      requestType: map['request_type']?.toString() ?? 'reimbursement',
      settlementAmount: map['settlement_amount'] != null
          ? parseAmount(map['settlement_amount'])
          : null,
      settlementMethod: map['settlement_method']?.toString(),
      settlementNote: map['settlement_note']?.toString(),
      settlementDate: map['settlement_date'] == null
          ? null
          : parseDate(map['settlement_date']),
    );
  }

  ExpenseRequest copyWith({
    String? id,
    String? requestedBy,
    String? requesterName,
    String? requesterEmail,
    String? itemDescription,
    double? amount,
    String? reason,
    String? billImageUrl,
    RequestStatus? status,
    Object? rejectionReason = _unchanged,
    String? reviewedBy,
    String? reviewedByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AuditLogEntry>? auditLogs,
    String? requestType,
    Object? settlementAmount = _unchanged,
    Object? settlementMethod = _unchanged,
    Object? settlementNote = _unchanged,
    Object? settlementDate = _unchanged,
  }) {
    return ExpenseRequest(
      id: id ?? this.id,
      requestedBy: requestedBy ?? this.requestedBy,
      requesterName: requesterName ?? this.requesterName,
      requesterEmail: requesterEmail ?? this.requesterEmail,
      itemDescription: itemDescription ?? this.itemDescription,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      billImageUrl: billImageUrl ?? this.billImageUrl,
      status: status ?? this.status,
      rejectionReason: identical(rejectionReason, _unchanged)
          ? this.rejectionReason
          : rejectionReason as String?,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedByName: reviewedByName ?? this.reviewedByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      auditLogs: auditLogs ?? this.auditLogs,
      version: version,
      paidAt: paidAt,
      requestType: requestType ?? this.requestType,
      settlementAmount: identical(settlementAmount, _unchanged)
          ? this.settlementAmount
          : settlementAmount as double?,
      settlementMethod: identical(settlementMethod, _unchanged)
          ? this.settlementMethod
          : settlementMethod as String?,
      settlementNote: identical(settlementNote, _unchanged)
          ? this.settlementNote
          : settlementNote as String?,
      settlementDate: identical(settlementDate, _unchanged)
          ? this.settlementDate
          : settlementDate as DateTime?,
    );
  }
}

class AuditLogEntry {
  final DateTime timestamp;
  final String action; // e.g. "Created", "Status changed to Approved", "Status changed to Paid"
  final String performerId;
  final String performerName;
  final String? notes; // e.g. rejection reason

  AuditLogEntry({
    required this.timestamp,
    required this.action,
    required this.performerId,
    required this.performerName,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toUtc().toIso8601String(),
      'action': action,
      'performerId': performerId,
      'performerName': performerName,
      'notes': notes,
    };
  }

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return AuditLogEntry(
      timestamp: parseDate(map['timestamp']),
      action: map['action']?.toString() ?? 'Unknown Action',
      performerId: map['performerId']?.toString() ?? '',
      performerName: map['performerName']?.toString() ?? 'Unknown User',
      notes: map['notes']?.toString(),
    );
  }
}
