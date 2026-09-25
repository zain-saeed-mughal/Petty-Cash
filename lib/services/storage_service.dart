import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'supabase_service.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();
  final ImagePicker _picker = ImagePicker();
  static const int maxUploadBytes = 10 * 1024 * 1024;
  SupabaseClient get _client =>
      SupabaseService().client ??
      (throw StateError('Receipt storage is unavailable. Try again.'));
  Future<XFile?> pickReceiptImage({ImageSource source = ImageSource.gallery}) =>
      _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
  static String imageMime(Uint8List b) {
    if (b.length >= 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff) {
      return 'image/jpeg';
    }
    if (b.length >= 8 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4e &&
        b[3] == 0x47) {
      return 'image/png';
    }
    if (b.length >= 12 &&
        String.fromCharCodes(b.take(4)) == 'RIFF' &&
        String.fromCharCodes(b.skip(8).take(4)) == 'WEBP') {
      return 'image/webp';
    }
    throw const FormatException('Choose a JPEG, PNG or WebP receipt image.');
  }

  Future<String> uploadReceiptImage({
    required Uint8List imageBytes,
    required String fileName,
    String? mimeType,
  }) async {
    if (imageBytes.isEmpty || imageBytes.length > maxUploadBytes) {
      throw StateError('Choose a receipt image under 10 MB.');
    }
    final client = _client, uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Sign in before uploading a receipt.');
    final mime = imageMime(imageBytes);
    final ext = mime == 'image/jpeg' ? 'jpg' : mime.split('/').last;
    final path = '$uid/${const Uuid().v4()}.$ext';
    await client.storage
        .from('receipts')
        .uploadBinary(
          path,
          imageBytes,
          fileOptions: FileOptions(contentType: mime),
        );
    return path; // Persist the path; signed access is generated only when viewing.
  }

  Future<void> removeUnusedReceipt(String path) async {
    await _client.storage.from('receipts').remove([path]);
  }

  String? objectPath(String reference) {
    final uri = Uri.tryParse(reference);
    if (uri == null) return null;
    if (!uri.hasScheme) return reference;
    final base = Uri.parse(SupabaseService().projectUrl);
    if (uri.host != base.host) return null;
    for (final prefix in [
      '/storage/v1/object/sign/receipts/',
      '/storage/v1/object/public/receipts/',
      '/storage/v1/object/authenticated/receipts/',
    ]) {
      if (uri.path.startsWith(prefix)) {
        return Uri.decodeComponent(uri.path.substring(prefix.length));
      }
    }
    return null;
  }

  Future<String> resolveReceipt(String reference) async {
    if (reference.startsWith('data:image/')) return reference;
    final path = objectPath(reference);
    if (path == null) return reference;
    return _client.storage.from('receipts').createSignedUrl(path, 900);
  }

  static const List<Map<String, String>> sampleBills = [];
}
