import sys
import re

new_en_keys = """
      'analytics_nav': 'Analytics',
      'transactions_nav': 'Transactions',
      'users_nav': 'Users',
      'reports_nav': 'Reports',
      'reports_analytics_title': 'Reports & Analytics',
      'all_transactions_title': 'All Transactions',
      'user_management_title': 'User Management',
      'monthly_reports_title': 'Monthly Reports',
      'super_admin_override': 'Super Admin Override',
      'override_status_for': 'Override status for ',
      'force_status_to': 'Force Status To:',
      'audit_note_reason': 'Audit Note / Override Reason',
      'audit_note_hint': 'e.g. Approved per CEO executive exemption...',
      'override_success': 'Transaction status overridden successfully by Super Admin.',
      'apply_override': 'Apply Override',
      'delete_transaction_title': 'Delete Transaction Record',
      'delete_transaction_confirm': 'Are you sure you want to permanently delete transaction? This action is irrevocable.',
      'transaction_deleted': 'Transaction record deleted.',
      'delete_btn': 'Delete',
      'all_org_transactions': 'All Organizational Transactions',
      'super_admin_view_desc': 'Super Admin View: Full control with transaction override and audit delete',
      'admin_view_desc': 'Admin View: Real-time organizational audit trail',
      'search_admin_transactions': 'Search by requester name, ID, item description, or reason...',
      'no_transactions_found': 'No Transactions Found',
      'try_adjusting_search': 'Try adjusting your search criteria.',
      'requested_by': 'Requested by: ',
      'rejection_reason_prefix': 'Rejection Reason: ',
      'override_status_tooltip': 'Override Status (Super Admin)',
      'delete_transaction_tooltip': 'Delete Transaction (Super Admin)',
"""

new_ur_keys = """
      'analytics_nav': 'تجزیات',
      'transactions_nav': 'لین دین',
      'users_nav': 'صارفین',
      'reports_nav': 'رپورٹس',
      'reports_analytics_title': 'رپورٹس اور تجزیات',
      'all_transactions_title': 'تمام لین دین',
      'user_management_title': 'صارفین کا انتظام',
      'monthly_reports_title': 'ماہانہ رپورٹس',
      'super_admin_override': 'سپر ایڈمن اوور رائیڈ',
      'override_status_for': 'اسٹیٹس اوور رائیڈ برائے ',
      'force_status_to': 'اسٹیٹس کو زبردستی تبدیل کریں:',
      'audit_note_reason': 'آڈٹ نوٹ / اوور رائیڈ کی وجہ',
      'audit_note_hint': 'مثلاً سی ای او کی منظوری سے...',
      'override_success': 'سپر ایڈمن کے ذریعے لین دین کا اسٹیٹس کامیابی سے تبدیل کر دیا گیا۔',
      'apply_override': 'اوور رائیڈ لاگو کریں',
      'delete_transaction_title': 'لین دین کا ریکارڈ حذف کریں',
      'delete_transaction_confirm': 'کیا آپ واقعی اس لین دین کو مستقل طور پر حذف کرنا چاہتے ہیں؟ یہ عمل ناقابل واپسی ہے۔',
      'transaction_deleted': 'لین دین کا ریکارڈ حذف کر دیا گیا۔',
      'delete_btn': 'حذف کریں',
      'all_org_transactions': 'تمام تنظیمی لین دین',
      'super_admin_view_desc': 'سپر ایڈمن منظر: ٹرانزیکشن اوور رائیڈ اور آڈٹ حذف کرنے کے ساتھ مکمل کنٹرول',
      'admin_view_desc': 'ایڈمن منظر: ریئل ٹائم تنظیمی آڈٹ ٹریل',
      'search_admin_transactions': 'درخواست دہندہ کا نام، آئی ڈی، تفصیل، یا وجہ سے تلاش کریں...',
      'no_transactions_found': 'کوئی لین دین نہیں ملا',
      'try_adjusting_search': 'اپنی تلاش کے معیار کو تبدیل کرنے کی کوشش کریں۔',
      'requested_by': 'درخواست گزار: ',
      'rejection_reason_prefix': 'مسترد ہونے کی وجہ: ',
      'override_status_tooltip': 'اسٹیٹس اوور رائیڈ کریں (سپر ایڈمن)',
      'delete_transaction_tooltip': 'لین دین حذف کریں (سپر ایڈمن)',
"""

with open('lib/l10n/translations.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Insert after approve_pay_btn for EN
content = content.replace(
    "'approve_pay_btn': 'Approve & Pay',",
    "'approve_pay_btn': 'Approve & Pay',\n" + new_en_keys
)

# Insert after approve_pay_btn for UR
content = content.replace(
    "'approve_pay_btn': 'منظور کریں اور ادا کریں',",
    "'approve_pay_btn': 'منظور کریں اور ادا کریں',\n" + new_ur_keys
)

with open('lib/l10n/translations.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Keys added to translations.dart")
