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
    # Add to _buildPendingCard
    if "final lang = Provider.of<LanguageProvider>(context);" not in content.split("  Widget _buildPendingCard(ExpenseRequest req) {")[1]:
        content = content.replace(
            "  Widget _buildPendingCard(ExpenseRequest req) {",
            "  Widget _buildPendingCard(ExpenseRequest req) {\n    final lang = Provider.of<LanguageProvider>(context, listen: false);"
        )

    # 2. Add language provider import
    if "import '../../providers/language_provider.dart';" not in content:
        content = content.replace(
            "import '../../providers/expense_provider.dart';",
            "import '../../providers/expense_provider.dart';\nimport '../../providers/language_provider.dart';"
        )

    # 3. Replace strings
    content = content.replace(
        "const Text(\n                                  'Pending Expense Queue',",
        "Text(\n                                  lang.tr('pending_expense_queue'),"
    )
    content = content.replace(
        "'${expense.pendingCount} requests awaiting verification • Total Pending: ${AppConstants.defaultCurrencySymbol}${expense.pendingAmount.toStringAsFixed(2)}'",
        "'${expense.pendingCount}${lang.tr('requests_awaiting_verification')}${AppConstants.defaultCurrencySymbol}${expense.pendingAmount.toStringAsFixed(2)}'"
    )
    content = content.replace(
        "hintText: 'Search by requester name, item description, or reason...',",
        "hintText: lang.tr('search_pending'),"
    )
    content = content.replace(
        "const Text(\n                      'All Caught Up!',",
        "Text(\n                      lang.tr('all_caught_up'),"
    )
    content = content.replace(
        "const Text(\n                      'There are currently no pending expense requests waiting for review.',",
        "Text(\n                      lang.tr('no_pending_requests'),"
    )
    content = content.replace(
        "'Purpose: ${req.reason}'",
        "'${lang.tr('purpose_prefix')}${req.reason}'"
    )
    content = content.replace(
        "'Receipt attached'",
        "lang.tr('receipt_attached')"
    )
    content = content.replace(
        "'No bill image'",
        "lang.tr('no_bill_image')"
    )
    content = content.replace(
        "Text('Review & Decide')",
        "Text(lang.tr('review_and_decide'))"
    )

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done")

process(sys.argv[1])
