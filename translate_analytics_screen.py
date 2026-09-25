import sys

def process(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replacements
    content = content.replace(
        "const Text(\n                      'Financial Analytics & Reports',",
        "Text(\n                      Provider.of<LanguageProvider>(context).tr('financial_analytics_reports'),"
    )
    content = content.replace(
        "const Text(\n                      'Real-time overview of petty cash outflows, approvals, and queue bottlenecks',",
        "Text(\n                      Provider.of<LanguageProvider>(context).tr('financial_analytics_sub'),"
    )
    content = content.replace(
        "title: 'TOTAL DISBURSED',",
        "title: Provider.of<LanguageProvider>(context).tr('total_disbursed'),"
    )
    content = content.replace(
        "subtitle: '$approvedCount approved payments',",
        "subtitle: '$approvedCount${Provider.of<LanguageProvider>(context).tr('approved_payments_suffix')}',"
    )
    content = content.replace(
        "title: 'PENDING QUEUE',",
        "title: Provider.of<LanguageProvider>(context).tr('pending_queue'),"
    )
    content = content.replace(
        "subtitle: '$pendingCount requests awaiting review',",
        "subtitle: '$pendingCount${Provider.of<LanguageProvider>(context).tr('requests_awaiting_review')}',"
    )
    content = content.replace(
        "title: 'APPROVAL RATE',",
        "title: Provider.of<LanguageProvider>(context).tr('approval_rate'),"
    )
    content = content.replace(
        "subtitle: '$approvedCount of ${approvedCount + rejectedCount} reviewed',",
        "subtitle: '$approvedCount${Provider.of<LanguageProvider>(context).tr('of_reviewed')} ${approvedCount + rejectedCount}',"
    )
    content = content.replace(
        "title: 'REJECTION COUNT',",
        "title: Provider.of<LanguageProvider>(context).tr('rejection_count'),"
    )
    content = content.replace(
        "subtitle: 'Returned to requester',",
        "subtitle: Provider.of<LanguageProvider>(context).tr('returned_to_requester'),"
    )
    content = content.replace(
        "'Request Status Distribution'",
        "Provider.of<LanguageProvider>(context).tr('req_status_dist')"
    )
    content = content.replace(
        "'Proportion of approved, pending, and rejected requests'",
        "Provider.of<LanguageProvider>(context).tr('req_status_dist_sub')"
    )
    content = content.replace(
        "const Center(child: Text('No request data available'))",
        "Center(child: Text(Provider.of<LanguageProvider>(context).tr('no_req_data')))"
    )
    content = content.replace(
        "'Approved ($approvedCount)'",
        "'${Provider.of<LanguageProvider>(context).tr('approved_word')} ($approvedCount)'"
    )
    content = content.replace(
        "'Pending ($pendingCount)'",
        "'${Provider.of<LanguageProvider>(context).tr('pending')} ($pendingCount)'"
    )
    content = content.replace(
        "'Rejected ($rejectedCount)'",
        "'${Provider.of<LanguageProvider>(context).tr('rejected')} ($rejectedCount)'"
    )
    content = content.replace(
        "'Recent Expense Amount Comparison'",
        "Provider.of<LanguageProvider>(context).tr('recent_exp_amt_comp')"
    )
    content = content.replace(
        "'Amounts of the latest expense submissions (${AppConstants.defaultCurrencySymbol})'",
        "Provider.of<LanguageProvider>(context).tr('recent_exp_amt_sub')"
    )
    content = content.replace(
        "const Center(child: Text('No transactions recorded yet.'))",
        "Center(child: Text(Provider.of<LanguageProvider>(context).tr('no_transactions_recorded_yet')))"
    )
    content = content.replace(
        "'Disbursements by Requester'",
        "Provider.of<LanguageProvider>(context).tr('disbursements_by_req')"
    )
    content = content.replace(
        "'Actual paid expenditure per staff member'",
        "Provider.of<LanguageProvider>(context).tr('disbursements_by_req_sub')"
    )
    content = content.replace(
        "const Center(\n              child: Text('No paid transactions found yet.'),\n            )",
        "Center(\n              child: Text(Provider.of<LanguageProvider>(context).tr('no_paid_transactions_yet')),\n            )"
    )
    
    # Add LanguageProvider import
    if "import '../../providers/language_provider.dart';" not in content:
        content = content.replace(
            "import '../../providers/expense_provider.dart';",
            "import '../../providers/expense_provider.dart';\nimport '../../providers/language_provider.dart';"
        )
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done")

process(sys.argv[1])
