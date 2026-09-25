import sys

def process(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replacements
    content = content.replace(
        "const Text(\n                          'Monthly Reports',",
        "Text(\n                          Provider.of<LanguageProvider>(context).tr('monthly_reports_heading'),"
    )
    content = content.replace(
        "const Text(\n                          'Paid amounts use the payment date. Other requests use their submission date.',",
        "Text(\n                          Provider.of<LanguageProvider>(context).tr('monthly_reports_sub'),"
    )
    content = content.replace(
        "tooltip: 'Previous month',",
        "tooltip: Provider.of<LanguageProvider>(context, listen: false).tr('prev_month'),"
    )
    content = content.replace(
        "tooltip: 'Next month',",
        "tooltip: Provider.of<LanguageProvider>(context, listen: false).tr('next_month'),"
    )
    content = content.replace(
        "labelText: 'Requester',",
        "labelText: Provider.of<LanguageProvider>(context, listen: false).tr('requester'),"
    )
    content = content.replace(
        "const Text('All users')",
        "Text(Provider.of<LanguageProvider>(context, listen: false).tr('all_users_dd'))"
    )
    content = content.replace(
        "labelText: 'Status',",
        "labelText: Provider.of<LanguageProvider>(context, listen: false).tr('status'),"
    )
    content = content.replace(
        "const Text('All statuses')",
        "Text(Provider.of<LanguageProvider>(context, listen: false).tr('all_statuses_dd'))"
    )
    content = content.replace(
        "const Text(\n                              'Data could not be refreshed. Displayed values may be out of date.',",
        "Text(\n                              Provider.of<LanguageProvider>(context, listen: false).tr('data_outdated'),"
    )
    content = content.replace(
        "'Total paid'",
        "Provider.of<LanguageProvider>(context).tr('total_paid')"
    )
    content = content.replace(
        "? '${(((paid - previousPaid) / previousPaid) * 100).toStringAsFixed(1)}% vs previous month'",
        "? '${(((paid - previousPaid) / previousPaid) * 100).toStringAsFixed(1)}${Provider.of<LanguageProvider>(context).tr('vs_prev_month')}'"
    )
    content = content.replace(
        ": 'No previous paid amount',",
        ": Provider.of<LanguageProvider>(context).tr('no_prev_paid'),"
    )
    content = content.replace(
        "'Requests in view'",
        "Provider.of<LanguageProvider>(context).tr('requests_in_view')"
    )
    content = content.replace(
        "'All active filters applied'",
        "Provider.of<LanguageProvider>(context).tr('all_filters_applied')"
    )
    content = content.replace(
        "'Pending'",
        "Provider.of<LanguageProvider>(context).tr('pending')"
    )
    content = content.replace(
        "'Awaiting a decision'",
        "Provider.of<LanguageProvider>(context).tr('awaiting_decision')"
    )
    content = content.replace(
        "'Rejected'",
        "Provider.of<LanguageProvider>(context).tr('rejected')"
    )
    content = content.replace(
        "'Review reasons in request details'",
        "Provider.of<LanguageProvider>(context).tr('review_reasons')"
    )
    content = content.replace(
        "'$undated historical payment(s) have no verified payment date and are excluded from monthly totals.'",
        "'$undated${Provider.of<LanguageProvider>(context).tr('historical_payments_no_date')}'"
    )
    content = content.replace(
        "const Text(\n                          'Request details',",
        "Text(\n                          Provider.of<LanguageProvider>(context).tr('request_details'),"
    )
    content = content.replace(
        "const Text('No requests match these filters.')",
        "Text(Provider.of<LanguageProvider>(context).tr('no_requests_match'))"
    )
    content = content.replace(
        "const DataColumn(label: Text('ID / Date'))",
        "DataColumn(label: Text(Provider.of<LanguageProvider>(context).tr('id_date')))"
    )
    content = content.replace(
        "const DataColumn(label: Text('Requester'))",
        "DataColumn(label: Text(Provider.of<LanguageProvider>(context).tr('requester')))"
    )
    content = content.replace(
        "const DataColumn(label: Text('Description'))",
        "DataColumn(label: Text(Provider.of<LanguageProvider>(context).tr('description_th')))"
    )
    content = content.replace(
        "const DataColumn(label: Text('Amount'))",
        "DataColumn(label: Text(Provider.of<LanguageProvider>(context).tr('amount_th')))"
    )
    content = content.replace(
        "const DataColumn(label: Text('Status'))",
        "DataColumn(label: Text(Provider.of<LanguageProvider>(context).tr('status_th')))"
    )
    content = content.replace(
        "'${rows.length} requests · Page ${page + 1} of $pages'",
        "'${rows.length} ${Provider.of<LanguageProvider>(context).tr('requests_suffix')} · ${Provider.of<LanguageProvider>(context).tr('page')} ${page + 1} ${Provider.of<LanguageProvider>(context).tr('of')} $pages'"
    )
    
    # Add LanguageProvider import
    if "import '../../providers/language_provider.dart';" not in content:
        content = content.replace(
            "import '../../providers/user_provider.dart';",
            "import '../../providers/user_provider.dart';\nimport '../../providers/language_provider.dart';"
        )
        
    # Const removal
    content = content.replace(
        "const InputDecoration(\n                                        labelText",
        "InputDecoration(\n                                        labelText"
    )
    content = content.replace(
        "const InputDecoration(\n                                            labelText",
        "InputDecoration(\n                                            labelText"
    )

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done")

process(sys.argv[1])
