import sys

def fix_const(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    content = content.replace("const Text(lang.tr('receipt_attached')", "Text(lang.tr('receipt_attached')")
    content = content.replace("const Text(\n                                  lang.tr('receipt_attached')", "Text(\n                                  lang.tr('receipt_attached')")
    content = content.replace("const Text(lang.tr('no_bill_image')", "Text(lang.tr('no_bill_image')")
    content = content.replace("const Text(\n                                  lang.tr('no_bill_image')", "Text(\n                                  lang.tr('no_bill_image')")
    content = content.replace("const Text(lang.tr('unable_display_preview')", "Text(lang.tr('unable_display_preview')")
    content = content.replace("const Text(\n                                      lang.tr('unable_display_preview')", "Text(\n                                      lang.tr('unable_display_preview')")
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix_const('lib/screens/finance/pending_requests_screen.dart')
fix_const('lib/screens/finance/request_detail_screen.dart')
