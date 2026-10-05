import 'package:flutter/material.dart';

import '../models/expense_request_model.dart';
import 'app_status_badge.dart';

class StatusBadge extends StatelessWidget {
  final RequestStatus status;
  final bool isCompact;

  const StatusBadge({super.key, required this.status, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    return AppStatusBadge(
      status: status.name,
      isCompact: isCompact,
    );
  }
}
