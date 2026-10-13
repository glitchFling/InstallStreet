$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (!(Test-Path -LiteralPath $compiler)) { throw '.NET Framework C# compiler was not found.' }
$stage = Join-Path $root ('tmp\build\' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
$artifacts = New-Object 'System.Collections.Generic.List[string]'
function Compile([string]$Source, [string]$Output, [string]$Target = 'library', [bool]$Embed = $false, [bool]$Runtime = $false, [bool]$Forms = $false) {
    $destination = Join-Path $stage $Output
    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
    $compiled = Join-Path $stage ($Output.Replace('\','_'))
    $options = @('/nologo',('/target:' + $Target),'/platform:anycpu',('/out:' + $compiled))
    if ($Target -ne 'library') { $options += '/win32manifest:' + (Join-Path $root 'VaultHouse\require-admin.manifest') }
    if ($Runtime) { $options += '/reference:' + (Join-Path $stage 'TaskRuntime.dll') }
    if ($Embed) { $options += '/resource:' + (Join-Path $root 'workers\task.ps1') + ',InstallStreet.TaskScript.ps1' }
    if ($Forms) { $options += '/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll' }
    $options += Join-Path $root $Source
    & $compiler @options
    if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $Source" }
    if ($compiled -ne $destination) { Move-Item -LiteralPath $compiled -Destination $destination }
    $artifacts.Add($Output)
}
Compile 'VaultHouse\TaskRuntime.cs' 'TaskRuntime.dll'
Compile 'AppL\GoogleChrome.cs' 'AppL\GoogleChrome.dll'
Compile 'DisplayCity\Wallpaper.cs' 'DisplayCity\Wallpaper.dll'
Compile 'DisplayCity\ConsumerFeatures.cs' 'DisplayCity\ConsumerFeatures.dll'
foreach ($module in @('AppL\winget','AppL\Git','AppL\GitHubCLI','AppL\codex','AppL\Rufus','AppL\VSCode','AppL\Dotnet10','AppL\Roblox','AppL\IconsExtract','AppL\Dimmer','AppL\Python','AppL\iTunes','AppL\iCloud','AppL\iLoader','AppL\VeraCrypt','AppL\WinRAR','AppL\nvm-windows','AppL\Playwright','AppL\React','AppL\Tailwind','AppL\Emscripten','AppL\7zip','AppL\powertoys','AppL\terminal','AppL\notepadplusplus','AppL\vlc','AppL\firefox','AppL\everything','AppL\sharex','AppL\obs','AppL\steam','AppL\discord','AppL\nextdns','AppL\googledrive','AppL\chatgpt','AppL\AutoHotkey','AppL\Clipchamp','AppL\DaVinciResolve','AppL\GitHubDesktop','AppL\Godot','AppL\Homebrew','AppL\Scoop','AppL\Tailscale','AppL\VisualStudio','AppL\WSL','AppL\Zoom','DisplayCity\DarkMode','DisplayCity\DeveloperMode','DisplayCity\LongPaths','DisplayCity\DisableBingSearch','DisplayCity\TaskbarLeft','DisplayCity\EndTaskContext','Files\showHiddenFiles','Files\showFileExtensions','VaultHouse\RunningIcon','VaultHouse\Appointer\desktopn')) {
    Compile ($module + '.cs') ($module + '.dll') 'library' $true $true
}
foreach ($module in @('__init__','AppL\init','DisplayCity\init','Files\__set__\applyChanges','VaultHouse\build-running-helper')) {
    Compile ($module + '.cs') ($module + '.dll') 'library' $false $true
}
Compile 'workers\WhereAppL\whereappl.cs' 'workers\WhereAppL\whereappl.dll'
Compile 'VaultHouse\Guards\LinkedInRemoval.cs' 'VaultHouse\Guards\LinkedInRemoval.dll' 'library' $false $true
Compile 'VaultHouse\Guards\AdminRights.cs' 'VaultHouse\Guards\AdminRights.dll'
Compile 'StorageSense\Launcher.cs' 'StorageSense.exe' 'winexe'
Compile 'VaultHouse\Launcher.cs' 'InstallStreet.exe' 'winexe'
Compile 'VaultHouse\InstallStreet.cs' 'InstallStreet.Cli.exe' 'exe'
Compile 'VaultHouse\RunningHelper.cs' 'RunningHelper.exe' 'exe'
Compile 'VaultHouse\oscdimg.cs' 'OscdimgSetup.exe' 'exe'
Compile 'VaultHouse\UpdateHelper.cs' 'UpdateHelper.exe' 'winexe'
# Publish only after every source has compiled successfully. Renaming also allows
# an existing process to finish with its already loaded executable/library.
$previous = Join-Path $stage 'previous'
New-Item -ItemType Directory -Path $previous -Force | Out-Null
foreach ($artifact in $artifacts) {
    $destination = [IO.Path]::GetFullPath((Join-Path $root $artifact))
    if (!$destination.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Invalid output: $destination" }
    if (Test-Path -LiteralPath $destination) {
        $backup = Join-Path $previous ($artifact.Replace('\','_'))
        Move-Item -LiteralPath $destination -Destination $backup
    }
    Move-Item -LiteralPath (Join-Path $stage $artifact) -Destination $destination
}
Write-Output ('Built ' + $artifacts.Count + ' artifacts.')
