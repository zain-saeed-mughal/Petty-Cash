import sys

def process(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Add lang provider inside build if missing
    if "final lang = Provider.of<LanguageProvider>(context);" not in content:
        content = content.replace(
            "  Widget build(BuildContext context) {",
            "  Widget build(BuildContext context) {\n    final lang = Provider.of<LanguageProvider>(context);"
        )
    # Add to _buildHistoryCard
    if "final lang = Provider.of<LanguageProvider>(context);" not in content.split("  Widget _buildHistoryCard(ExpenseRequest req) {")[1]:
        content = content.replace(
            "  Widget _buildHistoryCard(ExpenseRequest req) {",
            "  Widget _buildHistoryCard(ExpenseRequest req) {\n    final lang = Provider.of<LanguageProvider>(context, listen: false);"
        )

    # 2. Add language provider import
    if "import '../../providers/language_provider.dart';" not in content:
        content = content.replace(
            "import '../../providers/expense_provider.dart';",
            "import '../../providers/expense_provider.dart';\nimport '../../providers/language_provider.dart';"
        )

    # 3. Replace strings
    content = content.replace(
        "const Text(\n                                  'Total Settled / Paid',",
        "Text(\n                                  lang.tr('total_settled_paid'),"
    )
    content = content.replace(
        "const Text(\n                                  'Settled Transactions',",
        "Text(\n                                  lang.tr('settled_transactions'),"
    )
    content = content.replace(
        "'${expense.approvedCount} approved / ${expense.rejectedCount} rejected'",
        "'${expense.approvedCount}${lang.tr('approved_word')}${expense.rejectedCount}${lang.tr('rejected_word')}'"
    )
    content = content.replace(
        "hintText: 'Search history by requester, description, or reason...',",
        "hintText: lang.tr('search_history'),"
    )
    content = content.replace(
        "_buildFilterChip('All Settled', null),",
        "_buildFilterChip(lang.tr('all_settled'), null),"
    )
    content = content.replace(
        "_buildFilterChip(\n                                  'Paid / Approved',",
        "_buildFilterChip(\n                                  lang.tr('paid_approved'),"
    )
    content = content.replace(
        "_buildFilterChip(\n                                  'Rejected',",
        "_buildFilterChip(\n                                  lang.tr('rejected'),"
    )
    content = content.replace(
        "const Text(\n                      'No Payment Records Found',",
        "Text(\n                      lang.tr('no_payment_records'),"
    )
    content = content.replace(
        "const Text(\n                      'Approved and rejected requests will appear here.',",
        "Text(\n                      lang.tr('approved_rejected_appear'),"
    )
    content = content.replace(
        "'Purpose: ${req.reason}'",
        "'${lang.tr('purpose_prefix')}${req.reason}'"
    )
    content = content.replace(
        "'Reason: ${req.rejectionReason}'",
        "'${lang.tr('reason_prefix')}${req.rejectionReason}'"
    )
    content = content.replace(
        "const Text('View Receipt')",
        "Text(lang.tr('view_receipt'))"
    )
    content = content.replace(
        "const Text('Review Detail')",
        "Text(lang.tr('review_detail'))"
    )

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done")

process(sys.argv[1])
