param([string]$Zip = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$package = Get-Content (Join-Path $root 'package.json') -Raw | ConvertFrom-Json
if (!$Zip) { $Zip = "dist\InstallStreet-$($package.version)-x64.zip" }
$path = Join-Path $root $Zip
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($path)
try {
    $entries = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\','/') })
    foreach ($file in @('InstallStreet.exe','StorageSense.exe','node.exe','resources/install-webview2.ps1','resources/worker/worker.js','resources/electron/main.js','resources/electron/update-flow.js','resources/desktop/platform.js','resources/ui/index.html','resources/ui/storage.html','resources/ui/native-preload.js','resources/backend/InstallStreet.Cli.exe','resources/backend/UpdateHelper.exe','resources/backend/OscdimgSetup.exe','resources/backend/TaskRuntime.dll','resources/backend/AppL/Dimmer.dll','resources/backend/AppL/Python.dll','resources/backend/AppL/iTunes.dll','resources/backend/AppL/iCloud.dll','resources/backend/AppL/iLoader.dll','resources/backend/AppL/VeraCrypt.dll','resources/backend/AppL/WinRAR.dll','resources/backend/AppL/React.dll','resources/backend/AppL/Tailwind.dll','resources/backend/AppL/Emscripten.dll','resources/backend/AppL/AutoHotkey.dll','resources/backend/AppL/Clipchamp.dll','resources/backend/AppL/DaVinciResolve.dll','resources/backend/AppL/GitHubDesktop.dll','resources/backend/AppL/Godot.dll','resources/backend/AppL/Homebrew.dll','resources/backend/AppL/Scoop.dll','resources/backend/AppL/Tailscale.dll','resources/backend/AppL/VisualStudio.dll','resources/backend/AppL/WSL.dll','resources/backend/AppL/Zoom.dll','resources/backend/DisplayCity/Wallpaper.dll','resources/backend/DisplayCity/ConsumerFeatures.dll','resources/backend/VaultHouse/Appointer/desktopn.dll','resources/backend/VaultHouse/Guards/LinkedInRemoval.dll')) {
        if ($entries -notcontains $file) { throw "Missing portable payload: $file" }
    }
    if ($entries -contains 'resources/backend/AppL/VMware.dll') { throw 'VMware is disabled and must not be included in the portable package.' }
    if ($archive.Entries | Where-Object { $_.FullName -match '(^|/)(gh-profile|update-settings)\.json$|(^|/)(node_modules|StatusHQ|tmp|Updates)/|app\.asar$' }) { throw 'Personal, development, or Electron files were included in the portable ZIP.' }
    Write-Output "Native portable ZIP payload verified: $($archive.Entries.Count) entries."
} finally { $archive.Dispose() }
