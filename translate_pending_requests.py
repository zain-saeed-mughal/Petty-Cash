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
        r"'Pending Expense Queue'": r"lang.tr('pending_expense_queue')",
        r"'\$\{expense.pendingCount\} requests awaiting verification • Total Pending: \$\{AppConstants.defaultCurrencySymbol\}\$\{expense.pendingAmount.toStringAsFixed\(2\)\}'": r"'\${expense.pendingCount}${lang.tr('requests_awaiting_verification')}${AppConstants.defaultCurrencySymbol}${expense.pendingAmount.toStringAsFixed(2)}'",
        r"hintText:\s*'Search by requester name, item description, or reason\.\.\.'": r"hintText: lang.tr('search_pending')",
        r"'All Caught Up!'": r"lang.tr('all_caught_up')",
        r"'There are currently no pending expense requests waiting for review\.'": r"lang.tr('no_pending_requests')",
        r"'Purpose: \$\{req.reason\}'": r"'${lang.tr('purpose_prefix')}${req.reason}'",
        r"'Receipt attached'": r"lang.tr('receipt_attached')",
        r"'No bill image'": r"lang.tr('no_bill_image')",
        r"const Text\('Review & Decide'\)": r"Text(lang.tr('review_and_decide'))",
    }

    for pattern, repl in replacements.items():
        content = re.sub(pattern, repl, content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done")

replace_strings(sys.argv[1])
