import sys

def process(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace strings
    content = content.replace(
        "const Text(\n                'Super Admin Override',",
        "Text(\n                Provider.of<LanguageProvider>(context, listen: false).tr('super_admin_override'),"
    )
    content = content.replace(
        "'Override status for \"${req.itemDescription}\" (${req.id})'",
        "'${Provider.of<LanguageProvider>(context, listen: false).tr('override_status_for')}\"${req.itemDescription}\" (${req.id})'"
    )
    content = content.replace(
        "labelText: 'Force Status To:',",
        "labelText: Provider.of<LanguageProvider>(context, listen: false).tr('force_status_to'),"
    )
    content = content.replace(
        "labelText: 'Audit Note / Override Reason',",
        "labelText: Provider.of<LanguageProvider>(context, listen: false).tr('audit_note_reason'),"
    )
    content = content.replace(
        "hintText: 'e.g. Approved per CEO executive exemption...',",
        "hintText: Provider.of<LanguageProvider>(context, listen: false).tr('audit_note_hint'),"
    )
    content = content.replace(
        "const Text('Cancel')",
        "Text(Provider.of<LanguageProvider>(context, listen: false).tr('cancel'))"
    )
    content = content.replace(
        "'Transaction status overridden successfully by Super Admin.'",
        "Provider.of<LanguageProvider>(context, listen: false).tr('override_success')"
    )
    content = content.replace(
        "const Text('Apply Override')",
        "Text(Provider.of<LanguageProvider>(context, listen: false).tr('apply_override'))"
    )
    content = content.replace(
        "const Text('Delete Transaction Record')",
        "Text(Provider.of<LanguageProvider>(context, listen: false).tr('delete_transaction_title'))"
    )
    content = content.replace(
        "'Are you sure you want to permanently delete transaction \"${req.itemDescription}\" (${req.id})? This action is irrevocable.'",
        "Provider.of<LanguageProvider>(context, listen: false).tr('delete_transaction_confirm')"
    )
    content = content.replace(
        "Text('Transaction record deleted.')",
        "Text(Provider.of<LanguageProvider>(context, listen: false).tr('transaction_deleted'))"
    )
    content = content.replace(
        "const Text('Delete')",
        "Text(Provider.of<LanguageProvider>(context, listen: false).tr('delete_btn'))"
    )
    content = content.replace(
        "const Text(\n                                  'All Organizational Transactions',",
        "Text(\n                                  Provider.of<LanguageProvider>(context).tr('all_org_transactions'),"
    )
    content = content.replace(
        "? 'Super Admin View: Full control with transaction override and audit delete'",
        "? Provider.of<LanguageProvider>(context).tr('super_admin_view_desc')"
    )
    content = content.replace(
        ": 'Admin View: Real-time organizational audit trail',",
        ": Provider.of<LanguageProvider>(context).tr('admin_view_desc'),"
    )
    content = content.replace(
        "hintText: 'Search by requester name, ID, item description, or reason...',",
        "hintText: Provider.of<LanguageProvider>(context).tr('search_admin_transactions'),"
    )
    content = content.replace(
        "'All (${expense.totalTransactionsCount})'",
        "'${Provider.of<LanguageProvider>(context).tr('all')} (${expense.totalTransactionsCount})'"
    )
    content = content.replace(
        "'Pending (${expense.pendingCount})'",
        "'${Provider.of<LanguageProvider>(context).tr('pending')} (${expense.pendingCount})'"
    )
    content = content.replace(
        "'Approved / Paid (${expense.approvedCount})'",
        "'${Provider.of<LanguageProvider>(context).tr('paid_approved')} (${expense.approvedCount})'"
    )
    content = content.replace(
        "'Rejected (${expense.rejectedCount})'",
        "'${Provider.of<LanguageProvider>(context).tr('rejected')} (${expense.rejectedCount})'"
    )
    content = content.replace(
        "const Text(\n                        'No Transactions Found',",
        "Text(\n                        Provider.of<LanguageProvider>(context).tr('no_transactions_found'),"
    )
    content = content.replace(
        "const Text(\n                        'Try adjusting your search criteria.',",
        "Text(\n                        Provider.of<LanguageProvider>(context).tr('try_adjusting_search'),"
    )
    content = content.replace(
        "'Requested by: ${req.requesterName} (${req.requesterEmail})'",
        "'${Provider.of<LanguageProvider>(context, listen: false).tr('requested_by')}${req.requesterName} (${req.requesterEmail})'"
    )
    content = content.replace(
        "'Purpose: ${req.reason}'",
        "'${Provider.of<LanguageProvider>(context, listen: false).tr('purpose_prefix')}${req.reason}'"
    )
    content = content.replace(
        "'Rejection Reason: ${req.rejectionReason}'",
        "'${Provider.of<LanguageProvider>(context, listen: false).tr('rejection_reason_prefix')}${req.rejectionReason}'"
    )
    content = content.replace(
        "const Text('View Receipt')",
        "Text(Provider.of<LanguageProvider>(context, listen: false).tr('view_receipt'))"
    )
    content = content.replace(
        "const Text('Review Detail')",
        "Text(Provider.of<LanguageProvider>(context, listen: false).tr('review_detail'))"
    )
    content = content.replace(
        "'Override Status (Super Admin)'",
        "Provider.of<LanguageProvider>(context, listen: false).tr('override_status_tooltip')"
    )
    content = content.replace(
        "'Delete Transaction (Super Admin)'",
        "Provider.of<LanguageProvider>(context, listen: false).tr('delete_transaction_tooltip')"
    )

    # Add language provider import
    if "import '../../providers/language_provider.dart';" not in content:
        content = content.replace(
            "import '../../providers/expense_provider.dart';",
            "import '../../providers/expense_provider.dart';\nimport '../../providers/language_provider.dart';"
        )

    # Fix const errors
    content = content.replace("const SnackBar(", "SnackBar(")
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done")

process(sys.argv[1])
