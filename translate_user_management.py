import sys

def process(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Add language provider import
    if "import '../../providers/language_provider.dart';" not in content:
        content = content.replace(
            "import '../../providers/user_provider.dart';",
            "import '../../providers/user_provider.dart';\nimport '../../providers/language_provider.dart';"
        )

    # Replacements
    content = content.replace(
        "const Text('Account Created')",
        "Text(Provider.of<LanguageProvider>(context, listen: false).tr('account_created'))"
    )
    content = content.replace(
        "Text('$name can use these temporary credentials:')",
        "Text('$name${Provider.of<LanguageProvider>(context, listen: false).tr('can_use_temp_creds')}')"
    )
    content = content.replace(
        "_credentialRow('Email', email),",
        "_credentialRow(Provider.of<LanguageProvider>(context, listen: false).tr('email_label'), email),"
    )
    content = content.replace(
        "_credentialRow('Temporary password', temporaryPassword),",
        "_credentialRow(Provider.of<LanguageProvider>(context, listen: false).tr('temp_password_label'), temporaryPassword),"
    )
    content = content.replace(
        "'Share this password securely. It is shown only once and is not saved in the profile.'",
        "Provider.of<LanguageProvider>(context, listen: false).tr('share_password_securely')"
    )
    content = content.replace(
        "const Text('Done')",
        "Text(Provider.of<LanguageProvider>(context, listen: false).tr('done'))"
    )
    content = content.replace(
        "'Copy $label'",
        "'${Provider.of<LanguageProvider>(context, listen: false).tr('copy_tooltip')}$label'"
    )
    content = content.replace(
        "const Text('Deactivate account')",
        "Text(Provider.of<LanguageProvider>(context, listen: false).tr('deactivate_account_title'))"
    )
    content = content.replace(
        "'Disable access for ${user.name}? Their requests and payment history will be retained.'",
        "'${Provider.of<LanguageProvider>(context, listen: false).tr('deactivate_account_confirm')}${user.name}${Provider.of<LanguageProvider>(context, listen: false).tr('deactivate_account_confirm_end')}'"
    )
    content = content.replace(
        "const Text('Cancel')",
        "Text(Provider.of<LanguageProvider>(context, listen: false).tr('cancel'))"
    )
    content = content.replace(
        "const Text('Deactivate')",
        "Text(Provider.of<LanguageProvider>(context, listen: false).tr('deactivate_btn'))"
    )
    content = content.replace(
        "? 'Account deactivated.'",
        "? Provider.of<LanguageProvider>(context, listen: false).tr('account_deactivated')"
    )
    content = content.replace(
        ": provider.errorMessage ?? 'Unable to deactivate this account.',",
        ": provider.errorMessage ?? Provider.of<LanguageProvider>(context, listen: false).tr('unable_to_deactivate'),"
    )
    content = content.replace(
        "const Text(\n                                  'User Accounts Management',",
        "Text(\n                                  Provider.of<LanguageProvider>(context).tr('user_accounts_management'),"
    )
    content = content.replace(
        "? 'Super Admin: Manage all organizational users, Finance, Admins & Staff'",
        "? Provider.of<LanguageProvider>(context).tr('super_admin_manage_desc')"
    )
    content = content.replace(
        ": 'Admin: Manage Office Boy and Finance accounts',",
        ": Provider.of<LanguageProvider>(context).tr('admin_manage_desc'),"
    )
    content = content.replace(
        "const Text('Add')",
        "Text(Provider.of<LanguageProvider>(context).tr('add_btn'))"
    )
    content = content.replace(
        "hintText: 'Search users by name or email...',",
        "hintText: Provider.of<LanguageProvider>(context).tr('search_users_hint'),"
    )
    content = content.replace(
        "'All Users (${manageable.length})'",
        "'${Provider.of<LanguageProvider>(context).tr('all_users')} (${manageable.length})'"
    )
    content = content.replace(
        "'Office Boy (${manageable.where((u) => u.isOfficeBoy).length})'",
        "'${Provider.of<LanguageProvider>(context).tr('office_boy')} (${manageable.where((u) => u.isOfficeBoy).length})'"
    )
    content = content.replace(
        "'Finance (${manageable.where((u) => u.isFinance).length})'",
        "'${Provider.of<LanguageProvider>(context).tr('finance')} (${manageable.where((u) => u.isFinance).length})'"
    )
    content = content.replace(
        "'Admin (${manageable.where((u) => u.isAdmin).length})'",
        "'${Provider.of<LanguageProvider>(context).tr('admin')} (${manageable.where((u) => u.isAdmin).length})'"
    )
    content = content.replace(
        "const Text(\n                        'No Users Found',",
        "Text(\n                        Provider.of<LanguageProvider>(context).tr('no_users_found'),"
    )
    content = content.replace(
        "const Text(\n                        'Try adjusting your search criteria or create a new user account.',",
        "Text(\n                        Provider.of<LanguageProvider>(context).tr('try_adjusting_search_users'),"
    )
    content = content.replace(
        "'Edit User'",
        "Provider.of<LanguageProvider>(context, listen: false).tr('edit_user_tooltip')"
    )
    content = content.replace(
        "'Remove User'",
        "Provider.of<LanguageProvider>(context, listen: false).tr('remove_user_tooltip')"
    )
    
    # Fix const context issues safely
    content = content.replace("const SnackBar(", "SnackBar(")
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done")

process(sys.argv[1])
