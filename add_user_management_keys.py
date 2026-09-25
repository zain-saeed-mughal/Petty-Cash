import sys

new_en_keys = """
      'account_created': 'Account Created',
      'can_use_temp_creds': ' can use these temporary credentials:',
      'email_label': 'Email',
      'temp_password_label': 'Temporary password',
      'share_password_securely': 'Share this password securely. It is shown only once and is not saved in the profile.',
      'done': 'Done',
      'copy_tooltip': 'Copy ',
      'deactivate_account_title': 'Deactivate account',
      'deactivate_account_confirm': 'Disable access for ',
      'deactivate_account_confirm_end': '? Their requests and payment history will be retained.',
      'deactivate_btn': 'Deactivate',
      'account_deactivated': 'Account deactivated.',
      'unable_to_deactivate': 'Unable to deactivate this account.',
      'user_accounts_management': 'User Accounts Management',
      'super_admin_manage_desc': 'Super Admin: Manage all organizational users, Finance, Admins & Staff',
      'admin_manage_desc': 'Admin: Manage Office Boy and Finance accounts',
      'add_btn': 'Add',
      'search_users_hint': 'Search users by name or email...',
      'all_users': 'All Users',
      'office_boy': 'Office Boy',
      'finance': 'Finance',
      'admin': 'Admin',
      'no_users_found': 'No Users Found',
      'try_adjusting_search_users': 'Try adjusting your search criteria or create a new user account.',
      'edit_user_tooltip': 'Edit User',
      'remove_user_tooltip': 'Remove User',
"""

new_ur_keys = """
      'account_created': 'اکاؤنٹ بن گیا',
      'can_use_temp_creds': ' یہ عارضی اسناد استعمال کر سکتے ہیں:',
      'email_label': 'ای میل',
      'temp_password_label': 'عارضی پاس ورڈ',
      'share_password_securely': 'اس پاس ورڈ کو محفوظ طریقے سے شیئر کریں۔ یہ صرف ایک بار دکھایا جاتا ہے اور پروفائل میں محفوظ نہیں ہوتا ہے۔',
      'done': 'ہو گیا',
      'copy_tooltip': 'کاپی کریں ',
      'deactivate_account_title': 'اکاؤنٹ غیر فعال کریں',
      'deactivate_account_confirm': 'کیا آپ ',
      'deactivate_account_confirm_end': ' کی رسائی بند کرنا چاہتے ہیں؟ ان کی درخواستیں اور ادائیگی کی ہسٹری محفوظ رہے گی۔',
      'deactivate_btn': 'غیر فعال کریں',
      'account_deactivated': 'اکاؤنٹ غیر فعال کر دیا گیا۔',
      'unable_to_deactivate': 'اس اکاؤنٹ کو غیر فعال کرنے سے قاصر۔',
      'user_accounts_management': 'صارفین کے اکاؤنٹس کا انتظام',
      'super_admin_manage_desc': 'سپر ایڈمن: تمام تنظیمی صارفین، فنانس، ایڈمنز اور عملے کا انتظام کریں',
      'admin_manage_desc': 'ایڈمن: آفس بوائے اور فنانس اکاؤنٹس کا انتظام کریں',
      'add_btn': 'شامل کریں',
      'search_users_hint': 'نام یا ای میل سے صارفین تلاش کریں...',
      'all_users': 'تمام صارفین',
      'office_boy': 'آفس بوائے',
      'finance': 'فنانس',
      'admin': 'ایڈمن',
      'no_users_found': 'کوئی صارف نہیں ملا',
      'try_adjusting_search_users': 'اپنی تلاش کے معیار کو تبدیل کرنے کی کوشش کریں یا نیا صارف اکاؤنٹ بنائیں۔',
      'edit_user_tooltip': 'صارف میں ترمیم کریں',
      'remove_user_tooltip': 'صارف کو ہٹائیں',
"""

with open('lib/l10n/translations.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    "'delete_transaction_tooltip': 'Delete Transaction (Super Admin)',",
    "'delete_transaction_tooltip': 'Delete Transaction (Super Admin)',\n" + new_en_keys
)

content = content.replace(
    "'delete_transaction_tooltip': 'لین دین حذف کریں (سپر ایڈمن)',",
    "'delete_transaction_tooltip': 'لین دین حذف کریں (سپر ایڈمن)',\n" + new_ur_keys
)

with open('lib/l10n/translations.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Keys added to translations.dart")
