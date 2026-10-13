# InstallStreet

Open InstallStreet.exe, select apps and optional Windows settings, then choose Install.
Nothing is selected initially. Required dependencies are included automatically.
Check only inspects the selected tasks; Retry selected retries that selection.

## Presets and Windows installation media

Save a named preset with your app selection, optional settings, and Windows 10 or 11.
Choose a saved preset to load it; edit its name or selection and save to update it.
The preset actions menu supports import, export, deletion, and Create Windows ISO.
Preset files contain task IDs and the Windows choice, never credentials or custom commands.

Create Windows ISO asks for an original **x64 Windows ISO** matching your choice.
Missing Oscdimg is installed automatically using Microsoft ADK Deployment Tools.
The downloaded installer must have a valid Microsoft Authenticode signature.
The builder copies the source into a unique Media folder, adds the native InstallStreet
backend and preset, and creates an ISO supporting BIOS and UEFI boot. The source ISO
is unchanged. Allow enough free space for both the extracted files and output ISO.

Choose **Flash ISO with Rufus**, select your Rufus executable, then choose and verify
the USB device in Rufus. Rufus performs the write and asks for confirmation before
it erases the drive. InstallStreet does not report the drive flashed merely because
Rufus opened. Windows setup still asks you about installation, disks and accounts.

Apps install at the first administrator sign-in **after Windows setup**, with internet
access required. They are not installed inside the offline Windows image. Individual
apps may have additional OS requirements; choosing Windows 10 does not guarantee
that every current app supports it. Use a normal administrator account for first sign-in.
If a download fails or first-logon execution does not run, launch
`%SystemDrive%\InstallStreet\RunPreset.ps1` with PowerShell and administrator permission.
Successful tasks are detected and skipped on retry. Logs remain in that folder's StatusHQ.
The media excludes personal GitHub profiles, update tokens, and existing logs.

The UI retains its dark Windows Installer style and bundled offline logos, including
the user-provided BRAINSTORM logos. Icon sources and required attribution are listed
in `electron/assets/apps/SOURCES.json`.

## Applications installed

The following applications are available for selection. Existing working
installations are checked and skipped. Opening InstallStreet or running
**Check only** does not install these applications.

| Application / tool | Version or source | Installation task |
| --- | --- | --- |
| Windows Package Manager (WinGet) | Microsoft.WinGet.Client bootstrap | `winget` |
| Git | `Git.Git` through WinGet | `git` |
| GitHub CLI (`gh`) | `GitHub.cli` through WinGet | `gh` |
| Google Chrome | Official Google installer | `chrome` |
| OpenAI Codex desktop app | Microsoft Store product `9PLM9XGG6VKS` | `codex` |
| Rufus | `Rufus.Rufus` through WinGet | `rufus` |
| Visual Studio Code | `Microsoft.VisualStudioCode` through WinGet | `vscode` |
| Microsoft .NET 10 SDK | `Microsoft.DotNet.SDK.10`; includes the corresponding runtime | `dotnet10` |
| Roblox Player | `Roblox.Roblox` through WinGet | `roblox` |
| nvm-windows | `CoreyButler.NVMforWindows` through WinGet | `nvm-windows` |
| Node.js | LTS version installed and activated through nvm-windows | `nvm-windows` |
| npm | Bundled with the Node.js version installed by nvm-windows | `nvm-windows` |
| Playwright | `npm init playwright@latest` with noninteractive defaults; Node/npm prerequisite; Chromium, Firefox and WebKit | `playwright` |
| React | Vite React starter project with `react`, `react-dom`, and `lucide-react` | `react` |
| Tailwind CSS | Vite starter project using the official Tailwind Vite plugin | `tailwind` |
| Emscripten SDK | Official `emscripten-core/emsdk` repository; installs and activates the latest SDK | `emscripten` |
| Dimmer | Nelson Pires 2.0.1, from the specified official ZIP; starts after installation | `dimmer` |
| Python | Python 3.14 through `Python.Python.3.14`; existing working 3.14+ environments are skipped | `python` |
| pip | Included with Python; repaired with `ensurepip` when needed | `python` |
| NirSoft IconsExtract | Official NirSoft portable ZIP | `iconsextract` |
| iTunes desktop | Apple standalone x64 installer 12.13.8.3, not Microsoft Store | `itunes` |
| iCloud desktop | Legacy Apple standalone installer 7.21.0.23, not Microsoft Store | `icloud` |
| iLoader | Official nab138/iloader GitHub release 2.3.6 x64 MSI; runs after iTunes | `iloader` |
| VeraCrypt | `IDRIX.VeraCrypt` through WinGet; includes a desktop shortcut | `veracrypt` |
| WinRAR | `RARLab.WinRAR` through WinGet, official RARLab English installer; includes a desktop shortcut | `winrar` |
| Everything | `voidtools.Everything` through WinGet | `everything` |
| ShareX | `ShareX.ShareX` through WinGet | `sharex` |
| OBS Studio | `OBSProject.OBSStudio` through WinGet | `obs` |
| Steam | `Valve.Steam` through WinGet | `steam` |
| Discord | `Discord.Discord` through WinGet | `discord` |
| NextDNS | `NextDNS.NextDNS` through WinGet | `nextdns` |
| Google Drive | `Google.GoogleDrive` through WinGet | `googledrive` |
| ChatGPT for Windows | Official Microsoft Store app through WinGet (`9NT1R1C2HH7J`) | `chatgpt` |
| AutoHotkey v2 | `AutoHotkey.AutoHotkey` through WinGet | `ahk` |
| Microsoft Clipchamp | Microsoft Store app (`9P1J8S7CCWWT`) | `clipchamp` |
| DaVinci Resolve | Opens the official Blackmagic Design download page for manual setup | `davinciresolve` |
| GitHub Desktop | `GitHub.GitHubDesktop` through WinGet | `githubdesktop` |
| Godot Engine | `GodotEngine.GodotEngine` through WinGet | `godot` |
| Homebrew for WSL | Installs the WSL package; opens Homebrew's official Linux/WSL setup guide | `homebrew` |
| Scoop | Opens the official Scoop setup page; install from a regular PowerShell session | `scoop` |
| Tailscale | `Tailscale.Tailscale` through WinGet | `tailscale` |
| Visual Studio Community 2022 | `Microsoft.VisualStudio.2022.Community` through WinGet | `visualstudio` |
| Windows Subsystem for Linux | `Microsoft.WSL` through WinGet | `wsl` |
| Zoom Workplace | `Zoom.Zoom` through WinGet | `zoom` |

DaVinci Resolve requires the user to complete the publisher's download
and installation flow. Scoop's per-user installer should be run from a regular,
non-administrator PowerShell session. Homebrew runs inside a configured WSL 2
Linux distribution; InstallStreet installs WSL but does not create a Linux user
or run Homebrew's Linux bootstrap script. InstallStreet opens the relevant official
setup page for these manual steps and verifies the app when possible.

Playwright creates its TypeScript test project in `BRAINSTORM/playwright` under the
InstallStreet data folder (the repository during development, `%APPDATA%/InstallStreet`
when packaged). Select Playwright and click Install to initialize it; Check only does
not download packages. Run `npx playwright test --ui` from that project to use it.
Current Playwright supports Windows 11+ and Windows Server 2019+, not Windows 10.
See [Playwright installation](https://playwright.dev/docs/intro).

React and Tailwind each create a starter project under `BRAINSTORM/react` and
`BRAINSTORM/tailwind-css` in the InstallStreet data folder. They install Node.js
through nvm-windows as a prerequisite, install npm packages, and run a production
build to verify the project. React includes `lucide-react`. The Emscripten SDK is
cloned from [the official SDK repository](https://github.com/emscripten-core/emsdk),
installed under `BRAINSTORM/emsdk`, and activated for use. Launch `Open Emscripten
Command Prompt.cmd` from that folder to open a shell with the Emscripten environment
loaded. See [React](https://react.dev/learn/build-a-react-app-from-scratch),
[Tailwind CSS with Vite](https://tailwindcss.com/docs/installation/using-vite), and
[Emscripten SDK](https://emscripten.org/docs/getting_started/downloads.html) for
the publishers' guides.

WinGet bootstrap also installs the **NuGet PowerShell package provider** and
**Microsoft.WinGet.Client PowerShell module** when needed. WinGet repair and
application installers can install their required framework dependencies.
StorageSense.exe is the bundled maintenance companion. The desktop app uses a
native C++ WebView2 host and checks for the shared WebView2 Runtime at startup,
installing Microsoft's signed runtime automatically when it is missing. The
existing Node.js setup backend and task DLLs are bundled. **PowerShell and Command Prompt are existing Windows
tools**; InstallStreet creates their desktop shortcuts.
Desktop shortcut checks inspect both the current user's desktop (including
OneDrive) and the Public desktop. Matching installer-created shortcuts are reused
by executable and arguments, even if their names differ, so desktopn does not
create an additional icon for the same application.

iTunes and iCloud use direct Apple downloads, with pinned SHA256 checks and
Apple Authenticode signature verification before installation. Store versions do
not count as the requested desktop installations. Apple's current iCloud download
is Store-only; this task attempts legacy standalone iCloud 7.21.0.23 and reports an
installation or verification failure if it is incompatible with the PC. It never
falls back to the Store. [Apple's current download instructions](https://support.apple.com/en-us/103232).

iLoader is downloaded only from [its official repository](https://github.com/nab138/iloader),
with a pinned release checksum. InstallStreet installs the application; Apple ID
sign-in, device pairing, and sideloading are performed by the user inside iLoader.

## Other setup tasks

These tasks change settings, create shortcuts, or remove an application; they
are separate from the application installation list above.

| Task | Behavior | Compiled library |
| --- | --- | --- |
| LinkedIn removal | Removes installed LinkedIn Appx packages for all users | `VaultHouse/Guards/LinkedInRemoval.dll` |
| Promoted-app preference | Sets `SilentInstalledAppsEnabled` to DWORD `0` for the effective user | `DisplayCity/ConsumerFeatures.dll` |
| Wallpaper | Sets `C:\Windows\Web\Wallpaper\Theme1\img4.jpg` | `DisplayCity/Wallpaper.dll` |
| Dark mode | Enables dark mode for Windows and apps | `DisplayCity/DarkMode.dll` |
| Hidden files | Shows hidden files in File Explorer | `Files/showHiddenFiles.dll` |
| File extensions | Shows file extensions in File Explorer | `Files/showFileExtensions.dll` |
| Desktop shortcuts | Creates or repairs shortcuts for installed desktop apps, PowerShell, and Command Prompt | `VaultHouse/Appointer/desktopn.dll` |
| Running log icon | Registers the `.running` file icon | `VaultHouse/RunningIcon.dll` |

InstallStreet loads each task DLL in an isolated child process. Chrome contains C# installation logic.
The other installer/settings DLLs embed the PowerShell task implementation at
build time and share TaskRuntime.dll. workers/task.ps1 is their editable source;
the built task DLLs do not read that file at runtime. Settings and the icon apply
to the effective administrator account. The application requires elevation at startup.

The former batch group/utility entries are compiled libraries too:
__init__.dll, AppL/init.dll, DisplayCity/init.dll, Files/__set__/applyChanges.dll,
workers/WhereAppL/whereappl.dll, VaultHouse/Guards/AdminRights.dll, and
VaultHouse/build-running-helper.dll. DLLs are loaded by a .NET host; double-click
InstallStreet.exe to start the app. There are no batch files in the project.

## Command line

```
InstallStreet.Cli.exe --check
InstallStreet.Cli.exe --run all
InstallStreet.Cli.exe --run chrome,codex
InstallStreet.Cli.exe --register-icon
InstallStreet.Cli.exe --retry
InstallStreet.Cli.exe --help
```

CLI task IDs allow individual integrations. The Electron window runs only the selected tasks and their dependencies. Codex, Rufus, and nvm-windows include WinGet as a prerequisite. Failed tasks do not block later tasks, including dependent apps. Each task runs
in its own process so a crashing task cannot terminate the coordinator. CLI --retry retries
failed or pending tasks from the latest run. The window's Retry selected reruns the selection.

## Logs

Each run gets a StatusHQ/run-... folder with live .running logs, renamed .done
or .failed after execution and verification. Successful logs are retained.
latest.tsv tracks current/pending results; summary.tsv records completed sessions.
A lock prevents overlapping runs. Interrupted session logs are finalized on the
next run. --check does not create logs or change settings.

## Build and tests

Use the installed .NET Framework C# compiler through the build script:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File VaultHouse\build.ps1
InstallStreet.Cli.exe --self-test
npm run test:ui
```

The build compiles all DLLs and executables in a staging folder before publishing.
Previous artifacts are retained under tmp/build for processes still using them.
Generated DLLs, executables, logs, and temporary files are ignored by Git.
Runner/bridge tests use fixtures. Electron UI smoke tests perform read-only detection without installations or settings changes.
Actual installations require a separate end-to-end run.

WinGet uses Microsoft.WinGet.Client and Repair-WinGetPackageManager -Force -Latest
for bootstrap and dependency resolution. Chrome uses the official Google installer
and verifies its signature. Rufus uses WinGet package Rufus.Rufus. nvm-windows uses
CoreyButler.NVMforWindows, then installs and activates Node.js LTS with bundled npm.
A conflicting standalone Node installation is reported; it is not uninstalled.
Network and Store availability can affect installation. Settings restoration and
multi-user management are not included.

Microsoft bootstrap reference:
https://learn.microsoft.com/en-us/windows/package-manager/winget/

## Desktop interface and development

The interface is in electron/index.html, styles.css, and renderer.js. main.js
runs the desktop window, while preload.js exposes a limited bridge to the DLL
runner through InstallStreet.Cli.exe. No task selection is exposed.

Install dependencies with npm install, build the backend with npm run build:tasks,
and launch with npm start or InstallStreet.exe. Test with npm test and npm run
test:ui. The Electron dependency is locked in package-lock.json.

The repository's development UI still runs through Electron. The distributable
MSI and portable ZIP use the native WebView2 host, bundled Node.js backend, and
task DLLs; Chromium is not included in the release payload.


Rufus and VS Code are only ready when their desktop shortcuts point to the
installed executable. Missing or incorrect shortcuts are repaired without
reinstalling an existing app. Shortcuts use the actual Windows desktop location,
including a redirected/OneDrive desktop. .NET 10 installs the SDK (which includes
the corresponding runtime). Roblox uses the Roblox.Roblox WinGet package.


VaultHouse/Appointer/desktopn.dll creates or repairs desktop shortcuts immediately
for installed Chrome, Codex, Rufus, VS Code, and Roblox Player. Invoke it through
InstallStreet.Cli.exe --run desktop-apps. It also runs during every complete setup.
Missing apps are left for their installation tasks. Roblox installation now also
requires a valid Roblox Player desktop shortcut, including its launch arguments.


IconsExtract is included through AppL/IconsExtract.dll. It downloads NirSoft's
official portable ZIP to install under %LOCALAPPDATA%\InstallStreet\Apps\IconsExtract,
keeps the included documentation, and creates an IconsExtract desktop shortcut.
The desktopn helper also repairs that shortcut for existing installations.
Official download: https://www.nirsoft.net/utils/iconsext.html


## Distributable releases

`npm run dist` builds the DLL backend and native WebView2 host, restores the
pinned Microsoft WebView2 SDK and WiX toolset, then creates:

- `dist/InstallStreet-1.5.2-x64.msi`: Windows Installer with desktop and Start menu shortcuts.
- `dist/InstallStreet-1.5.2-x64.zip`: extract anywhere and run InstallStreet.exe without installing InstallStreet.

Both include the native host, Node.js backend, and task DLLs. Node.js, npm, the
source repository, and build tools are not needed to run either release. WebView2
Runtime is installed automatically when missing. The MSI installs InstallStreet;
it does not automatically run app-installation tasks. Open InstallStreet and run
setup when ready. Actual task installation still requires its downloads/network.

### Fresh Windows PCs

Use the release MSI or extract the entire portable ZIP on Windows 11 x64 (Intel
or AMD). Do not copy only InstallStreet.exe or StorageSense.exe, and do not use
the small source-development launcher from the repository as a release.
Visual Studio, Visual C++ build tools, Git, gh, Node.js, Python, a .NET SDK, and
PowerShell 7 are not prerequisites. The backend uses Windows' built-in .NET
Framework 4.x and Windows PowerShell 5.1. Administrator permission and internet
access are required for setup. Microsoft Store access is needed for Codex.
Native ARM64 and 32-bit releases are not currently provided.

WinGet is detected independently of PATH and bootstrapped when missing. The
bootstrap installs its NuGet provider and Microsoft.WinGet.Client module and
registers the default PowerShell Gallery repository if absent. Task processes
use a process-only execution-policy override; they do not change the user's or
machine's saved execution policy. Organization-enforced policies can still block
setup and are reported as failures.

`VaultHouse/verify-fresh-pc.ps1` checks packaged runtime assets and backend
assemblies, then probes the bundled Node backend and UI with a Windows-only PATH,
cleared developer environment variables, and missing Git/gh fixtures.
Release builds run this check. It does not install apps or run maintenance, and
it is a dependency-isolation check rather than a clean Windows VM test.

Packaged application logs, downloads, and profile data are kept in
%APPDATA%/InstallStreet so installation files can remain read-only. Portable here
means no InstallStreet installation is required; setup tasks still change the PC
and store application data in your user profile. The MSI is not a portable file.

Run VaultHouse/verify-msi.ps1 to inspect MSI metadata and required payload files.
The release binaries are unsigned; no signing certificate is configured.

### Auto-update settings

Open **Settings** in InstallStreet to enable automatic checks at startup and
every six hours, automatic downloads, and automatic installation when idle.
All options default to off. Automatic installation requires its own confirmation
when enabled, then closes InstallStreet and runs the verified MSI after setup and
StorageSense finish. The **Check for updates** button checks for a release,
downloads and verifies its MSI, then asks before installing. InstallStreet opens
again when Windows Installer succeeds.
No app-installation or maintenance tasks are started by an InstallStreet update.

Updates use published stable releases from UltraRyzen378/InstallStreet. Drafts
and prereleases are excluded. MSI downloads must match the release SHA256SUMS.txt;
the administrator-only UpdateHelper verifies the hash again after the app closes.
Windows Installer never requests an automatic restart. For portable ZIP users, this
installs an MSI copy and leaves the extracted folder unchanged.

The repository is public. Update checks and downloads need no GitHub account or
token. Older saved update tokens are removed when settings load. A published
stable release with an MSI and SHA256SUMS.txt is required; drafts are excluded.

Settings are stored in %APPDATA%/InstallStreet/update-settings.json for packaged
builds. Verified installers and update logs are under %APPDATA%/InstallStreet/Updates.
Development builds do not install updates.

Every setup run includes DisplayCity/Wallpaper.dll, setting the current user's
wallpaper to C:\Windows\Web\Wallpaper\Theme1\img4.jpg. It verifies the active
wallpaper, skips an existing match, and reports a missing image as a task failure.
Check only does not change wallpaper. Releases 1.0.1 include the wallpaper DLL.


The desktopn helper also creates PowerShell and Command Prompt desktop shortcuts
using the built-in Windows executables. Both open in your user profile folder.


Git (Git.Git) and GitHub CLI (GitHub.cli) are included in every setup run, through
AppL/Git.dll and AppL/GitHubCLI.dll. When gh is missing, the desktop interface
asks for a username and email to save in InstallStreet's local gh-profile.json.
It then shows a separate warning before optionally setting Git's global user.name
and user.email. Declining the warning leaves Git config unchanged; the local
profile remains saved. Skipping the profile still installs all applications.
No gh authentication or credential files are changed. gh config does not provide
username/email settings; the saved profile is an InstallStreet preference.
CLI-only runs install the tools without prompting for or changing Git identity.


Every run includes ConsumerFeatures.dll, setting HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SilentInstalledAppsEnabled to DWORD 0.
The task verifies the value and DWORD type. It does not uninstall existing apps,
disable Store updates, or restart Windows. A restart may be needed. This is the
specific current-user registry preference; it is not a guarantee against every
Windows promotion or future feature-update changes.


Dimmer 2.0.1 uses the exact supplied ZIP URL, preserves its bundled documentation,
installs under %LOCALAPPDATA%\InstallStreet\Apps\Dimmer, and creates a desktop
shortcut. After installation and shortcut creation, InstallStreet verifies the
binary and starts Dimmer in the background. An existing Dimmer process in the
current Windows session is reused. Check only and already-configured tasks do
not launch it. This does not add Dimmer to Windows startup.
Python uses Python.Python.3.14 and verifies the interpreter and pip. Existing
working Python 3.14+ environments are skipped; missing pip is repaired.
LinkedInRemoval.dll runs Get-AppxPackage -AllUsers '*LinkedIn*' | Remove-AppxPackage
-AllUsers inside the administrator-required setup session. It verifies absence and reports UAC
cancellation as failure. Check only detects packages without uninstalling. This removes
installed Appx registrations, not provisioned packages for future accounts.


InstallStreet requires administrator access for every desktop and CLI session.
Windows launch manifests require elevation for the GUI, CLI, and compatibility
helper. The administrator startup gate also prevents npm/development launches
from opening the interface without administrator access. Canceling UAC stops startup.
WebView2 navigation and developer tools are restricted. Per-user settings apply to the
effective administrator account; entering another account's credentials changes
which account receives those settings. Developer smoke tests and CLI checks must
now be launched from an elevated terminal. DLL and packaging verification can
still inspect binaries without launching the application.



## GitHub release automation

The Windows releases workflow builds and verifies the MSI, portable ZIP, admin
manifests, and SHA-256 checksums, then automatically publishes a stable GitHub release as Latest. It never
runs setup tasks on the build machine. Failed builds do not publish releases.

For a release, update the version in package.json and package-lock.json, commit
and push main, then push the matching version tag (for example v1.5.2). A tag
whose version does not match package.json fails before building. Keep the MSI
upgrade code unchanged across versions.

Alternatively, run Windows releases from Actions on main. It uses the current
package version and refuses to reuse a tag pointing at another commit. GitHub
Actions must be enabled for the repository. The workflow uses the built-in
GITHUB_TOKEN; no personal token or signing credentials are required. Build jobs
have read-only repository access, and only the release job can write.

## StorageSense sub-application

StorageSense.exe is the administrator-only Windows maintenance companion bundled
with InstallStreet. Keep it beside InstallStreet.exe and the runtime. Open it
directly, or click StorageSense in InstallStreet. It is separate from setup;
clicking Run InstallStreet never starts repairs or cleanup.

Available tools:

- DISM CheckHealth, ScanHealth, and AnalyzeComponentStore.
- DISM RestoreHealth, SFC verifyonly, and SFC scannow.
- Repair Windows: DISM RestoreHealth followed by SFC; continues after failures and restart requests.
- CHKDSK online scan of the Windows volume, without forced dismount/reboot.
- DISM StartComponentCleanup without ResetBase.
- Windows Disk Cleanup with its normal category-selection dialog.
- Links to Windows storage settings, DISM/CBS logs, and per-operation output logs.

Run All runs every check, then DISM repair, SFC repair, component cleanup, and
Windows Disk Cleanup, with one confirmation before starting. DISM and SFC repair
each run once. The sequence continues after failures and restart requests; Disk Cleanup
still lets you choose which categories to delete.

Repair and component cleanup require confirmation. No operation starts on launch.
Maintenance and application setup cannot run concurrently. Commands are a fixed
allowlist; no arbitrary shell input is accepted. Output and percentage updates
appear live. Command completion does not prove that every detected issue was
repaired: review the output. Operation logs live under StorageSense/Logs in the
application data folder. Repair downloads depend on Windows Update configuration.
There is no automatic reboot, ResetBase, custom recursive file deletion, or
unattended clearing of Downloads or the Recycle Bin. Native maintenance operations
are tested with fixtures rather than run against the developer's Windows image.

After a local build, run `npm run organize:packages` to move MSI/ZIP packages into
`dist/releases/<version>/` with per-version SHA256SUMS.txt files. Older builds are
preserved. `dist/PACKAGES.md` lists the available versions; win-unpacked stays
in dist for verification. CI keeps its staging paths until artifact upload.

### Playwright integration checks

Run `npm run test:playwright` to validate the worker, presets, and media bootstrap
without installing apps or downloading browsers. Use `npm run test:playwright -- -Build`
to also rebuild the native helpers. The script restores the working directory,
cleans up its temporary fixtures, and returns failure when a check or build fails.
