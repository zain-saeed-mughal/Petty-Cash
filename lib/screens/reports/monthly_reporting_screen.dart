import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/expense_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/expense_request_model.dart';
import '../../models/user_model.dart';
import '../../config/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../finance/request_detail_screen.dart';

class MonthlyReportingScreen extends StatefulWidget {
  const MonthlyReportingScreen({super.key});

  @override
  State<MonthlyReportingScreen> createState() => _MonthlyReportingScreenState();
}

class _MonthlyReportingScreenState extends State<MonthlyReportingScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedUserId;
  RequestStatus? _selectedStatus;
  
  final DateFormat _monthFormat = DateFormat('MMMM yyyy');
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  void _previousMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final expense = Provider.of<ExpenseProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    
    // Filter requests for selected month
    final currentMonthRequests = expense.allRequests.where((r) => 
      r.createdAt.year == _selectedDate.year && 
      r.createdAt.month == _selectedDate.month
    ).toList();

    // Filter requests for previous month for comparison
    final previousMonth = DateTime(_selectedDate.year, _selectedDate.month - 1);
    final prevMonthRequests = expense.allRequests.where((r) => 
      r.createdAt.year == previousMonth.year && 
      r.createdAt.month == previousMonth.month
    ).toList();

    // Apply User & Status filters
    final filteredRequests = currentMonthRequests.where((r) {
      if (_selectedUserId != null && _selectedUserId != 'ALL' && r.requestedBy != _selectedUserId) return false;
      if (_selectedStatus != null && r.status != _selectedStatus) return false;
      return true;
    }).toList();

    // KPIs
    int totalSubmitted = currentMonthRequests.length;
    int pendingCount = currentMonthRequests.where((r) => r.isPending).length;
    int rejectedCount = currentMonthRequests.where((r) => r.isRejected).length;

    double totalPaidAmount = currentMonthRequests.where((r) => r.isPaid).fold(0.0, (sum, r) => sum + r.amount);
    double prevMonthPaidAmount = prevMonthRequests.where((r) => r.isPaid).fold(0.0, (sum, r) => sum + r.amount);

    double growth = 0;
    if (prevMonthPaidAmount > 0) {
      growth = ((totalPaidAmount - prevMonthPaidAmount) / prevMonthPaidAmount) * 100;
    }

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(isDesktop ? 32 : 16),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    const Text(
                      'Monthly Reports',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryNavy,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Detailed breakdown and audit of petty cash requests by month.',
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 24),

                    // Filter Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderLight, width: 0.5),
                        boxShadow: AppTheme.premiumShadow,
                      ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Month Selector
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _previousMonth,
                        ),
                        Text(
                          _monthFormat.format(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _nextMonth,
                        ),
                      ],
                    ),
                    Container(height: 24, width: 1, color: Colors.grey.shade300),
                    // User Filter
                    DropdownButton<String>(
                      value: _selectedUserId,
                      hint: const Text('All Users'),
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem(value: 'ALL', child: Text('All Users')),
                        ...userProvider.allUsers.where((u) {
                          final authUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
                          if (authUser?.isFinance == true) {
                            return u.role == UserRole.officeBoy;
                          }
                          if (authUser?.isAdmin == true) {
                            return u.role == UserRole.officeBoy || u.role == UserRole.finance;
                          }
                          return true; // Super Admin sees all
                        }).map((u) => 
                          DropdownMenuItem(value: u.uid, child: Text(u.name))
                        ),
                      ],
                      onChanged: (val) => setState(() => _selectedUserId = val),
                    ),
                    Container(height: 24, width: 1, color: Colors.grey.shade300),
                    // Status Filter
                    DropdownButton<RequestStatus?>(
                      value: _selectedStatus,
                      hint: const Text('All Statuses'),
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Statuses')),
                        ...RequestStatus.values.map((s) => 
                          DropdownMenuItem(value: s, child: Text(s.displayName))
                        ),
                      ],
                      onChanged: (val) => setState(() => _selectedStatus = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // KPIs
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = isDesktop ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.2,
                    children: [
                      _buildKpiCard('Total Paid (PKR)', 'Rs. ${totalPaidAmount.toStringAsFixed(2)}', Icons.payments, Colors.teal, growth),
                      _buildKpiCard('Submitted', totalSubmitted.toString(), Icons.receipt, Colors.blue, null),
                      _buildKpiCard('Pending', pendingCount.toString(), Icons.pending, Colors.orange, null),
                      _buildKpiCard('Rejected', rejectedCount.toString(), Icons.cancel, Colors.red, null),
                    ],
                  );
                }
              ),
              const SizedBox(height: 32),

              // Data Table
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderLight, width: 0.5),
                  boxShadow: AppTheme.premiumShadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppTheme.primaryNavy),
                      headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      showCheckboxColumn: false,
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('Requester')),
                        DataColumn(label: Text('Item')),
                        DataColumn(label: Text('Amount')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: filteredRequests.map((req) {
                        return DataRow(
                          onSelectChanged: (_) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RequestDetailScreen(request: req),
                              ),
                            );
                          },
                          cells: [
                            DataCell(Text(_dateFormat.format(req.createdAt))),
                            DataCell(Text(req.id, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(req.requesterName)),
                            DataCell(Text(req.itemDescription)),
                            DataCell(Text('Rs. ${req.amount.toStringAsFixed(2)}')),
                            DataCell(StatusBadge(status: req.status)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
],
);
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, double? growth) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight, width: 0.5),
        boxShadow: AppTheme.premiumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                  ),
                ),
              ),
              if (growth != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${growth > 0 ? '+' : ''}${growth.toStringAsFixed(1)}% vs prev month',
                  style: TextStyle(
                    fontSize: 11,
                    color: growth >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }
}
