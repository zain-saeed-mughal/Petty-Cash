param([Parameter(Mandatory=$true)][string]$Config)
$ErrorActionPreference = 'Stop'
$releaseConfig = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
if (!$releaseConfig.SUPABASE_URL -or !$releaseConfig.SUPABASE_PUBLISHABLE_KEY -or $releaseConfig.SUPABASE_URL -match 'YOUR_PROJECT') { throw 'Configure Supabase URL and publishable key first.' }
$firebaseConfig = @{
 apiKey=$releaseConfig.FIREBASE_API_KEY; appId=$releaseConfig.FIREBASE_APP_ID
 projectId=$releaseConfig.FIREBASE_PROJECT_ID; messagingSenderId=$releaseConfig.FIREBASE_MESSAGING_SENDER_ID
}
if (@($firebaseConfig.Values | Where-Object {$_}).Count -ne 4 -or !$releaseConfig.FIREBASE_WEB_VAPID_KEY) { throw 'Complete the Firebase web app configuration and public VAPID key.' }
$firebaseJson = $firebaseConfig | ConvertTo-Json -Compress
Set-Content -LiteralPath web/firebase-config.js -Value "self.PETTY_CASH_FIREBASE_CONFIG = $firebaseJson;" -Encoding utf8
flutter build web --release "--dart-define-from-file=$Config"
if ($LASTEXITCODE -ne 0) { throw 'Flutter web release build failed.' }

