import re
import sys

def replace_strings(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Add import
    if "import '../../providers/language_provider.dart';" not in content:
        content = content.replace("import '../../providers/expense_provider.dart';", "import '../../providers/expense_provider.dart';\nimport '../../providers/language_provider.dart';")
    
    # Add lang provider inside build
    if "final lang = Provider.of<LanguageProvider>(context);" not in content:
        content = content.replace("final expense = Provider.of<ExpenseProvider>(context);", "final expense = Provider.of<ExpenseProvider>(context);\n    final lang = Provider.of<LanguageProvider>(context);")

    # String replacements
    replacements = {
        r"'Total Settled / Paid'": r"lang.tr('total_settled_paid')",
        r"'Settled Transactions'": r"lang.tr('settled_transactions')",
        r"'\$\{expense.approvedCount\} approved / \$\{expense.rejectedCount\} rejected'": r"'\${expense.approvedCount}${lang.tr('approved_word')}${expense.rejectedCount}${lang.tr('rejected_word')}'",
        r"hintText:\s*'Search history by requester, description, or reason\.\.\.'": r"hintText: lang.tr('search_history')",
        r"'All Settled'": r"lang.tr('all_settled')",
        r"'Paid / Approved'": r"lang.tr('paid_approved')",
        r"'Rejected'": r"lang.tr('rejected')",
        r"'No Payment Records Found'": r"lang.tr('no_payment_records')",
        r"'Approved and rejected requests will appear here\.'": r"lang.tr('approved_rejected_appear')",
        r"'Purpose: \$\{req.reason\}'": r"'${lang.tr('purpose_prefix')}${req.reason}'",
        r"'Reason: \$\{req.rejectionReason\}'": r"'${lang.tr('reason_prefix')}${req.rejectionReason}'",
        r"'Receipt attached'": r"lang.tr('receipt_attached')",
        r"'No bill image'": r"lang.tr('no_bill_image')",
        r"const Text\('View Receipt'\)": r"Text(lang.tr('view_receipt'))",
        r"const Text\('Review Detail'\)": r"Text(lang.tr('review_detail'))",
    }

    for pattern, repl in replacements.items():
        content = re.sub(pattern, repl, content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done")

replace_strings(sys.argv[1])
