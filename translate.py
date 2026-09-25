import re
import sys

def replace_strings(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    replacements = {
        r"const Text\(\s*'Submit Petty Cash Expense'": r"Text(lang.tr('submit_expense_title')",
        r"'Item Description \*'": r"lang.tr('item_desc_label')",
        r"'e\.g\. A4 Copy Paper, Kitchen Coffee & Milk, Hardware Repair\.\.\.'": r"lang.tr('item_desc_hint')",
        r"'Amount Spent \*'": r"lang.tr('amount_label')",
        r"hintText:\s*'0\.00'": r"hintText: lang.tr('amount_hint')",
        r"'Please enter the amount spent'": r"lang.tr('amount_empty_error')",
        r"'Please enter a valid amount greater than 0'": r"lang.tr('amount_invalid_error')",
        r"'Purpose / Reason for Purchase \*'": r"lang.tr('purpose_label')",
        r"'Explain why this expenditure was required \(e\.g\. Pantry weekly replenishment, client visitor refreshments\.\.\.\)'": r"lang.tr('purpose_hint')",
        r"'Please explain the reason for this expense'": r"lang.tr('purpose_error')",
        r"'Bill / Receipt Photo \(Optional but Recommended\)'": r"lang.tr('receipt_label')",
        r"Text\(\s*'Upload Bill or Receipt Photo'": r"Text(lang.tr('upload_photo')",
        r"Text\(\s*'PNG, JPG, or JPEG up to 10MB'": r"Text(lang.tr('photo_hint')",
        r"const Text\('Gallery'\)": r"Text(lang.tr('gallery'))",
        r"const Text\('Camera'\)": r"Text(lang.tr('camera'))",
        r"'View Full'": r"lang.tr('view_full')",
        r"tooltip:\s*'Remove'": r"tooltip: lang.tr('remove')",
        r"'Submitting Expense Request\.\.\.'": r"lang.tr('submitting')",
        r"'Submit Expense Request'": r"lang.tr('submit_btn')",
    }

    for pattern, repl in replacements.items():
        content = re.sub(pattern, repl, content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done")

replace_strings(sys.argv[1])
