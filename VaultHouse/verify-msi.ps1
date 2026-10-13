param([string]$Msi = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$package = Get-Content (Join-Path $root 'package.json') -Raw | ConvertFrom-Json
if (!$Msi) { $Msi = "dist\InstallStreet-$($package.version)-x64.msi" }
$path = [IO.Path]::GetFullPath((Join-Path $root $Msi))
if (!(Test-Path -LiteralPath $path)) { throw "MSI not found: $path" }
$installer = New-Object -ComObject WindowsInstaller.Installer
$db = $null
try {
    $db = $installer.OpenDatabase($path, 0)
    foreach ($entry in @(@('ProductName','InstallStreet'), @('ProductVersion',$package.version), @('UpgradeCode','{F10D21AD-8642-4E69-AF2C-48C87797F6C9}'))) {
        $view = $db.OpenView("SELECT ``Value`` FROM ``Property`` WHERE ``Property`` = '$($entry[0])'")
        $view.Execute(); $record = $view.Fetch()
        if (!$record) { throw "Missing MSI property: $($entry[0])" }
        $value = $record.StringData(1)
        if ($entry[0] -eq 'ProductVersion') { $value = ([version]$value).ToString(3) }
        if ($value -ne $entry[1]) { throw "Unexpected MSI property: $($entry[0])=$value" }
        $view.Close(); [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($view)
    }
    $view = $db.OpenView('SELECT `FileName` FROM `File`'); $view.Execute(); $names = @()
    while ($record = $view.Fetch()) { $names += $record.StringData(1).Split('|')[-1] }
    $view.Close()
    foreach ($name in @('InstallStreet.exe','StorageSense.exe','node.exe','InstallStreet.Cli.exe','UpdateHelper.exe','OscdimgSetup.exe','TaskRuntime.dll','desktopn.dll','Wallpaper.dll','ConsumerFeatures.dll','Dimmer.dll','Python.dll','iTunes.dll','iCloud.dll','iLoader.dll','VeraCrypt.dll','WinRAR.dll','React.dll','Tailwind.dll','Emscripten.dll','AutoHotkey.dll','Clipchamp.dll','DaVinciResolve.dll','GitHubDesktop.dll','Godot.dll','Homebrew.dll','Scoop.dll','Tailscale.dll','VisualStudio.dll','WSL.dll','Zoom.dll','LinkedInRemoval.dll','running.ico','worker.js','index.html','install-webview2.ps1')) {
        if ($names -notcontains $name) { throw "Missing MSI payload: $name" }
    }
    if ($names -contains 'VMware.dll') { throw 'VMware is disabled and must not be included in the MSI.' }
    if ($names -contains 'app.asar') { throw 'Electron package unexpectedly included in MSI.' }
    Write-Output "MSI metadata and $($names.Count) native payload files verified."
} finally {
    if ($db) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($db) }
    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($installer)
}
