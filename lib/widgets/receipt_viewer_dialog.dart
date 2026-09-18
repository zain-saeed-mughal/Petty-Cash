import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_theme.dart';

class ReceiptViewerDialog extends StatelessWidget {
  final String imageUrl;
  final String title;

  const ReceiptViewerDialog({
    super.key,
    required this.imageUrl,
    this.title = 'Bill / Receipt Inspection',
  });

  static void show(BuildContext context, {required String imageUrl, String title = 'Bill / Receipt Inspection'}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ReceiptViewerDialog(imageUrl: imageUrl, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBase64 = imageUrl.startsWith('data:image');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 850),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryNavy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Interactive Zoomable Image
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  child: Container(
                    color: const Color(0xFF0F172A),
                    width: double.infinity,
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Center(
                        child: isBase64
                            ? Image.memory(
                                base64Decode(imageUrl.split(',').last),
                                fit: BoxFit.contain,
                                errorBuilder: (ctx, err, stack) => _errorPlaceholder(),
                              )
                            : CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(color: Colors.white),
                                ),
                                errorWidget: (context, url, error) => _errorPlaceholder(),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.broken_image_rounded, size: 64, color: Colors.white60),
        SizedBox(height: 12),
        Text(
          'Unable to load receipt image preview',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}
