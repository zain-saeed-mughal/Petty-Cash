import 'package:supabase_flutter/supabase_flutter.dart';

String accountServiceMessage(int status, dynamic details) {
  if (status == 404) {
    return 'Account management is not deployed. Deploy the manage-user server function and try again.';
  }
  if (status == 401) return 'Your session expired. Sign out and sign in again.';
  dynamic message = details;
  if (message is Map) message = message['error'] ?? message['message'];
  if (message is Map) message = message['message'];
  if (message is String &&
      message.trim().isNotEmpty &&
      message != 'Exception') {
    return message;
  }
  if (status == 403) {
    return 'You do not have permission to manage this account.';
  }
  return 'The account could not be saved. Please try again.';
}

String userMessage(Object error) {
  if (error is PostgrestException) return error.message;
  if (error is AuthException) return error.message;
  final text = error.toString().replaceFirst(
    RegExp(r'^(Exception|Bad state):\s*'),
    '',
  );
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed to fetch')) {
    return 'Connection unavailable. Check your internet and try again.';
  }
  return text;
}
