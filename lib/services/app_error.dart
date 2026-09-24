import 'package:supabase_flutter/supabase_flutter.dart';

String userMessage(Object error) {
  if(error is PostgrestException) return error.message;
  if(error is AuthException) return error.message;
  final text=error.toString().replaceFirst(RegExp(r'^(Exception|Bad state):\s*'),'');
  if(text.contains('SocketException') || text.contains('ClientException') || text.contains('Failed to fetch')) {
    return 'Connection unavailable. Check your internet and try again.';
  }
  return text;
}

