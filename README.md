# Petty Cash

Petty Cash is a Flutter expense management app for staff request submission, finance approval, admin user management, and reporting.

## Prerequisites

- Flutter SDK 3.22+
- Dart SDK matching the Flutter version
- Supabase project with a secure database and storage bucket
- Android Studio or Xcode for platform builds

## Environment setup

1. Create a Supabase project.
2. Copy the project URL and publishable key into the app config in [lib/services/supabase_service.dart](lib/services/supabase_service.dart).
3. Apply the SQL in [supabase_schema.sql](supabase_schema.sql) in the Supabase SQL Editor.
4. Create a private storage bucket named `receipts` and use signed URLs for temporary access.

## Local development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Safe test commands

Use the repo tests only for local, non-production validation:

```bash
flutter test --no-pub test/petty_cash_test.dart test/widget_test.dart
```

Do not run live provisioning or privileged DB writes as part of normal automated test execution.

## Supported platforms

- Android
- iOS
- Web
- Windows

## Release checklist

- Sign Android release builds with the correct upload key.
- Confirm the release Android manifest includes internet access.
- Add iOS camera/photo permission descriptions before release.
- Review Supabase Row Level Security, storage policies, and payment flow behavior before using real expense data.
- Validate app behavior in a disposable staging environment before production rollout.
