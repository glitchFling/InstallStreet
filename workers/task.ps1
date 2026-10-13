param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('winget','git','gh','chrome','codex','rufus','playwright','nvm-windows','react','tailwind','emscripten','vscode','dotnet10','roblox','iconsextract','dimmer','python','itunes','icloud','iloader','veracrypt','winrar','desktop-apps','dark-mode','hidden-files','file-extensions','running-icon','7zip','powertoys','terminal','notepadplusplus','vlc','firefox','everything','sharex','obs','steam','discord','nextdns','googledrive','chatgpt','ahk','clipchamp','davinciresolve','githubdesktop','godot','homebrew','scoop','tailscale','visualstudio','wsl','zoom','developer-mode','long-paths','disable-bing-search','taskbar-left','end-task-context')]
    [string]$Task,
    [ValidateSet('Check','Run')][string]$Mode = 'Check'
)
$ErrorActionPreference = 'Stop'
$taskRoot = $env:INSTALLSTREET_TASK_ROOT
if (!$taskRoot) { $taskRoot = Split-Path $PSScriptRoot -Parent }
$taskDataRoot = $env:INSTALLSTREET_DATA_ROOT
if (!$taskDataRoot) { $taskDataRoot = $taskRoot }

function Find-Winget {
    $candidates = @()
    $command = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($command) { $candidates += $command.Source }
    $alias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path -LiteralPath $alias) { $candidates += $alias }
    $package = Get-AppxPackage Microsoft.DesktopAppInstaller | Select-Object -First 1
    if ($package) {
        $candidate = Join-Path $package.InstallLocation 'winget.exe'
        if (Test-Path -LiteralPath $candidate) { $candidates += $candidate }
    }
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        try {
            $version = & $candidate --version 2>&1
            if ($LASTEXITCODE -eq 0 -and "$version" -match 'v\d+\.\d+') { return $candidate }
        } catch { }
    }
    return $null
}
function Test-Winget {
    return [bool](Find-Winget)
}
function Test-Chrome {
    $dll = Join-Path $taskRoot 'AppL\GoogleChrome.dll'
    if (!(Test-Path -LiteralPath $dll)) { throw 'GoogleChrome.dll is missing. Rebuild InstallStreet.' }
    [Reflection.Assembly]::LoadFrom($dll) | Out-Null
    return [GoogleChromeTask]::IsInstalled()
}
function Test-RegistryValue([string]$Path, [string]$Name, [int]$Value) {
    if (!(Test-Path $Path)) { return $false }
    return ((Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue).$Name -eq $Value)
}
function Refresh-TaskEnvironment {
    foreach ($name in @('NVM_HOME','NVM_SYMLINK')) {
        $value = [Environment]::GetEnvironmentVariable($name, 'User')
        if (!$value) { $value = [Environment]::GetEnvironmentVariable($name, 'Machine') }
        if ($value) { [Environment]::SetEnvironmentVariable($name, $value, 'Process') }
    }
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = [Environment]::ExpandEnvironmentVariables($machine + ';' + $user + ';' + $env:Path)
}
function Find-Nvm {
    $command = Get-Command nvm.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    foreach ($folder in @($env:NVM_HOME, "$env:APPDATA\nvm", "$env:LOCALAPPDATA\nvm", "$env:ProgramFiles\nvm")) {
        if ($folder) {
            $candidate = Join-Path $folder 'nvm.exe'
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    }
    return $null
}
function Test-NvmSetup {
    Refresh-TaskEnvironment
    $exe = Find-Nvm
    if (!$exe) { return $false }
    $version = & $exe version 2>&1
    if ($LASTEXITCODE -ne 0 -or "$version" -notmatch '\d+\.\d+') { return $false }
    $node = Get-Command node.exe -ErrorAction SilentlyContinue
    $npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if (!$node -or !$npm) { return $false }
    $nodeVersion = & $node.Source --version 2>&1
    if ($LASTEXITCODE -ne 0 -or "$nodeVersion" -notmatch '^v\d+\.\d+') { return $false }
    $npmVersion = & $npm.Source --version 2>&1
    return ($LASTEXITCODE -eq 0 -and "$npmVersion" -match '\d+\.\d+')
}
function Get-PlaywrightProject {
    return (Join-Path $taskDataRoot 'BRAINSTORM\playwright')
}
function Test-Playwright {
    Refresh-TaskEnvironment
    $node = Get-Command node.exe -ErrorAction SilentlyContinue
    $project = Get-PlaywrightProject
    if (!$node -or !(Test-Path -LiteralPath (Join-Path $project 'node_modules\@playwright\test\package.json'))) { return $false }
    Push-Location -LiteralPath $project
    try {
        & $node.Source -e "const fs=require('fs');const p=require('@playwright/test');for(const name of ['chromium','firefox','webkit']){if(!fs.existsSync(p[name].executablePath()))process.exit(1)}" 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    } finally { Pop-Location }
}
function Install-Playwright {
    Refresh-TaskEnvironment
    $npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
    $node = Get-Command node.exe -ErrorAction SilentlyContinue
    if (!$npm -or !$node) { throw 'Playwright needs Node.js and npm. Resolve the Node setup failure, then retry.' }
    $project = Get-PlaywrightProject
    New-Item -ItemType Directory -Path $project -Force | Out-Null
    Push-Location -LiteralPath $project
    try {
        Write-Output "Setting up Playwright in $project"
        if (!(Test-Path -LiteralPath 'package.json')) {
            & $npm.Source init playwright@latest --yes -- --quiet
            if ($LASTEXITCODE -ne 0) { throw "Playwright initialization failed: $LASTEXITCODE. Retry to repair the installation." }
        } else {
            # Preserve generated configuration and user tests on partial-install retries.
            & $npm.Source install --save-dev '@playwright/test@latest'
            if ($LASTEXITCODE -ne 0) { throw "Playwright package installation failed: $LASTEXITCODE" }
        }
        & $node.Source (Join-Path $project 'node_modules\@playwright\test\cli.js') install
        if ($LASTEXITCODE -ne 0) { throw "Playwright browser installation failed: $LASTEXITCODE" }
    } finally { Pop-Location }
}

function Get-ReactProject { return (Join-Path $taskDataRoot 'BRAINSTORM\react') }
function Get-TailwindProject { return (Join-Path $taskDataRoot 'BRAINSTORM\tailwind-css') }
function Get-EmscriptenRoot { return (Join-Path $taskDataRoot 'BRAINSTORM\emsdk') }
function Set-ProjectProperty($Object, [string]$Name, $Value) {
    if ($Object.PSObject.Properties[$Name]) { $Object.$Name = $Value }
    else { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}
function Set-NodeProjectFiles([string]$Project, [string]$Kind) {
    New-Item -ItemType Directory -Path $Project -Force | Out-Null
    $packagePath = Join-Path $Project 'package.json'
    if (Test-Path -LiteralPath $packagePath) { $package = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json }
    else {
        $name = if ($Kind -eq 'react') { 'installstreet-react-app' } else { 'installstreet-tailwind-app' }
        $package = ('{"name":"' + $name + '","version":"1.0.0","private":true,"type":"module","scripts":{},"dependencies":{},"devDependencies":{}}') | ConvertFrom-Json
    }
    if (!$package.scripts) { Set-ProjectProperty $package 'scripts' ([pscustomobject]@{}) }
    Set-ProjectProperty $package.scripts 'dev' 'vite'
    Set-ProjectProperty $package.scripts 'build' 'vite build'
    if (!$package.dependencies) { Set-ProjectProperty $package 'dependencies' ([pscustomobject]@{}) }
    if (!$package.devDependencies) { Set-ProjectProperty $package 'devDependencies' ([pscustomobject]@{}) }
    Set-ProjectProperty $package.devDependencies 'vite' 'latest'
    if ($Kind -eq 'react') {
        Set-ProjectProperty $package.dependencies 'react' 'latest'; Set-ProjectProperty $package.dependencies 'react-dom' 'latest'; Set-ProjectProperty $package.dependencies 'lucide-react' 'latest'
        Set-ProjectProperty $package.devDependencies '@vitejs/plugin-react' 'latest'
        $files = @{
            'index.html' = '<!doctype html><html lang="en"><head><meta charset="UTF-8"/><meta name="viewport" content="width=device-width, initial-scale=1.0"/><title>React app</title></head><body><div id="root"></div><script type="module" src="/src/main.jsx"></script></body></html>'
            'vite.config.js' = "import { defineConfig } from 'vite'`nimport react from '@vitejs/plugin-react'`n`nexport default defineConfig({ plugins: [react()] })`n"
            'src/main.jsx' = "import React from 'react'`nimport { createRoot } from 'react-dom/client'`nimport App from './App.jsx'`nimport './style.css'`n`ncreateRoot(document.getElementById('root')).render(<React.StrictMode><App /></React.StrictMode>)`n"
            'src/App.jsx' = "import { Heart } from 'lucide-react'`n`nexport default function App() {`n  return <main><h1>React is ready</h1><p>Edit <code>src/App.jsx</code> to get started.</p><Heart aria-label=`"heart`" /></main>`n}`n"
            'src/style.css' = "body { margin: 0; min-width: 320px; min-height: 100vh; font-family: system-ui, sans-serif; display: grid; place-items: center; background: #111827; color: #f9fafb; } main { text-align: center; } code { color: #61dafb; }"
        }
    } else {
        Set-ProjectProperty $package.devDependencies 'tailwindcss' 'latest'; Set-ProjectProperty $package.devDependencies '@tailwindcss/vite' 'latest'
        $files = @{
            'index.html' = '<!doctype html><html lang="en"><head><meta charset="UTF-8"/><meta name="viewport" content="width=device-width, initial-scale=1.0"/><title>Tailwind CSS app</title></head><body><main class="min-h-screen grid place-items-center bg-slate-950 text-white"><section class="text-center"><h1 class="text-4xl font-bold text-sky-400">Tailwind CSS is ready</h1><p class="mt-4 text-slate-300">Edit index.html to get started.</p></section></main><script type="module" src="/src/main.js"></script></body></html>'
            'vite.config.js' = "import { defineConfig } from 'vite'`nimport tailwindcss from '@tailwindcss/vite'`n`nexport default defineConfig({ plugins: [tailwindcss()] })`n"
            'src/main.js' = "import './style.css'`n"
            'src/style.css' = "@import 'tailwindcss';`n"
        }
    }
    foreach ($relative in $files.Keys) {
        $path = Join-Path $Project $relative
        if (!(Test-Path -LiteralPath $path)) { $parent = Split-Path $path -Parent; New-Item -ItemType Directory -Path $parent -Force | Out-Null; Set-Content -LiteralPath $path -Value $files[$relative] -Encoding utf8 }
    }
    Set-Content -LiteralPath $packagePath -Value ($package | ConvertTo-Json -Depth 20) -Encoding utf8
}
function Install-NodeProject([string]$Project, [string]$Kind) {
    Refresh-TaskEnvironment
    $npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if (!$npm) { throw "$Kind setup needs Node.js and npm. Resolve the Node setup failure, then retry." }
    Set-NodeProjectFiles $Project $Kind
    Push-Location -LiteralPath $Project
    try {
        & $npm.Source install
        if ($LASTEXITCODE -ne 0) { throw "$Kind npm dependency installation failed: $LASTEXITCODE" }
        & $npm.Source run build
        if ($LASTEXITCODE -ne 0) { throw "$Kind starter project build failed: $LASTEXITCODE" }
    } finally { Pop-Location }
}
function Test-NodeProject([string]$Project, [string[]]$Packages) {
    Refresh-TaskEnvironment
    $node = Get-Command node.exe -ErrorAction SilentlyContinue
    if (!$node -or !(Test-Path -LiteralPath (Join-Path $Project 'package.json'))) { return $false }
    foreach ($package in $Packages) { if (!(Test-Path -LiteralPath (Join-Path $Project ("node_modules\" + $package + '\package.json')))) { return $false } }
    Push-Location -LiteralPath $Project
    try { & $node.Source (Join-Path $Project 'node_modules\vite\bin\vite.js') build 2>&1 | Out-Null; return ($LASTEXITCODE -eq 0) }
    finally { Pop-Location }
}
function Test-Emscripten {
    $emcc = Join-Path (Get-EmscriptenRoot) 'upstream\emscripten\emcc.bat'
    if (!(Test-Path -LiteralPath $emcc)) { return $false }
    & $emcc --version 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}
function Install-Emscripten {
    $root = Get-EmscriptenRoot
    $git = Find-GitTool 'git'
    if (!$git) { throw 'Emscripten setup needs Git. Resolve the Git setup failure, then retry.' }
    if (!(Test-Path -LiteralPath (Join-Path $root '.git'))) {
        if (Test-Path -LiteralPath $root) { throw "The Emscripten SDK folder exists but is not a Git checkout: $root. Move it and retry." }
        New-Item -ItemType Directory -Path (Split-Path $root -Parent) -Force | Out-Null
        & $git clone --depth 1 https://github.com/emscripten-core/emsdk.git $root
        if ($LASTEXITCODE -ne 0) { throw "Cloning the official Emscripten SDK failed: $LASTEXITCODE" }
    } else {
        & $git -C $root pull --ff-only
        if ($LASTEXITCODE -ne 0) { throw "Updating the Emscripten SDK failed: $LASTEXITCODE" }
    }
    $setup = Join-Path $root 'emsdk.bat'
    if (!(Test-Path -LiteralPath $setup)) { throw "Emscripten SDK bootstrap script is missing: $setup" }
    Push-Location -LiteralPath $root
    try {
        & $setup install latest
        if ($LASTEXITCODE -ne 0) { throw "Emscripten latest SDK installation failed: $LASTEXITCODE" }
        & $setup activate latest
        if ($LASTEXITCODE -ne 0) { throw "Emscripten SDK activation failed: $LASTEXITCODE" }
        $launcher = Join-Path $root 'Open Emscripten Command Prompt.cmd'
        if (!(Test-Path -LiteralPath $launcher)) { Set-Content -LiteralPath $launcher -Encoding ascii -Value "@echo off`r`ncall `"%~dp0emsdk_env.bat`"`r`nif errorlevel 1 exit /b %errorlevel%`r`ncd /d `"%USERPROFILE%`"`r`ncmd /k`r`n" }
    } finally { Pop-Location }
    if (!(Test-Emscripten)) { throw 'Emscripten setup ran but emcc did not pass its version check. Retry setup.' }
}

function Test-WingetPackage([string]$Id, [string]$Source = 'winget') {
    $exe = Find-Winget
    if (!$exe) { return $false }
    $result = & $exe list --id $Id --exact --source $Source --disable-interactivity 2>&1
    return ($LASTEXITCODE -eq 0 -and "$result" -match [regex]::Escape($Id))
}
function Test-DaVinciResolve {
    foreach ($path in @("$env:ProgramFiles\Blackmagic Design\DaVinci Resolve\Resolve.exe", "${env:ProgramFiles(x86)}\Blackmagic Design\DaVinci Resolve\Resolve.exe")) {
        if (Test-Path -LiteralPath $path -PathType Leaf) { return $true }
    }
    foreach ($base in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')) {
        if (Test-Path $base) { foreach ($key in (Get-ChildItem $base -ErrorAction SilentlyContinue)) { $item = Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue; if ($item.DisplayName -match '^DaVinci Resolve( |$)') { return $true } } }
    }
    return $false
}
function Test-Scoop {
    Refresh-TaskEnvironment
    $command = Get-Command scoop -ErrorAction SilentlyContinue
    if (!$command) { return $false }
    & $command.Source --version 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}
function Test-Homebrew {
    $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if (!$wsl) { return $false }
    $distros = @(& $wsl.Source --list --quiet 2>$null)
    if ($LASTEXITCODE -ne 0) { return $false }
    foreach ($entry in $distros) {
        $distro = ([string]$entry).Trim([char]0).Trim()
        if (!$distro) { continue }
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo.FileName = $wsl.Source
        $process.StartInfo.Arguments = '-d "' + $distro.Replace('"','') + '" --exec sh -lc "command -v brew >/dev/null 2>&1"'
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        try {
            if (!$process.Start()) { continue }
            if (!$process.WaitForExit(10000)) { $process.Kill(); continue }
            if ($process.ExitCode -eq 0) { return $true }
        } catch { } finally { $process.Dispose() }
    }
    return $false
}
function Open-ManualInstallPage([string]$Url, [string]$Message) {
    Write-Output $Message
    Start-Process -FilePath $Url
    Write-Output 'Complete the publisher setup, then use Check only or Retry selected to verify.'
}
function Install-WingetPackage([string]$Id, [string]$Locale = '', [string]$Source = 'winget') {
    if (!(Test-Winget)) { throw 'WinGet is unavailable. Set up WinGet first.' }
    $exe = Find-Winget
    $arguments = @('install','--id',$Id,'--exact','--source',$Source,'--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
    if ($Locale) { $arguments += @('--locale',$Locale) }
    & $exe @arguments
    if ($LASTEXITCODE -notin @(0,3010)) { throw "$Id installation failed: $LASTEXITCODE" }
    if ($LASTEXITCODE -eq 3010) { Write-Output "$Id requested a restart." }
}
function Find-VSCode {
    foreach ($path in @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe", "$env:ProgramFiles\Microsoft VS Code\Code.exe", "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe")) {
        if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    }
    foreach ($key in @('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Code.exe','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Code.exe')) {
        if (Test-Path $key) { $path = (Get-Item $key).GetValue(''); if ($path -and (Test-Path -LiteralPath $path)) { return $path } }
    }
    return $null
}
function Find-Rufus {
    $command = Get-Command rufus.exe -ErrorAction SilentlyContinue
    if ($command -and (Test-Path -LiteralPath $command.Source)) { return $command.Source }
    foreach ($base in @("$env:LOCALAPPDATA\Microsoft\WinGet", "$env:ProgramFiles\WinGet")) {
        $link = Join-Path $base 'Links\rufus.exe'
        if (Test-Path -LiteralPath $link -PathType Leaf) { return $link }
        $packages = Join-Path $base 'Packages'
        if (Test-Path -LiteralPath $packages) {
            foreach ($folder in (Get-ChildItem -LiteralPath $packages -Directory -Filter 'Rufus.Rufus*')) {
                $exe = Get-ChildItem -LiteralPath $folder.FullName -File -Recurse -Filter 'rufus*.exe' | Select-Object -First 1
                if ($exe) { return $exe.FullName }
            }
        }
    }
    return $null
}
function Find-DesktopShortcut([string]$Target, [string]$Desktop, [string]$Arguments = '', [string]$WorkingDirectory = '') {
    if (!$Target -or !$Desktop) { return $null }
    $folders = @($Desktop)
    $userDesktop = [Environment]::GetFolderPath('DesktopDirectory')
    if ($userDesktop -and [IO.Path]::GetFullPath($Desktop).TrimEnd('\').Equals([IO.Path]::GetFullPath($userDesktop).TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
        $common = [Environment]::GetFolderPath('CommonDesktopDirectory')
        if ($common) { $folders += $common }
    }
    $shell = $null; $shortcut = $null
    try {
        $shell = New-Object -ComObject WScript.Shell
        foreach ($folder in ($folders | Select-Object -Unique)) {
            foreach ($file in (Get-ChildItem -LiteralPath $folder -Filter '*.lnk' -File -ErrorAction SilentlyContinue)) {
                try {
                    $shortcut = $shell.CreateShortcut($file.FullName)
                    if ((!$WorkingDirectory -or ($shortcut.WorkingDirectory -and [IO.Path]::GetFullPath($shortcut.WorkingDirectory).TrimEnd('\').Equals([IO.Path]::GetFullPath($WorkingDirectory).TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase))) -and $shortcut.Arguments -eq $Arguments -and $shortcut.TargetPath -and [IO.Path]::GetFullPath($shortcut.TargetPath).Equals([IO.Path]::GetFullPath($Target), [StringComparison]::OrdinalIgnoreCase)) { return $file.FullName }
                } catch { } finally {
                    if ($shortcut) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut); $shortcut = $null }
                }
            }
        }
        return $null
    } finally {
        if ($shortcut) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut) }
        if ($shell) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) }
    }
}
function Test-DesktopShortcut([string]$Name, [string]$Target, [string]$Desktop = [Environment]::GetFolderPath('DesktopDirectory'), [string]$Arguments = '', [string]$WorkingDirectory = '') {
    return [bool](Find-DesktopShortcut $Target $Desktop $Arguments $WorkingDirectory)
}
function New-DesktopShortcut([string]$Name, [string]$Target, [string]$Desktop = [Environment]::GetFolderPath('DesktopDirectory'), [string]$Arguments = '', [string]$WorkingDirectory = '') {
    if (!$Target -or !(Test-Path -LiteralPath $Target -PathType Leaf)) { throw "Cannot create $Name shortcut: executable was not found." }
    if (!$Desktop) { throw 'The desktop folder could not be located.' }
    if (Test-DesktopShortcut $Name $Target $Desktop $Arguments $WorkingDirectory) { Write-Output "$Name uses an existing desktop shortcut."; return }
    if (!(Test-Path -LiteralPath $Desktop)) { New-Item -ItemType Directory -Path $Desktop -Force | Out-Null }
    $shell = $null; $shortcut = $null
    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut((Join-Path $Desktop ($Name + '.lnk')))
        $shortcut.TargetPath = [IO.Path]::GetFullPath($Target)
        $shortcut.Arguments = $Arguments
        $shortcut.WorkingDirectory = $(if ($WorkingDirectory) { $WorkingDirectory } else { Split-Path $Target -Parent })
        $shortcut.IconLocation = $Target + ',0'
        $shortcut.Description = $Name
        $shortcut.Save()
    } finally {
        if ($shortcut) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut) }
        if ($shell) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) }
    }
    if (!(Test-DesktopShortcut $Name $Target $Desktop $Arguments $WorkingDirectory)) { throw "$Name desktop shortcut verification failed." }
    Write-Output "$Name desktop shortcut is ready."
}
function Test-Dotnet10 {
    Refresh-TaskEnvironment
    $paths = @("$env:ProgramFiles\dotnet\dotnet.exe", "${env:ProgramFiles(x86)}\dotnet\dotnet.exe")
    $command = Get-Command dotnet.exe -ErrorAction SilentlyContinue
    if ($command) { $paths = @($command.Source) + $paths }
    foreach ($path in ($paths | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $sdks = & $path --list-sdks 2>&1
            if ($LASTEXITCODE -eq 0 -and ($sdks | Where-Object { "$_" -match '^10\.\d+\.\d+\s' })) { return $true }
        }
    }
    return $false
}
function Find-Roblox {
    $versions = Join-Path $env:LOCALAPPDATA 'Roblox\Versions'
    if (Test-Path -LiteralPath $versions) {
        foreach ($directory in (Get-ChildItem -LiteralPath $versions -Directory -Filter 'version-*' | Sort-Object LastWriteTime -Descending)) {
            $exe = Join-Path $directory.FullName 'RobloxPlayerBeta.exe'
            if (Test-Path -LiteralPath $exe -PathType Leaf) { return $exe }
        }
    }
    return $null
}
function Find-IconsExtract {
    $command = Get-Command iconsext.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    foreach ($folder in @("$env:LOCALAPPDATA\InstallStreet\Apps\IconsExtract", "$env:ProgramFiles\NirSoft\IconsExtract", "${env:ProgramFiles(x86)}\NirSoft\IconsExtract", "$env:ProgramFiles\IconsExtract", "${env:ProgramFiles(x86)}\IconsExtract")) {
        $target = Join-Path $folder 'iconsext.exe'
        if (Test-Path -LiteralPath $target -PathType Leaf) { return $target }
    }
    return $null
}
function Test-DimmerBinary([string]$Path) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $info = (Get-Item -LiteralPath $Path).VersionInfo
    $version = New-Object Version($info.FileMajorPart, $info.FileMinorPart, $info.FileBuildPart, $info.FilePrivatePart)
    return ($version -ge [version]'2.0.1.0')
}
function Find-Dimmer {
    $path = Join-Path $env:LOCALAPPDATA 'InstallStreet\Apps\Dimmer\Dimmer.exe'
    if (Test-DimmerBinary $path) { return $path }
    foreach ($folder in @("$env:ProgramFiles\Dimmer", "${env:ProgramFiles(x86)}\Dimmer")) {
        $path = Join-Path $folder 'Dimmer.exe'
        if (Test-DimmerBinary $path) { return $path }
    }
    return $null
}
function Start-Dimmer([string]$Target) {
    if (!(Test-DimmerBinary $Target)) { throw 'Dimmer could not be verified before launch.' }
    $session = (Get-Process -Id $PID).SessionId
    if (Get-Process -Name Dimmer -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $session }) {
        Write-Output 'Dimmer is already running in this Windows session; no second instance was started.'
        return
    }
    $process = Start-Process -FilePath $Target -WorkingDirectory (Split-Path $Target -Parent) -WindowStyle Hidden -PassThru
    Write-Output "Dimmer started after installation (PID $($process.Id))."
}
function Find-Python {
    Refresh-TaskEnvironment
    $paths = @("$env:LOCALAPPDATA\Programs\Python\Python314\python.exe", "$env:ProgramFiles\Python314\python.exe")
    $command = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($command -and $command.Source -notlike '*\Microsoft\WindowsApps\*') { $paths = @($command.Source) + $paths }
    foreach ($base in @('HKCU:\Software\Python\PythonCore\3.14\InstallPath', 'HKLM:\Software\Python\PythonCore\3.14\InstallPath', 'HKLM:\Software\WOW6432Node\Python\PythonCore\3.14\InstallPath')) {
        if (Test-Path $base) {
            $key = Get-Item $base
            $executable = $key.GetValue('ExecutablePath')
            if ($executable) { $paths += $executable }
            elseif ($key.GetValue('')) { $paths += Join-Path $key.GetValue('') 'python.exe' }
        }
    }
    foreach ($path in ($paths | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $version = & $path --version 2>&1
            if ($LASTEXITCODE -eq 0 -and "$version" -match '^Python 3\.(\d+)\.' -and [int]$Matches[1] -ge 14) { return $path }
        }
    }
    return $null
}
function Test-Python {
    $exe = Find-Python
    if (!$exe) { return $false }
    $pip = & $exe -m pip --version 2>&1
    return ($LASTEXITCODE -eq 0 -and "$pip" -match '^pip \d+')
}
function Find-AppleDesktop([string]$Name) {
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        $relative = if ($Name -eq 'itunes') { 'iTunes\iTunes.exe' } else { 'Common Files\Apple\Internet Services\iCloud.exe' }
        $target = Join-Path $base $relative
        if (Test-Path -LiteralPath $target -PathType Leaf) { return $target }
    }
    return $null
}
function Find-iLoader {
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
        foreach ($relative in @('iloader\iloader.exe','Programs\iloader\iloader.exe')) {
            $target = Join-Path $base $relative
            if (Test-Path -LiteralPath $target -PathType Leaf) { return $target }
        }
    }
    return $null
}
function Find-VeraCrypt {
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        $target = Join-Path $base 'VeraCrypt\VeraCrypt.exe'
        if (Test-Path -LiteralPath $target -PathType Leaf) { return $target }
    }
    return $null
}
function Find-WinRAR {
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        $target = Join-Path $base 'WinRAR\WinRAR.exe'
        if (Test-Path -LiteralPath $target -PathType Leaf) { return $target }
    }
    return $null
}
function Install-DirectInstaller([string]$Url, [string]$Name, [string]$Sha256, [bool]$Apple = $false, [bool]$Msi = $false) {
    $directory = Join-Path $taskDataRoot ('tmp\Installers\' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $installer = Join-Path $directory $Name
    & (Join-Path $env:SystemRoot 'System32\curl.exe') --fail --location --retry 3 --connect-timeout 30 --max-time 600 $Url --output $installer
    if ($LASTEXITCODE -ne 0) { throw "$Name download failed: $LASTEXITCODE" }
    if ((Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash -ne $Sha256) { throw "$Name SHA256 verification failed." }
    if ($Apple) {
        $signature = Get-AuthenticodeSignature -LiteralPath $installer
        if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Apple (Inc\.|Computer, Inc\.)') { throw "$Name Apple signature verification failed." }
    }
    if ($Msi) {
        $arguments = '/i "' + $installer + '" /qn /norestart /L*v "' + (Join-Path $directory 'install.log') + '"'
        $process = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\msiexec.exe') -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
    } else {
        $arguments = '/quiet /norestart /log "' + (Join-Path $directory 'install.log') + '"'
        $process = Start-Process -FilePath $installer -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
    }
    if ($process.ExitCode -notin @(0,3010)) { throw "$Name installation failed: $($process.ExitCode). Logs and installer: $directory" }
    if ($process.ExitCode -eq 3010) { Write-Output "$Name requested a manual restart." }
    Remove-Item -LiteralPath $installer
}
function Get-DesktopApps {
    $system = [Environment]::SystemDirectory
    foreach ($entry in @(@('PowerShell', 'WindowsPowerShell\v1.0\powershell.exe'), @('Command Prompt', 'cmd.exe'))) {
        $target = Join-Path $system $entry[1]
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            [pscustomobject]@{ Name = $entry[0]; Target = $target; Arguments = ''; WorkingDirectory = $env:USERPROFILE }
        }
    }
    foreach ($entry in @(@('Rufus','Find-Rufus'),@('Visual Studio Code','Find-VSCode'),@('Roblox Player','Find-Roblox'),@('IconsExtract','Find-IconsExtract'),@('Dimmer','Find-Dimmer'))) {
        $target = & $entry[1]
        if ($target) { [pscustomobject]@{ Name = $entry[0]; Target = $target; Arguments = $(if ($entry[0] -eq 'Roblox Player') { '-app' } else { '' }) } }
    }
    foreach ($entry in @(@('iTunes','itunes'),@('iCloud','icloud'))) {
        $target = Find-AppleDesktop $entry[1]
        if ($target) { [pscustomobject]@{ Name = $entry[0]; Target = $target; Arguments = '' } }
    }
    $target = Find-iLoader
    if ($target) { [pscustomobject]@{ Name = 'iLoader'; Target = $target; Arguments = '' } }
    $target = Find-VeraCrypt
    if ($target) { [pscustomobject]@{ Name = 'VeraCrypt'; Target = $target; Arguments = '' } }
    $target = Find-WinRAR
    if ($target) { [pscustomobject]@{ Name = 'WinRAR'; Target = $target; Arguments = '' } }
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
        $target = Join-Path $base 'Google\Chrome\Application\chrome.exe'
        if (Test-Path -LiteralPath $target) { [pscustomobject]@{ Name = 'Google Chrome'; Target = $target; Arguments = '' }; break }
    }
    $package = Get-AppxPackage | Where-Object { $_.Name -match '(^|[.])Codex($|[.])|OpenAI.*Codex' } | Select-Object -First 1
    if ($package) {
        $manifest = Get-AppxPackageManifest -Package $package.PackageFullName
        $application = $manifest.Package.Applications.Application | Select-Object -First 1
        if ($application.Id) {
            [pscustomobject]@{ Name = 'Codex'; Target = (Join-Path $env:WINDIR 'explorer.exe'); Arguments = ('shell:AppsFolder\' + $package.PackageFamilyName + '!' + $application.Id) }
        }
    }
}
function Test-DesktopApps {
    foreach ($app in @(Get-DesktopApps)) {
        if (!(Test-DesktopShortcut $app.Name $app.Target -Arguments $app.Arguments -WorkingDirectory $app.WorkingDirectory)) { return $false }
    }
    return $true
}
function Find-GitTool([string]$Tool) {
    Refresh-TaskEnvironment
    $command = Get-Command ($Tool + '.exe') -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $paths = if ($Tool -eq 'git') {
        @("$env:ProgramFiles\Git\cmd\git.exe", "${env:ProgramFiles(x86)}\Git\cmd\git.exe", "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe")
    } else {
        @("$env:ProgramFiles\GitHub CLI\gh.exe", "${env:ProgramFiles(x86)}\GitHub CLI\gh.exe", "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe")
    }
    foreach ($path in $paths) { if (Test-Path -LiteralPath $path -PathType Leaf) { return $path } }
    return $null
}
function Test-GitTool([string]$Tool) {
    $exe = Find-GitTool $Tool
    if (!$exe) { return $false }
    $version = & $exe --version 2>&1
    return ($LASTEXITCODE -eq 0 -and "$version" -match '\d+\.\d+')
}
function Test-Task {
    switch ($Task) {
        'winget' { return (Test-Winget) }
        'git' { return (Test-GitTool 'git') }
        'gh' { return (Test-GitTool 'gh') }
        'chrome' { return (Test-Chrome) }
        'rufus' { $target = Find-Rufus; return ($target -and (Test-DesktopShortcut 'Rufus' $target)) }
        'vscode' { $target = Find-VSCode; return ($target -and (Test-DesktopShortcut 'Visual Studio Code' $target)) }
        'dotnet10' { return (Test-Dotnet10) }
        'roblox' { $target = Find-Roblox; return ($target -and (Test-DesktopShortcut 'Roblox Player' $target -Arguments '-app')) }
        'iconsextract' { $target = Find-IconsExtract; return ($target -and (Test-DesktopShortcut 'IconsExtract' $target)) }
        'dimmer' { $target = Find-Dimmer; return ($target -and (Test-DesktopShortcut 'Dimmer' $target)) }
        'python' { return (Test-Python) }
        'itunes' { return [bool](Find-AppleDesktop 'itunes') }
        'icloud' { return [bool](Find-AppleDesktop 'icloud') }
        'iloader' { return [bool](Find-iLoader) }
        'veracrypt' { return [bool](Find-VeraCrypt) }
        'winrar' { return [bool](Find-WinRAR) }
        'desktop-apps' { return (Test-DesktopApps) }
        'nvm-windows' { return (Test-NvmSetup) }
        'playwright' { return (Test-Playwright) }
        'react' { return (Test-NodeProject (Get-ReactProject) @('react','react-dom','lucide-react','vite','@vitejs/plugin-react')) }
        'tailwind' { return (Test-NodeProject (Get-TailwindProject) @('tailwindcss','@tailwindcss/vite','vite')) }
        'emscripten' { return (Test-Emscripten) }
        'codex' { return [bool](Get-AppxPackage | Where-Object { $_.Name -match '(^|[.])Codex($|[.])|OpenAI.*Codex' } | Select-Object -First 1) }
        'dark-mode' {
            $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
            return ((Test-RegistryValue $key 'AppsUseLightTheme' 0) -and (Test-RegistryValue $key 'SystemUsesLightTheme' 0))
        }
        'hidden-files' { return (Test-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Hidden' 1) }
        'file-extensions' { return (Test-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' 0) }
        'running-icon' {
            $extension = 'HKCU:\Software\Classes\.running'
            $icon = 'HKCU:\Software\Classes\InstallStreet.Running\DefaultIcon'
            $expected = '"' + (Join-Path $taskRoot 'VaultHouse\icons\.running\running.ico') + '",0'
            return ((Test-Path $extension) -and (Test-Path $icon) -and ((Get-Item $extension).GetValue('') -eq 'InstallStreet.Running') -and ((Get-Item $icon).GetValue('') -eq $expected))
        }
        '7zip' { return (Test-WingetPackage '7zip.7zip') }
        'powertoys' { return (Test-WingetPackage 'Microsoft.PowerToys') }
        'terminal' { return (Test-WingetPackage 'Microsoft.WindowsTerminal') }
        'notepadplusplus' { return (Test-WingetPackage 'Notepad++.Notepad++') }
        'vlc' { return (Test-WingetPackage 'VideoLAN.VLC') }
        'firefox' { return (Test-WingetPackage 'Mozilla.Firefox') }
        'everything' { return (Test-WingetPackage 'voidtools.Everything') }
        'sharex' { return (Test-WingetPackage 'ShareX.ShareX') }
        'obs' { return (Test-WingetPackage 'OBSProject.OBSStudio') }
        'steam' { return (Test-WingetPackage 'Valve.Steam') }
        'discord' { return (Test-WingetPackage 'Discord.Discord') }
        'nextdns' { return (Test-WingetPackage 'NextDNS.NextDNS') }
        'googledrive' { return (Test-WingetPackage 'Google.GoogleDrive') }
        'chatgpt' { return (Test-WingetPackage '9NT1R1C2HH7J' -Source 'msstore') }
        'ahk' { return (Test-WingetPackage 'AutoHotkey.AutoHotkey') }
        'clipchamp' { return (Test-WingetPackage '9P1J8S7CCWWT' -Source 'msstore') }
        'davinciresolve' { return (Test-DaVinciResolve) }
        'githubdesktop' { return (Test-WingetPackage 'GitHub.GitHubDesktop') }
        'godot' { return (Test-WingetPackage 'GodotEngine.GodotEngine') }
        'homebrew' { return (Test-Homebrew) }
        'scoop' { return (Test-Scoop) }
        'tailscale' { return (Test-WingetPackage 'Tailscale.Tailscale') }
        'visualstudio' { return (Test-WingetPackage 'Microsoft.VisualStudio.2022.Community') }
        'wsl' { return (Test-WingetPackage 'Microsoft.WSL') }
        'zoom' { return (Test-WingetPackage 'Zoom.Zoom') }
        'developer-mode' {
            return (Test-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' 'AllowDevelopmentWithoutDevLicense' 1)
        }
        'long-paths' {
            return (Test-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' 1)
        }
        'disable-bing-search' {
            return (Test-RegistryValue 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1)
        }
        'taskbar-left' {
            return (Test-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAl' 0)
        }
        'end-task-context' {
            return (Test-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' 'TaskbarEndTask' 1)
        }
    }
}
function Set-Dword([string]$Path, [string]$Name, [int]$Value) {
    if (!(Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
}
try {
    if ($Mode -eq 'Check') {
        if (Test-Task) { Write-Output "$Task is ready."; exit 0 }
        Write-Output "$Task needs setup."
        exit 10
    }
    if (Test-Task) { Write-Output "$Task is already configured; skipping."; exit 0 }
    switch ($Task) {
        'winget' {
            Write-Output 'Bootstrapping WinGet and its dependencies with Microsoft.WinGet.Client...'
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force -Confirm:$false | Out-Null
            if (!(Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) { Register-PSRepository -Default }
            Install-Module -Name Microsoft.WinGet.Client -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -Confirm:$false
            Import-Module Microsoft.WinGet.Client
            Repair-WinGetPackageManager -Force -Latest
        }
        'chrome' {
            [Reflection.Assembly]::LoadFrom((Join-Path $taskRoot 'AppL\GoogleChrome.dll')) | Out-Null
            $result = [GoogleChromeTask]::Execute($taskRoot, 'Run', $null)
            if ($result -notin @(0,3010)) { throw "Chrome task failed: $result" }
        }
        'git' { Install-WingetPackage 'Git.Git' }
        'veracrypt' { Install-WingetPackage 'IDRIX.VeraCrypt' }
        'winrar' { Install-WingetPackage 'RARLab.WinRAR' 'en' }
        'itunes' {
            Install-DirectInstaller 'https://secure-appldnld.apple.com/itunes12/082-23400-20250912-4099b0db-ac9e-4cad-a6e7-2851fb1ec220/iTunes64Setup.exe' 'iTunes64Setup.exe' '3C11EE5F937230BFB576705A143A5AF098D87EA087A1E0F9FAA3A892ADF24481' -Apple $true
        }
        'icloud' {
            Write-Output 'Installing legacy standalone iCloud 7.21.0.23 from Apple. The current iCloud release is Store-only; no Store fallback will be used.'
            Install-DirectInstaller 'https://updates.cdn-apple.com/2020/windows/001-39935-20200911-1A70AA56-F448-11EA-8CC0-99D41950005E/iCloudSetup.exe' 'iCloudSetup.exe' '4CFD20D13CDCE2B5C435F2DDAF4EE4C81D976461846BF3B954E8AF6CBCDEB9F7' -Apple $true
        }
        'iloader' {
            Install-DirectInstaller 'https://github.com/nab138/iloader/releases/download/v2.3.6/iloader-windows-x64.msi' 'iloader.msi' '6F0D038F74F60E2E036EFA17DD45B7CEBD3A4C61B226FF0F03CC8668BB5E3B2D' -Msi $true
        }
        'gh' { Install-WingetPackage 'GitHub.cli' }
        'codex' {
            if (!(Test-Winget)) { throw 'WinGet is unavailable. Set up WinGet first.' }
            $exe = Find-Winget
            & $exe install --id 9PLM9XGG6VKS --exact --source msstore --accept-package-agreements --accept-source-agreements --disable-interactivity
            if ($LASTEXITCODE -notin @(0,3010)) { throw "Codex installation failed: $LASTEXITCODE" }
            if ($LASTEXITCODE -eq 3010) { Write-Output 'Codex requested a restart.' }
        }
        'dark-mode' {
            $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
            Set-Dword $key 'AppsUseLightTheme' 0
            Set-Dword $key 'SystemUsesLightTheme' 0
        }
        'rufus' {
            $target = Find-Rufus
            if (!$target) { Install-WingetPackage 'Rufus.Rufus'; Refresh-TaskEnvironment; $target = Find-Rufus }
            New-DesktopShortcut 'Rufus' $target
        }
        'vscode' {
            $target = Find-VSCode
            if (!$target) { Install-WingetPackage 'Microsoft.VisualStudioCode'; $target = Find-VSCode }
            New-DesktopShortcut 'Visual Studio Code' $target
        }
        'dotnet10' { Install-WingetPackage 'Microsoft.DotNet.SDK.10'; Refresh-TaskEnvironment }
        'roblox' {
            $target = Find-Roblox
            if (!$target) { Install-WingetPackage 'Roblox.Roblox'; $target = Find-Roblox }
            New-DesktopShortcut 'Roblox Player' $target -Arguments '-app'
        }
        'iconsextract' {
            $target = Find-IconsExtract
            if (!$target) {
                $download = Join-Path $taskDataRoot ('tmp\IconsExtract\' + [Guid]::NewGuid().ToString('N'))
                New-Item -ItemType Directory -Path $download -Force | Out-Null
                $zip = Join-Path $download 'iconsext.zip'
                & curl.exe --fail --location --retry 3 --retry-delay 3 --connect-timeout 30 --max-time 300 'https://www.nirsoft.net/utils/iconsext.zip' --output $zip
                if ($LASTEXITCODE -ne 0) { throw "IconsExtract download failed: $LASTEXITCODE" }
                $extracted = Join-Path $download 'extracted'
                Expand-Archive -LiteralPath $zip -DestinationPath $extracted
                if (!(Test-Path -LiteralPath (Join-Path $extracted 'iconsext.exe') -PathType Leaf)) { throw 'The NirSoft archive does not contain iconsext.exe.' }
                $destination = Join-Path $env:LOCALAPPDATA 'InstallStreet\Apps\IconsExtract'
                New-Item -ItemType Directory -Path $destination -Force | Out-Null
                foreach ($item in (Get-ChildItem -LiteralPath $extracted)) { Copy-Item -LiteralPath $item.FullName -Destination $destination -Recurse -Force }
                $target = Join-Path $destination 'iconsext.exe'
            }
            New-DesktopShortcut 'IconsExtract' $target
        }
        'dimmer' {
            $target = Find-Dimmer
            if (!$target) {
                $download = Join-Path $taskDataRoot ('tmp\Dimmer\' + [Guid]::NewGuid().ToString('N'))
                New-Item -ItemType Directory -Path $download -Force | Out-Null
                $zip = Join-Path $download 'dimmer-2.0.1.zip'
                & curl.exe --fail --location --retry 3 --retry-delay 3 --connect-timeout 30 --max-time 300 'https://www.nelsonpires.com/download/dimmer/2.0.1/zip' --output $zip
                if ($LASTEXITCODE -ne 0) { throw "Dimmer download failed: $LASTEXITCODE" }
                $extracted = Join-Path $download 'extracted'
                Expand-Archive -LiteralPath $zip -DestinationPath $extracted
                if (!(Test-DimmerBinary (Join-Path $extracted 'Dimmer.exe'))) { throw 'The Dimmer ZIP does not contain the expected Dimmer 2.0.1 executable.' }
                $destination = Join-Path $env:LOCALAPPDATA 'InstallStreet\Apps\Dimmer'
                New-Item -ItemType Directory -Path $destination -Force | Out-Null
                foreach ($item in (Get-ChildItem -LiteralPath $extracted)) { Copy-Item -LiteralPath $item.FullName -Destination $destination -Recurse -Force }
                $target = Join-Path $destination 'Dimmer.exe'
            }
            New-DesktopShortcut 'Dimmer' $target
            Start-Dimmer $target
        }
        'python' {
            $exe = Find-Python
            if (!$exe) { Install-WingetPackage 'Python.Python.3.14'; $exe = Find-Python }
            if (!$exe) { throw 'Python 3.14 or newer could not be located after installation. Reopen InstallStreet and retry.' }
            & $exe -m ensurepip --upgrade
            if ($LASTEXITCODE -ne 0) { throw "Python pip setup failed: $LASTEXITCODE" }
        }
        'desktop-apps' {
            foreach ($app in @(Get-DesktopApps)) { New-DesktopShortcut $app.Name $app.Target -Arguments $app.Arguments -WorkingDirectory $app.WorkingDirectory }
        }
        'playwright' { Install-Playwright }
        'react' { Install-NodeProject (Get-ReactProject) 'react' }
        'tailwind' { Install-NodeProject (Get-TailwindProject) 'tailwind' }
        'emscripten' { Install-Emscripten }
        'nvm-windows' {
            Refresh-TaskEnvironment
            $nvm = Find-Nvm
            if (!$nvm) {
                if (Get-Command node.exe -ErrorAction SilentlyContinue) {
                    throw 'A standalone Node.js installation is present. Uninstall it before setting up nvm-windows to avoid a conflicting Node path; then retry setup.'
                }
                Install-WingetPackage 'CoreyButler.NVMforWindows'
                Refresh-TaskEnvironment
                $nvm = Find-Nvm
                if (!$nvm) { throw 'nvm-windows was installed but nvm.exe could not be located. Reopen InstallStreet and retry.' }
            }
            Write-Output 'Installing Node.js LTS and its bundled npm through nvm-windows...'
            & $nvm install lts
            if ($LASTEXITCODE -ne 0) { throw "nvm install lts failed: $LASTEXITCODE" }
            & $nvm use lts
            if ($LASTEXITCODE -ne 0) { throw "nvm use lts failed: $LASTEXITCODE" }
            Refresh-TaskEnvironment
            Write-Output 'Node.js and npm will be verified before this task is marked done.'
        }
        'hidden-files' { Set-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Hidden' 1 }
        'file-extensions' { Set-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' 0 }
        'running-icon' {
            $icon = Join-Path $taskRoot 'VaultHouse\icons\.running\running.ico'
            if (!(Test-Path -LiteralPath $icon -PathType Leaf)) { throw "Icon not found: $icon" }
            foreach ($key in @('HKCU:\Software\Classes\.running','HKCU:\Software\Classes\InstallStreet.Running','HKCU:\Software\Classes\InstallStreet.Running\DefaultIcon')) { if (!(Test-Path -LiteralPath $key)) { New-Item -Path $key -Force | Out-Null } }
            Set-Item -LiteralPath 'HKCU:\Software\Classes\.running' -Value 'InstallStreet.Running'
            Set-Item -LiteralPath 'HKCU:\Software\Classes\InstallStreet.Running' -Value 'InstallStreet running log'
            Set-Item -LiteralPath 'HKCU:\Software\Classes\InstallStreet.Running\DefaultIcon' -Value ('"' + $icon + '",0')
            Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class InstallStreetShell { [DllImport("shell32.dll")] public static extern void SHChangeNotify(uint e, uint f, IntPtr a, IntPtr b); }'
            [InstallStreetShell]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
        }
        '7zip'           { Install-WingetPackage '7zip.7zip' }
        'powertoys'      { Install-WingetPackage 'Microsoft.PowerToys' }
        'terminal'       { Install-WingetPackage 'Microsoft.WindowsTerminal' }
        'notepadplusplus'{ Install-WingetPackage 'Notepad++.Notepad++' }
        'vlc'            { Install-WingetPackage 'VideoLAN.VLC' }
        'firefox'        { Install-WingetPackage 'Mozilla.Firefox' }
        'everything'     { Install-WingetPackage 'voidtools.Everything' }
        'sharex'         { Install-WingetPackage 'ShareX.ShareX' }
        'obs'            { Install-WingetPackage 'OBSProject.OBSStudio' }
        'steam'          { Install-WingetPackage 'Valve.Steam' }
        'discord'        { Install-WingetPackage 'Discord.Discord' }
        'nextdns'        { Install-WingetPackage 'NextDNS.NextDNS' }
        'googledrive'    { Install-WingetPackage 'Google.GoogleDrive' }
        'chatgpt'        { Install-WingetPackage '9NT1R1C2HH7J' -Source 'msstore' }
        'ahk' { Install-WingetPackage 'AutoHotkey.AutoHotkey' }
        'clipchamp' { Install-WingetPackage '9P1J8S7CCWWT' -Source 'msstore' }
        'davinciresolve' { Open-ManualInstallPage 'https://www.blackmagicdesign.com/products/davinciresolve' 'DaVinci Resolve requires downloading and completing setup on Blackmagic Design official site.' }
        'githubdesktop' { Install-WingetPackage 'GitHub.GitHubDesktop' }
        'godot' { Install-WingetPackage 'GodotEngine.GodotEngine' }
        'homebrew' { Open-ManualInstallPage 'https://docs.brew.sh/Homebrew-on-Linux' 'Homebrew runs inside a Linux distribution on WSL 2; InstallStreet installs WSL but leaves Linux distribution setup and Homebrew shell steps to you.' }
        'scoop' { Open-ManualInstallPage 'https://scoop.sh/' 'Scoop standard setup is per-user and should be run from a regular, non-administrator PowerShell window.' }
        'tailscale' { Install-WingetPackage 'Tailscale.Tailscale' }
        'visualstudio' { Install-WingetPackage 'Microsoft.VisualStudio.2022.Community' }
        'wsl' { Install-WingetPackage 'Microsoft.WSL' }
        'zoom' { Install-WingetPackage 'Zoom.Zoom' }
        'developer-mode' {
            Set-Dword 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' 'AllowDevelopmentWithoutDevLicense' 1
        }
        'long-paths' {
            Set-Dword 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' 1
        }
        'disable-bing-search' {
            Set-Dword 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
        }
        'taskbar-left' {
            Set-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAl' 0
        }
        'end-task-context' {
            Set-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' 'TaskbarEndTask' 1
        }
    }    Write-Output "$Task action completed; the runner will verify the result."
    exit 0
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}












