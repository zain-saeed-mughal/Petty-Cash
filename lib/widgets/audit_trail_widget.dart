import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/expense_request_model.dart';
import '../config/app_theme.dart';

class AuditTrailWidget extends StatelessWidget {
  final List<AuditLogEntry> auditLogs;

  const AuditTrailWidget({super.key, required this.auditLogs});

  @override
  Widget build(BuildContext context) {
    if (auditLogs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No audit logs available.',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }

    // Sort logs so most recent is at top, or keep chronological? Let's keep chronological top-to-bottom.
    final sortedLogs = List<AuditLogEntry>.from(auditLogs)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Audit Trail',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryNavy,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedLogs.length,
          itemBuilder: (context, index) {
            final log = sortedLogs[index];
            final isLast = index == sortedLogs.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Timeline line & dot
                  SizedBox(
                    width: 40,
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(top: 24),
                          decoration: BoxDecoration(
                            color: _getLogColor(log.action),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: Colors.grey.shade300,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Content card
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 16,
                        bottom: 8,
                        right: 16,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    log.action,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Text(
                                  DateFormat('MMM dd, hh:mm a')
                                      .format(log.timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'By: ${log.performerName}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            if (log.notes != null && log.notes!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.amber.shade200,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.note_alt_outlined,
                                      size: 16,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        log.notes!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Color _getLogColor(String action) {
    if (action.toLowerCase().contains('created')) return Colors.blue;
    if (action.toLowerCase().contains('approved')) return Colors.green;
    if (action.toLowerCase().contains('paid')) return Colors.teal;
    if (action.toLowerCase().contains('rejected')) return Colors.red;
    return Colors.grey;
  }
}
