$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$package = $PSScriptRoot
Add-Type -AssemblyName System.IO.Compression.FileSystem

$web = Join-Path $root 'build\web'
$release = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
$debug = Join-Path $root 'build\app\outputs\flutter-apk\app-debug.apk'
foreach ($required in @($web, $release, $debug)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Build output is missing: $required"
  }
}

Compress-Archive -Path (Join-Path $web '*') -DestinationPath (Join-Path $package 'petty-cash-web.zip') -Force
Copy-Item -LiteralPath $release -Destination (Join-Path $package 'petty-cash-android-unsigned.apk') -Force
Copy-Item -LiteralPath $debug -Destination (Join-Path $package 'petty-cash-android-test.apk') -Force

$backend = Join-Path $package 'petty-cash-backend.zip'
if (Test-Path -LiteralPath $backend) { Remove-Item -LiteralPath $backend }
$backendArchive = [System.IO.Compression.ZipFile]::Open($backend, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  foreach ($name in @('RUN_ON_EXISTING_DATABASE.sql', 'VERIFY_DATABASE.sql', 'DEPLOY.md')) {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
      $backendArchive, (Join-Path $package $name), $name,
      [System.IO.Compression.CompressionLevel]::Optimal
    ) | Out-Null
  }
  foreach ($name in @('manage-user', 'send-push')) {
    $functionDir = Join-Path $root "supabase\functions\$name"
    foreach ($file in (Get-ChildItem -LiteralPath $functionDir -File -Recurse)) {
      $entry = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
      [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $backendArchive, $file.FullName, $entry,
        [System.IO.Compression.CompressionLevel]::Optimal
      ) | Out-Null
    }
  }
} finally {
  $backendArchive.Dispose()
}

$iosZip = Join-Path $package 'petty-cash-ios-source.zip'
if (Test-Path -LiteralPath $iosZip) { Remove-Item -LiteralPath $iosZip }
$iosArchive = [System.IO.Compression.ZipFile]::Open($iosZip, [System.IO.Compression.ZipArchiveMode]::Create)
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
        $iosArchive, $file.FullName, $relative,
        [System.IO.Compression.CompressionLevel]::Optimal
      ) | Out-Null
    }
  }
} finally {
  $iosArchive.Dispose()
}

$checksums = Get-ChildItem -LiteralPath $package -File |
  Where-Object { $_.Name -notin @('SHA256SUMS.txt', 'build_packages.ps1') } |
  Sort-Object Name |
  ForEach-Object { '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $_.Name }
$checksums | Set-Content -LiteralPath (Join-Path $package 'SHA256SUMS.txt') -Encoding ascii
