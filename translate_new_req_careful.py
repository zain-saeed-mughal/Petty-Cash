import sys

def process(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Add lang provider if missing
    if "final lang = Provider.of<LanguageProvider>(context);" not in content:
        content = content.replace(
            "  Widget build(BuildContext context) {",
            "  Widget build(BuildContext context) {\n    final lang = Provider.of<LanguageProvider>(context);"
        )

    # 2. Add language provider import
    if "import '../../providers/language_provider.dart';" not in content:
        content = content.replace(
            "import '../../providers/expense_provider.dart';",
            "import '../../providers/expense_provider.dart';\nimport '../../providers/language_provider.dart';"
        )

    # 3. Replace the specific string constants with lang.tr
    # Header
    content = content.replace(
        "children: const [",
        "children: ["
    )
    content = content.replace(
        "'Submit Petty Cash Expense'",
        "lang.tr('submit_expense_title')"
    )
    content = content.replace(
        "'Fill in the details, attach bill/receipt photo, and send for Finance approval.'",
        "lang.tr('submit_expense_subtitle')"
    )

    # Item Description
    content = content.replace(
        "const Text(\n                        'Item Description *'",
        "Text(\n                        lang.tr('item_desc_label')"
    )
    content = content.replace(
        "const InputDecoration(\n                          hintText: 'e.g. A4 Copy Paper, Kitchen Coffee & Milk, Hardware Repair...'",
        "InputDecoration(\n                          hintText: lang.tr('item_desc_hint')"
    )
    content = content.replace(
        "return 'Please describe the item or service';",
        "return lang.tr('item_desc_error');"
    )

    # Amount Spent
    content = content.replace(
        "const Text(\n                        'Amount Spent *'",
        "Text(\n                        lang.tr('amount_label')"
    )
    content = content.replace(
        "const InputDecoration(\n                          prefixIcon: Padding",
        "InputDecoration(\n                          prefixIcon: Padding"
    )
    content = content.replace(
        "return 'Please enter the amount spent';",
        "return lang.tr('amount_empty_error');"
    )
    content = content.replace(
        "return 'Please enter a valid amount greater than 0';",
        "return lang.tr('amount_invalid_error');"
    )

    # Purpose
    content = content.replace(
        "const Text(\n                        'Purpose / Reason for Purchase *'",
        "Text(\n                        lang.tr('purpose_label')"
    )
    content = content.replace(
        "const InputDecoration(\n                          hintText: 'Explain why this expenditure was required (e.g. Pantry weekly replenishment, client visitor refreshments...)',",
        "InputDecoration(\n                          hintText: lang.tr('purpose_hint'),"
    )
    content = content.replace(
        "return 'Please explain the reason for this expense';",
        "return lang.tr('purpose_error');"
    )

    # Receipt
    content = content.replace(
        "const Text(\n                        'Bill / Receipt Photo (Optional but Recommended)'",
        "Text(\n                        lang.tr('receipt_label')"
    )
    content = content.replace(
        "const Text('Upload Bill or Receipt Photo'",
        "Text(lang.tr('upload_photo')"
    )
    content = content.replace(
        "const Text('PNG, JPG, or JPEG up to 10MB'",
        "Text(lang.tr('photo_hint')"
    )
    content = content.replace(
        "const Text('Gallery')",
        "Text(lang.tr('gallery'))"
    )
    content = content.replace(
        "const Text('Camera')",
        "Text(lang.tr('camera'))"
    )
    content = content.replace(
        "const Text('View Full')",
        "Text(lang.tr('view_full'))"
    )
    content = content.replace(
        "const Text('Remove')",
        "Text(lang.tr('remove'))"
    )

    # Submit button
    content = content.replace(
        "? 'Submitting Expense Request...'",
        "? lang.tr('submitting')"
    )
    content = content.replace(
        ": 'Submit Expense Request',",
        ": lang.tr('submit_btn'),"
    )

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done")

process(sys.argv[1])
