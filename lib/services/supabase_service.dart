import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _isSupabaseAvailable = false;

  bool get isSupabaseAvailable => _isSupabaseAvailable;

  // Placeholder credentials. Update these with real values when deploying.
  static const String _supabaseUrl = 'https://ysrwvlminsuvwswgpuhh.supabase.co';
  static const String _supabaseAnonKey = 'sb_publishable_6puU1eZ4bgDCZjSQWeDdMg_xs27lGMz';

  Future<void> initialize() async {
    try {
      if (_supabaseUrl == 'YOUR_SUPABASE_URL' || _supabaseUrl.isEmpty) {
        debugPrint('Supabase credentials not configured. Falling back to Demo/Offline Mode.');
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
      debugPrint('Supabase initialization failed ($e). Falling back to Demo/Offline Mode.');
      _isSupabaseAvailable = false;
    }
  }

  SupabaseClient? get client {
    if (_isSupabaseAvailable) {
      return Supabase.instance.client;
    }
    return null;
  }
}
