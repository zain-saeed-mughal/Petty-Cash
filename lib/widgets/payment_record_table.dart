import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class PaymentRecordColumn<T> {
  final String label;
  final int flex;
  final Widget Function(BuildContext context, T record) cell;

  const PaymentRecordColumn({
    required this.label,
    required this.cell,
    this.flex = 2,
  });
}

/// A searchable comparison table that stays aligned and scrollable on phones.
class PaymentRecordTable<T> extends StatefulWidget {
  final String tableId;
  final List<T> records;
  final List<PaymentRecordColumn<T>> columns;
  final String Function(T record) idOf;
  final String Function(T record) searchOf;
  final String Function(T record) statusOf;
  final String Function(String status) statusLabel;
  final Widget Function(BuildContext context, T record) details;
  final String searchHint;
  final String statusHint;
  final String allStatusesLabel;
  final String recordsLabel;
  final String noMatchesLabel;
  final String detailsLabel;
  final String showMoreLabel;

  const PaymentRecordTable({
    super.key,
    required this.tableId,
    required this.records,
    required this.columns,
    required this.idOf,
    required this.searchOf,
    required this.statusOf,
    required this.statusLabel,
    required this.details,
    required this.searchHint,
    required this.statusHint,
    required this.allStatusesLabel,
    required this.recordsLabel,
    required this.noMatchesLabel,
    required this.detailsLabel,
    required this.showMoreLabel,
  });

  @override
  State<PaymentRecordTable<T>> createState() => _PaymentRecordTableState<T>();
}

class _PaymentRecordTableState<T> extends State<PaymentRecordTable<T>> {
  String _query = '';
  String? _status;
  final Set<String> _expanded = {};
  int _limit = 20;

  void _toggle(String id) {
    setState(() {
      if (!_expanded.add(id)) _expanded.remove(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final statuses = widget.records.map(widget.statusOf).toSet().toList()
      ..sort();
    final selectedStatus = statuses.contains(_status) ? _status : null;
    final query = _query.trim().toLowerCase();
    final filtered = widget.records.where((record) {
      return (selectedStatus == null ||
              widget.statusOf(record) == selectedStatus) &&
          (query.isEmpty ||
              widget.searchOf(record).toLowerCase().contains(query));
    }).toList();
    final shown = filtered.take(_limit).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        gradient: isDark
            ? null
            : const LinearGradient(
                colors: [Colors.white, Color(0xFFF7F9FE)],
              ),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : AppTheme.borderLight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark ? null : AppTheme.premiumShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >= 760 &&
              MediaQuery.sizeOf(context).width >= 760;
          final search = TextField(
            key: ValueKey('${widget.tableId}-search'),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: widget.searchHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() {
              _query = value;
              _limit = 20;
            }),
          );
          final statusFilter = DropdownButtonFormField<String>(
            key: ValueKey(
              '${widget.tableId}-status-${selectedStatus ?? 'all'}-${statuses.join('|')}',
            ),
            initialValue: selectedStatus ?? '',
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              labelText: widget.statusHint,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: '', child: Text(widget.allStatusesLabel)),
              for (final status in statuses)
                DropdownMenuItem(
                  value: status,
                  child: Text(
                    widget.statusLabel(status),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() {
              _status = value == null || value.isEmpty ? null : value;
              _limit = 20;
            }),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                Row(
                  children: [
                    Expanded(flex: 3, child: search),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: statusFilter),
                  ],
                )
              else ...[
                search,
                const SizedBox(height: 10),
                statusFilter,
              ],
              const SizedBox(height: 12),
              Text(
                '${filtered.length} ${widget.recordsLabel}',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      widget.noMatchesLabel,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                )
              else if (wide)
                _tableRows(context, shown, isDark)
              else
                Column(
                  children: [
                    for (var index = 0; index < shown.length; index++)
                      _mobileRecord(context, shown[index], index, isDark),
                  ],
                ),
              if (filtered.length > shown.length)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _limit += 20),
                      icon: const Icon(Icons.expand_more_rounded),
                      label: Text(widget.showMoreLabel),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showRecordModal(BuildContext context, T record) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.detailsLabel,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.primaryNavy,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(ctx),
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (final col in widget.columns)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                col.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              Flexible(
                                child: col.cell(context, record),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                widget.details(context, record),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleRecordTap(BuildContext context, T record) {
    _toggle(widget.idOf(record));
    _showRecordModal(context, record);
  }

  Widget _header(BuildContext context, bool isDark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEAF1FD),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        for (final column in widget.columns)
          Expanded(
            flex: column.flex,
            child: Text(
              column.label,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF344766),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        const SizedBox(width: 32),
      ],
    ),
  );

  Widget _tableRows(BuildContext context, List<T> records, bool isDark) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _header(context, isDark),
      for (var index = 0; index < records.length; index++)
        _record(context, records[index], index, isDark),
    ],
  );

  Widget _record(BuildContext context, T record, int index, bool isDark) {
    final id = widget.idOf(record);
    final expanded = _expanded.contains(id);
    final rowBg = index.isEven
        ? (isDark ? const Color(0xFF1E293B) : Colors.white)
        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFD));
    return Column(
      key: ValueKey('${widget.tableId}-$id'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: rowBg,
          child: InkWell(
            onTap: () => _handleRecordTap(context, record),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              child: Row(
                children: [
                  for (final column in widget.columns)
                    Expanded(
                      flex: column.flex,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: column.cell(context, record),
                      ),
                    ),
                  SizedBox(
                    width: 32,
                    child: Tooltip(
                      message: widget.detailsLabel,
                      child: Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.visibility_outlined,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: widget.details(context, record),
          ),
        Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE5EAF2)),
      ],
    );
  }

  Widget _mobileRecord(BuildContext context, T record, int index, bool isDark) {
    final id = widget.idOf(record);
    final expanded = _expanded.contains(id);
    final cardBg = index.isEven
        ? (isDark ? const Color(0xFF1E293B) : Colors.white)
        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFD));
    return Column(
      key: ValueKey('${widget.tableId}-$id'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: cardBg,
          child: InkWell(
            onTap: () => _handleRecordTap(context, record),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Table(
                    columnWidths: const {
                      0: FixedColumnWidth(92),
                      1: FlexColumnWidth(),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      for (final column in widget.columns)
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Text(
                                column.label,
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: column.cell(context, record),
                            ),
                          ],
                        ),
                    ],
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.detailsLabel,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.visibility_outlined,
                          color: AppTheme.primaryBlue,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: widget.details(context, record),
          ),
        Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE5EAF2)),
      ],
    );
  }
}
