import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _isSupabaseAvailable = false;

  String get projectUrl => _supabaseUrl;
  bool get isSupabaseAvailable => _isSupabaseAvailable;

  // The publishable key is public; a deployment may override these values.
  static const String _supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://203.215.164.70:8000',
  );
  static const String _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzI5MDAwMDAwLCJleHAiOjIzNjAwMDAwMDB9.g3LJYmuIXr9DJJAN7bJto9ichdHDk3kEf5BCZ12xL7o',
  );

  Future<void> initialize() async {
    if (_isSupabaseAvailable) return;
    try {
      if (_supabaseUrl == 'YOUR_SUPABASE_URL' || _supabaseUrl.isEmpty) {
        debugPrint('Supabase credentials are not configured.');
        _isSupabaseAvailable = false;
        return;
      }

      await Supabase.initialize(
        url: _supabaseUrl,
        publishableKey: _supabaseAnonKey,
      );
      _isSupabaseAvailable = true;
      debugPrint('Supabase initialized successfully.');
    } catch (e) {
      debugPrint('Supabase initialization failed ($e).');
      _isSupabaseAvailable = false;
      rethrow;
    }
  }

  SupabaseClient? get client {
    if (_isSupabaseAvailable) {
      return Supabase.instance.client;
    }
    return null;
  }
}
