import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final ImagePicker _picker = ImagePicker();

  SupabaseClient? get _client => SupabaseService().client;

  // Pick image from camera or gallery
  Future<XFile?> pickReceiptImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      return file;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  // Upload image bytes to Supabase Storage or generate a Data URI for immediate display
  Future<String> uploadReceiptImage({
    required Uint8List imageBytes,
    required String fileName,
    String? mimeType,
  }) async {
    final client = _client;
    if (client != null) {
      try {
        final filePath = 'receipts/$fileName';
        final detectedMime = mimeType ?? 'image/jpeg';
        
        await client.storage.from('receipts').uploadBinary(
              filePath,
              imageBytes,
              fileOptions: FileOptions(contentType: detectedMime),
            );

        final publicUrl = client.storage.from('receipts').getPublicUrl(filePath);
        return publicUrl;
      } catch (e) {
        debugPrint('Supabase Storage upload failed: $e. Returning Data URI fallback.');
      }
    }

    // Fallback: Convert to Base64 Data URI so it immediately displays everywhere
    final base64String = base64Encode(imageBytes);
    final detectedMime = mimeType ?? 'image/jpeg';
    return 'data:$detectedMime;base64,$base64String';
  }

  // Sample Receipt Templates for Quick 1-Click Testing
  static const List<Map<String, String>> sampleBills = [
    {
      'title': 'Office Supplies Receipt',
      'url': 'https://images.unsplash.com/photo-1586075010923-2dd4570fb338?w=800&auto=format&fit=crop&q=60',
    },
    {
      'title': 'Coffee & Pantry Bill',
      'url': 'https://images.unsplash.com/photo-1554415707-9e43ecb67ff6?w=800&auto=format&fit=crop&q=60',
    },
    {
      'title': 'Maintenance Invoice',
      'url': 'https://images.unsplash.com/photo-1513506003901-1e6a229e2d15?w=800&auto=format&fit=crop&q=60',
    },
  ];
}
