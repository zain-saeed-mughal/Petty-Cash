import 'package:uuid/uuid.dart';

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final bool isRead;
  final String? relatedRequestId;
  final String? relatedAdvanceId;
  final String? relatedExpenseId;
  final String? relatedAdvanceRequestId;
  final String? relatedCoreAdvanceId;
  final String? relatedReimbursementId;
  final DateTime createdAt;

  AppNotification({
    String? id,
    required this.userId,
    required this.title,
    required this.message,
    this.isRead = false,
    this.relatedRequestId,
    this.relatedAdvanceId,
    this.relatedExpenseId,
    this.relatedAdvanceRequestId,
    this.relatedCoreAdvanceId,
    this.relatedReimbursementId,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'is_read': isRead,
      'related_request_id': relatedRequestId,
      'related_advance_id': relatedAdvanceId,
      'related_expense_id': relatedExpenseId,
      'related_advance_request_id': relatedAdvanceRequestId,
      'related_core_advance_id': relatedCoreAdvanceId,
      'related_reimbursement_id': relatedReimbursementId,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map, {String? docId}) {
    return AppNotification(
      id: docId ?? map['id'] ?? const Uuid().v4(),
      userId: map['user_id'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      isRead: map['is_read'] ?? false,
      relatedRequestId: map['related_request_id'],
      relatedAdvanceId: map['related_advance_id'],
      relatedExpenseId: map['related_expense_id'],
      relatedAdvanceRequestId: map['related_advance_request_id'],
      relatedCoreAdvanceId: map['related_core_advance_id'],
      relatedReimbursementId: map['related_reimbursement_id'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }
}
