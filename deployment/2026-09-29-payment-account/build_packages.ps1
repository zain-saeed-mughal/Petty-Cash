$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$package = $PSScriptRoot

Compress-Archive -Path (Join-Path $root 'build\web\*') -DestinationPath (Join-Path $package 'petty-cash-web.zip') -Force
Copy-Item -LiteralPath (Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk') -Destination (Join-Path $package 'petty-cash-android-unsigned.apk') -Force
Copy-Item -LiteralPath (Join-Path $root 'build\app\outputs\flutter-apk\app-debug.apk') -Destination (Join-Path $package 'petty-cash-android-test.apk') -Force
$purgeSql = @(
  Get-Content -LiteralPath (Join-Path $root 'supabase\migrations\202609290027_office_boy_data_purge.sql') -Raw
  Get-Content -LiteralPath (Join-Path $root 'supabase\migrations\202609290028_purge_deleted_request_history.sql') -Raw
) -join "`r`n"
$purgeSql | Set-Content -LiteralPath (Join-Path $package 'database_optional_user_purge.sql') -Encoding utf8
Copy-Item -LiteralPath (Join-Path $root 'supabase\migrations\202609290028_purge_deleted_request_history.sql') -Destination (Join-Path $package 'database_purge_audit_fix.sql') -Force

Add-Type -AssemblyName System.IO.Compression.FileSystem
$iosZip = Join-Path $package 'petty-cash-ios-source.zip'
if (Test-Path -LiteralPath $iosZip) { Remove-Item -LiteralPath $iosZip }
$archive = [System.IO.Compression.ZipFile]::Open($iosZip, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  foreach ($name in @('ios', 'lib', 'assets', 'pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml', '.metadata')) {
    $target = Join-Path $root $name
    if (-not (Test-Path -LiteralPath $target)) { continue }
    $item = Get-Item -LiteralPath $target
    $files = if ($item.PSIsContainer) { Get-ChildItem -LiteralPath $target -File -Recurse -Force } else { @($item) }
    foreach ($file in $files) {
      $relative = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
      if ($relative -match '^ios/(Flutter/(ephemeral/|Generated\.xcconfig$|flutter_export_environment\.sh$)|Pods/|\.symlinks/|build/)') { continue }
      [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $archive, $file.FullName, $relative, [System.IO.Compression.CompressionLevel]::Optimal
      ) | Out-Null
    }
  }
} finally {
  $archive.Dispose()
}

$checksums = Get-ChildItem -LiteralPath $package -File |
  Where-Object { $_.Name -ne 'SHA256SUMS.txt' } |
  Sort-Object Name |
  ForEach-Object { '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $_.Name }
$checksums | Set-Content -LiteralPath (Join-Path $package 'SHA256SUMS.txt') -Encoding ascii
