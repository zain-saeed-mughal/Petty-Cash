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

    # Directionality
    if "return Directionality(" not in content:
        content = content.replace("return AdaptiveScaffold(", "return Directionality(\n      textDirection: lang.currentLanguage == 'ur' ? TextDirection.rtl : TextDirection.ltr,\n      child: AdaptiveScaffold(")
        content = content.replace("      body: screens[_currentIndex],\n    );", "      body: screens[_currentIndex],\n    ),\n    );")

    # String replacements
    replacements = {
        r"'Pending Reviews'": r"lang.tr('pending_reviews')",
        r"'Payment History'": r"lang.tr('payment_history')",
        r"'Monthly Reports'": r"lang.tr('monthly_reports')",
        r"\['Pending Approvals', 'Payment History', 'Monthly Reports'\]": r"[lang.tr('pending_approvals'), lang.tr('payment_history'), lang.tr('monthly_reports')]",
    }

    for pattern, repl in replacements.items():
        content = re.sub(pattern, repl, content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done")

replace_strings(sys.argv[1])
