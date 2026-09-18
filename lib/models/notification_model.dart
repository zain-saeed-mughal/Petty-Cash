import 'package:uuid/uuid.dart';

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final bool isRead;
  final String? relatedRequestId;
  final DateTime createdAt;

  AppNotification({
    String? id,
    required this.userId,
    required this.title,
    required this.message,
    this.isRead = false,
    this.relatedRequestId,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'is_read': isRead,
      'related_request_id': relatedRequestId,
      'created_at': createdAt.toIso8601String(),
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
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : DateTime.now(),
    );
  }
}
