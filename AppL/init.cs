using System;
using System.Diagnostics;
using System.IO;
public static class InstallStreetTask
{
    public static int Execute(string root, string mode, Action<string> output)
    {
        if (mode != "Check" && mode != "Run") throw new ArgumentException("Mode must be Check or Run.");
        return ScriptTaskRuntime.RunCli(root, (mode == "Check" ? "--check " : "--run ") + "winget,git,gh,chrome,codex,rufus,vscode,dotnet10,roblox,nvm-windows,playwright,react,tailwind,emscripten,dimmer,python,itunes,icloud,iloader,veracrypt,winrar,iconsextract,ahk,clipchamp,davinciresolve,githubdesktop,godot,homebrew,scoop,tailscale,visualstudio,wsl,zoom", output);
    }
    public static void Launch(string root)
    {
        Process.Start(new ProcessStartInfo(Path.Combine(root, "InstallStreet.exe")) { UseShellExecute = true });
    }
}




