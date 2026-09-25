import re
import sys

def replace_strings(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Add import
    if "import '../../providers/language_provider.dart';" not in content:
        content = content.replace("import '../../providers/expense_provider.dart';", "import '../../providers/expense_provider.dart';\nimport '../../providers/language_provider.dart';")
    
    # Add lang provider in build
    if "final lang = Provider.of<LanguageProvider>(context);" not in content:
        content = content.replace("final auth = Provider.of<AuthProvider>(context, listen: false);", "final auth = Provider.of<AuthProvider>(context, listen: false);\n    final lang = Provider.of<LanguageProvider>(context, listen: false);")
        # Also need it in build method
        content = content.replace("final screenWidth = MediaQuery.of(context).size.width;", "final lang = Provider.of<LanguageProvider>(context);\n    final screenWidth = MediaQuery.of(context).size.width;")
        
    # Replace Strings
    replacements = {
        r"'You do not have permission to approve this request\.'": r"lang.tr('no_permission_approve')",
        r"'This request is no longer pending and cannot be approved\.'": r"lang.tr('request_not_pending_approve')",
        r"const Text\('Approve & Process Payment'\)": r"Text(lang.tr('approve_process_payment'))",
        r"'Are you sure you want to approve \"\$\{widget\.request\.itemDescription\}\" for \$\{AppConstants\.defaultCurrencySymbol\}\$\{widget\.request\.amount\.toStringAsFixed\(2\)\}\? This will mark the expense as Paid\.'": r"'${lang.tr('approve_confirm_msg_prefix')}${widget.request.itemDescription}${lang.tr('approve_confirm_msg_middle')}${AppConstants.defaultCurrencySymbol}${widget.request.amount.toStringAsFixed(2)}${lang.tr('approve_confirm_msg_end')}'",
        r"const Text\('Cancel'\)": r"Text(lang.tr('cancel'))",
        r"const Text\('Confirm Approval'\)": r"Text(lang.tr('confirm_approval'))",
        r"'Unable to save\. Try again\.'": r"lang.tr('unable_to_save_retry')",
        r"'Expense request approved and marked as Paid!'": r"lang.tr('expense_approved_marked_paid')",
        r"'You do not have permission to reject this request\.'": r"lang.tr('no_permission_reject')",
        r"'This request is no longer pending and cannot be rejected\.'": r"lang.tr('request_not_pending_reject')",
        r"'Expense request rejected\. Reason logged for requester\.'": r"lang.tr('expense_rejected_reason_logged')",
        r"'Expense Review: \$\{req\.displayId\}'": r"'${lang.tr('expense_review_prefix')}${req.displayId}'",
        r"'Requester Information'": r"lang.tr('requester_information')",
        r"'Purpose & Reason for Purchase'": r"lang.tr('purpose_reason_purchase')",
        r"'Rejection Explanation:'": r"lang.tr('rejection_explanation')",
        r"'Attached Bill / Receipt'": r"lang.tr('attached_bill_receipt')",
        r"const Text\('Full View & Zoom'\)": r"Text(lang.tr('full_view_zoom'))",
        r"'Receipt: \$\{req\.itemDescription\}'": r"'${lang.tr('receipt_prefix')}${req.itemDescription}'",
        r"'Unable to display preview'": r"lang.tr('unable_display_preview')",
        r"'No receipt attached for this request'": r"lang.tr('no_receipt_attached_msg')",
        r"'Reject'": r"lang.tr('reject_btn')",
        r"'Approve & Pay'": r"lang.tr('approve_pay_btn')",
    }

    for pattern, repl in replacements.items():
        content = re.sub(pattern, repl, content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done")

replace_strings(sys.argv[1])
