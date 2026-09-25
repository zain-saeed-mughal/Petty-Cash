import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';

extension AppLanguageContext on BuildContext {
  LanguageProvider get language {
    Localizations.maybeLocaleOf(this);
    return read<LanguageProvider>();
  }

  String t(String english) => language.text(english);
}
