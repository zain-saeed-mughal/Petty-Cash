enum RequestStatus {
  pending,
  approved,
  rejected,
  paid;

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
  });

  bool get isPending => status == RequestStatus.pending;
  bool get isApproved => status == RequestStatus.approved;
  bool get isRejected => status == RequestStatus.rejected;
  bool get isPaid => status == RequestStatus.paid;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'auditLogs': auditLogs.map((e) => e.toMap()).toList(),
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
    String? rejectionReason,
    String? reviewedBy,
    String? reviewedByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AuditLogEntry>? auditLogs,
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
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedByName: reviewedByName ?? this.reviewedByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      auditLogs: auditLogs ?? this.auditLogs,
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
      'timestamp': timestamp.toIso8601String(),
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
