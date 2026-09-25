import sys

def process(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Add lang provider in build if missing
    if "final lang = Provider.of<LanguageProvider>(context);" not in content:
        content = content.replace(
            "  Widget build(BuildContext context) {",
            "  Widget build(BuildContext context) {\n    final lang = Provider.of<LanguageProvider>(context);"
        )

    if "final lang = Provider.of<LanguageProvider>(context, listen: false);" not in content.split("Future<void> _handleApprove() async {")[1]:
        content = content.replace(
            "Future<void> _handleApprove() async {",
            "Future<void> _handleApprove() async {\n    final lang = Provider.of<LanguageProvider>(context, listen: false);"
        )
    if "final lang = Provider.of<LanguageProvider>(context, listen: false);" not in content.split("Future<void> _handleReject() async {")[1]:
        content = content.replace(
            "Future<void> _handleReject() async {",
            "Future<void> _handleReject() async {\n    final lang = Provider.of<LanguageProvider>(context, listen: false);"
        )
        
    # 2. Add language provider import
    if "import '../../providers/language_provider.dart';" not in content:
        content = content.replace(
            "import '../../providers/expense_provider.dart';",
            "import '../../providers/expense_provider.dart';\nimport '../../providers/language_provider.dart';"
        )

    # 3. Replace strings
    content = content.replace(
        "'You do not have permission to approve this request.'",
        "lang.tr('no_permission_approve')"
    )
    content = content.replace(
        "'This request is no longer pending and cannot be approved.'",
        "lang.tr('request_not_pending_approve')"
    )
    content = content.replace(
        "const Text('Approve & Process Payment')",
        "Text(lang.tr('approve_process_payment'))"
    )
    content = content.replace(
        "'Are you sure you want to approve \"${widget.request.itemDescription}\" for ${AppConstants.defaultCurrencySymbol}${widget.request.amount.toStringAsFixed(2)}? This will mark the expense as Paid.'",
        "'${lang.tr('approve_confirm_msg_prefix')}${widget.request.itemDescription}${lang.tr('approve_confirm_msg_middle')}${AppConstants.defaultCurrencySymbol}${widget.request.amount.toStringAsFixed(2)}${lang.tr('approve_confirm_msg_end')}'"
    )
    content = content.replace(
        "const Text('Cancel')",
        "Text(lang.tr('cancel'))"
    )
    content = content.replace(
        "const Text('Confirm Approval')",
        "Text(lang.tr('confirm_approval'))"
    )
    content = content.replace(
        "'Unable to save. Try again.'",
        "lang.tr('unable_to_save_retry')"
    )
    content = content.replace(
        "'Expense request approved and marked as Paid!'",
        "lang.tr('expense_approved_marked_paid')"
    )
    content = content.replace(
        "'You do not have permission to reject this request.'",
        "lang.tr('no_permission_reject')"
    )
    content = content.replace(
        "'This request is no longer pending and cannot be rejected.'",
        "lang.tr('request_not_pending_reject')"
    )
    content = content.replace(
        "'Expense request rejected. Reason logged for requester.'",
        "lang.tr('expense_rejected_reason_logged')"
    )
    content = content.replace(
        "'Expense Review: ${req.displayId}'",
        "'${lang.tr('expense_review_prefix')}${req.displayId}'"
    )
    content = content.replace(
        "const Text(\n                          'Requester Information',",
        "Text(\n                          lang.tr('requester_information'),"
    )
    content = content.replace(
        "const Text(\n                          'Purpose & Reason for Purchase',",
        "Text(\n                          lang.tr('purpose_reason_purchase'),"
    )
    content = content.replace(
        "const Text(\n                                'Rejection Explanation:',",
        "Text(\n                                lang.tr('rejection_explanation'),"
    )
    content = content.replace(
        "const Text(\n                              'Attached Bill / Receipt',",
        "Text(\n                              lang.tr('attached_bill_receipt'),"
    )
    content = content.replace(
        "const Text('Full View & Zoom')",
        "Text(lang.tr('full_view_zoom'))"
    )
    content = content.replace(
        "'Receipt: ${req.itemDescription}'",
        "'${lang.tr('receipt_prefix')}${req.itemDescription}'"
    )
    content = content.replace(
        "'Unable to display preview'",
        "lang.tr('unable_display_preview')"
    )
    content = content.replace(
        "const Text(\n                                'No receipt attached for this request',",
        "Text(\n                                lang.tr('no_receipt_attached_msg'),"
    )
    content = content.replace(
        "const Text(\n                                'Reject',",
        "Text(\n                                lang.tr('reject_btn'),"
    )
    content = content.replace(
        "const Text(\n                                'Approve & Pay',",
        "Text(\n                                lang.tr('approve_pay_btn'),"
    )

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done")

process(sys.argv[1])
