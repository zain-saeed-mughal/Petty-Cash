# Review evidence

Recorded against fcea3a3. These are review fixtures and captured results, not production app changes.

- `layout_results.json`: inspect each `errors` array. The probe intentionally records errors rather than failing immediately; an exit code of zero does not mean all layouts passed.
- `live_contracts.json`: zero-row read-only database responses, with no keys or private row contents.
- PNG files: synthetic records rendered using the real app screens; navigation space is simulated.
- `probe_test.dart`: snapshot of the layout probe used for this review. It depends on Flutter test assets and fonts at `.dart_tool/review_current/fonts` relative to the project root. The font fixtures are preserved here.

To restore its font inputs and rerun from the project root in PowerShell:

```powershell
New-Item -ItemType Directory -Path .dart_tool/review_current/fonts -Force | Out-Null
Copy-Item -Path review/2026-09-24/fonts/*.ttf -Destination .dart_tool/review_current/fonts
flutter test --no-pub review/2026-09-24/probe_test.dart
```

The probe writes new results into `.dart_tool/review_current`, preserving this evidence snapshot. Flutter version, font metrics and record dates can affect fresh results. It uses a Google Fonts internal test hook and is an investigative harness, not a maintained regression suite.
