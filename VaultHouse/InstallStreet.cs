using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Security.Principal;





internal sealed class SetupTask
{
    public readonly string Id, Name;
    public readonly string[] Dependencies;
    public SetupTask(string id, string name, params string[] dependencies) { Id = id; Name = name; Dependencies = dependencies; }
}
internal static class InstallStreetApp
{
    private static readonly string Root = AppDomain.CurrentDomain.BaseDirectory;
    private static readonly string DataRoot = Environment.GetEnvironmentVariable("INSTALLSTREET_DATA_ROOT") ?? Root;
    private static readonly SetupTask[] Catalog = {
        new SetupTask("winget", "WinGet package manager"),
        new SetupTask("git", "Git", "winget"),
        new SetupTask("gh", "GitHub CLI (gh)", "winget", "git"),
        new SetupTask("chrome", "Google Chrome"),
        new SetupTask("codex", "Codex", "winget"),
        new SetupTask("rufus", "Rufus and desktop shortcut", "winget"),
        new SetupTask("vscode", "Visual Studio Code and desktop shortcut", "winget"),
        new SetupTask("dotnet10", ".NET 10 SDK", "winget"),
        new SetupTask("roblox", "Roblox Player", "winget"),
        new SetupTask("nvm-windows", "nvm-windows, Node.js and npm", "winget"),
        new SetupTask("playwright", "Playwright", "nvm-windows"),
        new SetupTask("react", "React, lucide-react and Vite starter", "nvm-windows"),
        new SetupTask("tailwind", "Tailwind CSS and Vite starter", "nvm-windows"),
        new SetupTask("emscripten", "Emscripten SDK", "git"),
        new SetupTask("dimmer", "Dimmer 2.0.1 and desktop shortcut"),
        new SetupTask("python", "Python 3.14 and pip", "winget"),
        new SetupTask("itunes", "iTunes desktop (Apple installer)"),
        new SetupTask("icloud", "iCloud desktop (legacy Apple installer)"),
        new SetupTask("iloader", "iLoader", "itunes"),
        new SetupTask("veracrypt", "VeraCrypt", "winget"),
        new SetupTask("winrar", "WinRAR", "winget"),
        new SetupTask("remove-linkedin", "Remove installed LinkedIn Appx packages (all users)"),
        new SetupTask("consumer-features", "Disable promoted-app auto-installation"),
        new SetupTask("wallpaper", "Set desktop wallpaper"),
        new SetupTask("dark-mode", "Dark mode"),
        new SetupTask("hidden-files", "Show hidden files"),
        new SetupTask("file-extensions", "Show file extensions"),
        new SetupTask("iconsextract", "NirSoft IconsExtract and desktop shortcut"),
        new SetupTask("desktop-apps", "Desktop app shortcuts"),
        new SetupTask("running-icon", "Register .running icon"),
        new SetupTask("7zip", "7-Zip", "winget"),
        new SetupTask("powertoys", "Microsoft PowerToys", "winget"),
        new SetupTask("terminal", "Windows Terminal", "winget"),
        new SetupTask("notepadplusplus", "Notepad++", "winget"),
        new SetupTask("vlc", "VLC Media Player", "winget"),
        new SetupTask("firefox", "Mozilla Firefox", "winget"),
        new SetupTask("everything", "Everything file search", "winget"),
        new SetupTask("sharex", "ShareX screenshot utility", "winget"),
        new SetupTask("obs", "OBS Studio recording and streaming", "winget"),
        new SetupTask("steam", "Steam gaming client", "winget"),
        new SetupTask("discord", "Discord", "winget"),
        new SetupTask("nextdns", "NextDNS", "winget"),
        new SetupTask("googledrive", "Google Drive", "winget"),
        new SetupTask("chatgpt", "ChatGPT for Windows (Microsoft Store)", "winget"),
        new SetupTask("ahk", "AutoHotkey", "winget"),
        new SetupTask("clipchamp", "Microsoft Clipchamp (Microsoft Store)", "winget"),
        new SetupTask("davinciresolve", "DaVinci Resolve (publisher setup)"),
        new SetupTask("githubdesktop", "GitHub Desktop", "winget"),
        new SetupTask("godot", "Godot Engine", "winget"),
        new SetupTask("homebrew", "Homebrew for WSL 2 (publisher setup)", "winget", "wsl"),
        new SetupTask("scoop", "Scoop (publisher setup)"),
        new SetupTask("tailscale", "Tailscale", "winget"),
        new SetupTask("visualstudio", "Visual Studio Community 2022", "winget"),
        new SetupTask("wsl", "Windows Subsystem for Linux", "winget"),
        new SetupTask("zoom", "Zoom Workplace", "winget"),
        new SetupTask("developer-mode", "Enable Developer Mode"),
        new SetupTask("long-paths", "Enable Long File Paths"),
        new SetupTask("disable-bing-search", "Disable Bing Search in Start"),
        new SetupTask("taskbar-left", "Align Taskbar to Left"),
        new SetupTask("end-task-context", "Enable End Task in Taskbar Context Menu")
    };
    private static Action<string, string, int, int> Progress;
    private static void Report(string id, string state, int completed, int total) { if (Progress != null) Progress(id, state, completed, total); }
    private static string TestStatus;
    private static Func<SetupTask, string, Action<string>, int> TestInvoke;
    private static string Status { get { return TestStatus ?? Path.Combine(DataRoot, "StatusHQ"); } }
    private static SetupTask Find(string id)
    {
        foreach (SetupTask task in Catalog) if (task.Id == id) return task;
        throw new ArgumentException("Unknown task: " + id);
    }
    private static List<SetupTask> Select(string ids, bool dependencies)
    {
        List<SetupTask> result = new List<SetupTask>();
        foreach (string id in ids.Split(','))
        {
            if (id.Trim() == "all") { foreach (SetupTask task in Catalog) Add(result, task, dependencies); }
            else Add(result, Find(id.Trim()), dependencies);
        }
        return result;
    }
    private static void Add(List<SetupTask> list, SetupTask task, bool dependencies)
    {
        if (dependencies) foreach (string id in task.Dependencies) Add(list, Find(id), true);
        if (!list.Contains(task)) list.Add(task);
    }
    private static int ProcessOutput(string executable, string arguments, Action<string> output)
    {
        ProcessStartInfo start = new ProcessStartInfo(executable, arguments);
        start.WorkingDirectory = Root;
        start.UseShellExecute = false;
        start.CreateNoWindow = true;
        start.RedirectStandardOutput = true;
        start.RedirectStandardError = true;
        using (Process process = Process.Start(start))
        {
            Task stdout = Task.Factory.StartNew(delegate { Pump(process.StandardOutput, output); });
            Task stderr = Task.Factory.StartNew(delegate { Pump(process.StandardError, output); });
            process.WaitForExit();
            Task.WaitAll(stdout, stderr);
            return process.ExitCode;
        }
    }
    private static void Pump(StreamReader input, Action<string> output)
    {
        string line;
        while ((line = input.ReadLine()) != null) output(line);
    }
    private static int Invoke(SetupTask task, string mode, Action<string> output)
    {
        if (TestInvoke != null) return TestInvoke(task, mode, output);
        return ProcessOutput(Path.Combine(Root, "InstallStreet.Cli.exe"), "--task " + task.Id + " " + mode, output);
    }
    private static int InvokeInProcess(SetupTask task, string mode, Action<string> output)
    {
        string relative;
        switch (task.Id)
        {
            case "git": relative = @"AppL\Git.dll"; break;
            case "gh": relative = @"AppL\GitHubCLI.dll"; break;
            case "chrome": relative = @"AppL\GoogleChrome.dll"; break;
            case "winget": relative = @"AppL\winget.dll"; break;
            case "codex": relative = @"AppL\codex.dll"; break;
            case "rufus": relative = @"AppL\Rufus.dll"; break;
            case "vscode": relative = @"AppL\VSCode.dll"; break;
            case "dotnet10": relative = @"AppL\Dotnet10.dll"; break;
            case "roblox": relative = @"AppL\Roblox.dll"; break;
            case "nvm-windows": relative = @"AppL\nvm-windows.dll"; break;
            case "playwright": relative = @"AppL\Playwright.dll"; break;
            case "react": relative = @"AppL\React.dll"; break;
            case "tailwind": relative = @"AppL\Tailwind.dll"; break;
            case "emscripten": relative = @"AppL\Emscripten.dll"; break;
            case "dimmer": relative = @"AppL\Dimmer.dll"; break;
            case "python": relative = @"AppL\Python.dll"; break;
            case "itunes": relative = @"AppL\iTunes.dll"; break;
            case "icloud": relative = @"AppL\iCloud.dll"; break;
            case "iloader": relative = @"AppL\iLoader.dll"; break;
            case "veracrypt": relative = @"AppL\VeraCrypt.dll"; break;
            case "winrar": relative = @"AppL\WinRAR.dll"; break;
            case "remove-linkedin": relative = @"VaultHouse\Guards\LinkedInRemoval.dll"; break;
            case "consumer-features": relative = @"DisplayCity\ConsumerFeatures.dll"; break;
            case "wallpaper": relative = @"DisplayCity\Wallpaper.dll"; break;
            case "dark-mode": relative = @"DisplayCity\DarkMode.dll"; break;
            case "hidden-files": relative = @"Files\showHiddenFiles.dll"; break;
            case "file-extensions": relative = @"Files\showFileExtensions.dll"; break;
            case "iconsextract": relative = @"AppL\IconsExtract.dll"; break;
            case "desktop-apps": relative = @"VaultHouse\Appointer\desktopn.dll"; break;
            case "running-icon": relative = @"VaultHouse\RunningIcon.dll"; break;
            case "7zip": relative = @"AppL\7zip.dll"; break;
            case "powertoys": relative = @"AppL\powertoys.dll"; break;
            case "terminal": relative = @"AppL\terminal.dll"; break;
            case "notepadplusplus": relative = @"AppL\notepadplusplus.dll"; break;
            case "vlc": relative = @"AppL\vlc.dll"; break;
            case "firefox": relative = @"AppL\firefox.dll"; break;
            case "everything": relative = @"AppL\everything.dll"; break;
            case "sharex": relative = @"AppL\sharex.dll"; break;
            case "obs": relative = @"AppL\obs.dll"; break;
            case "steam": relative = @"AppL\steam.dll"; break;
            case "discord": relative = @"AppL\discord.dll"; break;
            case "nextdns": relative = @"AppL\nextdns.dll"; break;
            case "googledrive": relative = @"AppL\googledrive.dll"; break;
            case "chatgpt": relative = @"AppL\chatgpt.dll"; break;
            case "ahk": relative = @"AppL\AutoHotkey.dll"; break;
            case "clipchamp": relative = @"AppL\Clipchamp.dll"; break;
            case "davinciresolve": relative = @"AppL\DaVinciResolve.dll"; break;
            case "githubdesktop": relative = @"AppL\GitHubDesktop.dll"; break;
            case "godot": relative = @"AppL\Godot.dll"; break;
            case "homebrew": relative = @"AppL\Homebrew.dll"; break;
            case "scoop": relative = @"AppL\Scoop.dll"; break;
            case "tailscale": relative = @"AppL\Tailscale.dll"; break;
            case "visualstudio": relative = @"AppL\VisualStudio.dll"; break;
            case "wsl": relative = @"AppL\WSL.dll"; break;
            case "zoom": relative = @"AppL\Zoom.dll"; break;
            case "developer-mode": relative = @"DisplayCity\DeveloperMode.dll"; break;
            case "long-paths": relative = @"DisplayCity\LongPaths.dll"; break;
            case "disable-bing-search": relative = @"DisplayCity\DisableBingSearch.dll"; break;
            case "taskbar-left": relative = @"DisplayCity\TaskbarLeft.dll"; break;
            case "end-task-context": relative = @"DisplayCity\EndTaskContext.dll"; break;
            default: throw new ArgumentException("Unknown task library: " + task.Id);
        }
        string library = Path.Combine(Root, relative);
        if (!File.Exists(library)) throw new FileNotFoundException("Rebuild InstallStreet: task library is missing.", library);
        System.Reflection.Assembly assembly = System.Reflection.Assembly.LoadFrom(library);
        System.Reflection.MethodInfo execute = assembly.GetType(task.Id == "chrome" ? "GoogleChromeTask" : "InstallStreetTask", true).GetMethod("Execute");
        try { return (int)execute.Invoke(null, new object[] { Root, mode, output }); }
        catch (System.Reflection.TargetInvocationException error) { throw error.InnerException ?? error; }
    }
    // A .running file is kept open only during execution, then renamed to its final state.
    internal static bool Execute(string directory, string id, Func<Action<string>, int> check,
        Func<Action<string>, int> action, int verificationAttempts, Action<string> live)
    {
        string active = Path.Combine(directory, id + ".running");
        bool success = false;
        using (StreamWriter log = new StreamWriter(active, false, Encoding.UTF8))
        {
            object gate = new object();
            Action<string> write = delegate(string line) { lock (gate) { log.WriteLine(line); log.Flush(); live(line); } };
            try
            {
                write("Started " + DateTimeOffset.Now.ToString("o"));
                int initial = check(write);
                if (initial == 0) { write("Already configured; skipped."); success = true; }
                else if (initial != 10) write("Detection failed with exit code " + initial + "; action was not started.");
                else
                {
                    int exit = action(write);
                    write("Action exit code: " + exit);
                    if (exit == 0 || exit == 3010)
                    {
                        if (exit == 3010) write("A restart was requested.");
                        for (int attempt = 0; attempt < verificationAttempts; attempt++)
                        {
                            if (attempt > 0) Thread.Sleep(2000);
                            if (check(write) == 0) { success = true; break; }
                        }
                        if (!success) write("Verification failed. Retry after resolving the issue or restarting if requested.");
                    }
                }
            }
            catch (Exception error) { write("Error: " + error.Message); }
            write(success ? "Result: done" : "Result: failed");
        }
        File.Move(active, Path.Combine(directory, id + (success ? ".done" : ".failed")));
        return success;
    }
    private static void RecoverInterrupted()
    {
        foreach (string file in Directory.GetFiles(Status, "*.running", SearchOption.AllDirectories))
        {
            // Leave old batch logs alone: only session logs belong to this runner.
            if (!Path.GetFileName(Path.GetDirectoryName(file)).StartsWith("run-")) continue;
            File.AppendAllText(file, Environment.NewLine + "Interrupted before a final result. Retry this task." + Environment.NewLine);
            File.Move(file, Path.ChangeExtension(file, ".failed"));
        }
    }
    private static void SaveSummary(List<string> rows)
    {
        string target = Path.Combine(Status, "latest.tsv");
        string temporary = Path.Combine(Status, "latest.tmp");
        File.WriteAllLines(temporary, rows.ToArray(), Encoding.UTF8);
        if (File.Exists(target)) File.Replace(temporary, target, null);
        else File.Move(temporary, target);
    }
    private static int Run(List<SetupTask> tasks)
    {
        Directory.CreateDirectory(Status);
        FileStream runLock;
        try { runLock = new FileStream(Path.Combine(Status, "runner.lock"), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None); }
        catch (IOException) { Console.Error.WriteLine("Another InstallStreet run is active."); return 1; }
        using (runLock)
        {
            RecoverInterrupted();
            string session = Path.Combine(Status, "run-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + "-" + Guid.NewGuid().ToString("N").Substring(0, 8));
            Directory.CreateDirectory(session);
            List<string> rows = new List<string> { "task\tstate\tlog" };
            foreach (SetupTask planned in tasks) rows.Add(planned.Id + "\tpending\t" + Path.Combine(session, planned.Id + ".running"));
            SaveSummary(rows);
            Dictionary<string, bool> results = new Dictionary<string, bool>();
            bool failed = false;
            for (int index = 0; index < tasks.Count; index++)
            {
                SetupTask task = tasks[index];
                Console.WriteLine("\n[{0}/{1}] {2}", index + 1, tasks.Count, task.Name);
                Report(task.Id, "Running", index, tasks.Count);
                bool ok;
                try { ok = Execute(session, task.Id,
                    delegate(Action<string> output) { return Invoke(task, "Check", output); },
                    delegate(Action<string> output) { return Invoke(task, "Run", output); }, 6, Console.WriteLine); }
                catch (Exception error) {
                    ok = false;
                    Console.WriteLine("Task failed: " + error.Message + ". Continuing.");
                    try { File.WriteAllText(Path.Combine(session, task.Id + ".failed"), error.ToString()); } catch { }
                }
                Report(task.Id, ok ? "Done" : "Failed", index + 1, tasks.Count);
                results[task.Id] = ok;
                failed |= !ok;
                rows[index + 1] = task.Id + "\t" + (ok ? "done" : "failed") + "\t" + Path.Combine(session, task.Id + (ok ? ".done" : ".failed"));
                SaveSummary(rows);
            }
            File.WriteAllLines(Path.Combine(session, "summary.tsv"), rows.ToArray(), Encoding.UTF8);
            Console.WriteLine("\nSummary:");
            foreach (SetupTask task in tasks) Console.WriteLine("[{0}] {1}", results[task.Id] ? "DONE" : "FAILED", task.Name);
            Console.WriteLine("Logs: " + session);
            return failed ? 1 : 0;
        }
    }
    private static int Check(List<SetupTask> tasks)
    {
        bool error = false;
        int completed = 0;
        foreach (SetupTask task in tasks)
        {
            Report(task.Id, "Checking", completed, tasks.Count);
            int code;
            try { code = Invoke(task, "Check", Console.WriteLine); }
            catch (Exception failure) { Console.WriteLine(failure.Message); code = 1; }
            Console.WriteLine("[{0}] {1}", code == 0 ? "READY" : code == 10 ? "NEEDS SETUP" : "ERROR", task.Name);
            Report(task.Id, code == 0 ? "Ready" : code == 10 ? "Needs setup" : "Error", ++completed, tasks.Count);
            error |= code != 0 && code != 10;
        }
        return error ? 1 : 0;
    }
    private static int Retry()
    {
        string summary = Path.Combine(Status, "latest.tsv");
        if (!File.Exists(summary)) { Console.WriteLine("No previous run to retry."); return 0; }
        List<SetupTask> tasks = new List<SetupTask>();
        foreach (string line in File.ReadAllLines(summary))
        {
            string[] fields = line.Split('\t');
            if (fields.Length >= 2 && (fields[1] == "failed" || fields[1] == "pending")) Add(tasks, Find(fields[0]), true);
        }
        if (tasks.Count == 0) { Console.WriteLine("No failed tasks in the latest run."); return 0; }
        return Run(tasks);
    }
    private static void Help()
    {
        Console.WriteLine("InstallStreet -- setup for this PC");
        Console.WriteLine("Desktop UI: open InstallStreet.exe");
        Console.WriteLine("--check [all|id,id]   Check only; no installs, settings changes, or logs");
        Console.WriteLine("--run all|id,id       Run chosen tasks; include required dependencies");
        Console.WriteLine("--retry               Retry failed tasks from the latest run");
        Console.WriteLine("--register-icon       Register your .running icon");
        Console.WriteLine("--self-test           Test the runner using temporary fixtures");
        Console.WriteLine("--terminal            Open the terminal menu");
        foreach (SetupTask task in Catalog) Console.WriteLine("  " + task.Id + " : " + task.Name);
    }
    private static int Menu()
    {
        while (true)
        {
            Console.WriteLine("\nINSTALLSTREET\nR: run setup  C: check only  F: retry setup  Q: quit");
            string input = Console.ReadLine();
            if (input == null || input.Trim().Equals("q", StringComparison.OrdinalIgnoreCase)) return 0;
            switch (input.Trim().ToLowerInvariant())
            {
                case "r": case "f": Run(Select("all", true)); break;
                case "c": Check(Select("all", false)); break;
                default: Console.WriteLine("Enter R, C, F, or Q."); break;
            }
        }
    }
    private static void Assert(bool condition, string message) { if (!condition) throw new Exception("Self-test failed: " + message); }
    private static int SelfTest()
    {
        string directory = Path.Combine(DataRoot, "tmp", "runner-tests", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        Action<string> quiet = delegate(string line) { };
        bool acted = false;
        Assert(Execute(directory, "skip", delegate(Action<string> o) { return 0; }, delegate(Action<string> o) { acted = true; return 1; }, 1, quiet) && !acted, "configured task must skip action");
        int checks = 0;
        Assert(Execute(directory, "success", delegate(Action<string> o) { return ++checks == 1 ? 10 : 0; }, delegate(Action<string> o) {
            Assert(File.Exists(Path.Combine(directory, "success.running")), "active marker missing");
            return ProcessOutput(Environment.GetEnvironmentVariable("COMSPEC"), "/d /c \"echo fixture-output & exit /b 0\"", o);
        }, 1, quiet), "successful action must verify");
        Assert(File.ReadAllText(Path.Combine(directory, "success.done")).Contains("fixture-output"), "child output not captured");
        Assert(!Execute(directory, "bad-exit", delegate(Action<string> o) { return 10; }, delegate(Action<string> o) { return 7; }, 1, quiet), "nonzero action must fail");
        Assert(!Execute(directory, "bad-verify", delegate(Action<string> o) { return 10; }, delegate(Action<string> o) { return 0; }, 1, quiet), "unverified action must fail");
        Assert(!Execute(directory, "exception", delegate(Action<string> o) { throw new IOException("fixture exception"); }, delegate(Action<string> o) { return 0; }, 1, quiet), "exceptions must fail");
        Assert(Directory.GetFiles(directory, "*.running").Length == 0, "active markers must finalize");
        Assert(Select("codex", true)[0].Id == "winget", "dependencies must precede tasks");
        Assert(Select("codex,winget", true).Count == 2, "dependencies must deduplicate");
        TestStatus = Path.Combine(directory, "StatusHQ");
        try
        {
            int attempted = 0;
            TestInvoke = delegate(SetupTask task, string mode, Action<string> output) {
                attempted++;
                if (task.Id == "chrome") throw new InvalidOperationException("fixture task crash");
                return 0;
            };
            Assert(Check(Select("chrome,dimmer", false)) == 1 && attempted == 2, "check must continue after task exception");
            attempted = 0;
            Assert(Run(Select("chrome,dimmer", true)) == 1 && attempted == 2, "run must continue after task exception");
            TestInvoke = delegate(SetupTask task, string mode, Action<string> output) { return 10; };
            int beforeCheck = Directory.GetFiles(Status, "*", SearchOption.AllDirectories).Length;
            Assert(Check(Select("chrome", false)) == 0 && Directory.GetFiles(Status, "*", SearchOption.AllDirectories).Length == beforeCheck, "check-only must not create status files");
            TestInvoke = delegate(SetupTask task, string mode, Action<string> output) {
                if (mode == "Check") return task.Id == "chrome" ? 0 : 10;
                return task.Id == "winget" ? 7 : 0;
            };
            Assert(Run(Select("chrome,codex", true)) == 1, "failed dependency must fail run");
            string[] failedRows = File.ReadAllLines(Path.Combine(Status, "latest.tsv"));
            Assert(failedRows.Length == 4 && failedRows[3].Contains("codex\tfailed"), "failed task must be recorded for retry");
            Assert(File.ReadAllText(failedRows[3].Split('\t')[2]).Contains("Action exit code: 0"), "task must be attempted despite failed dependency");
            TestInvoke = delegate(SetupTask task, string mode, Action<string> output) { return 0; };
            Assert(Retry() == 0, "retry must recover failed tasks");
            Assert(File.ReadAllLines(Path.Combine(Status, "latest.tsv")).Length == 3, "retry must exclude successful tasks");
            using (FileStream held = new FileStream(Path.Combine(Status, "runner.lock"), FileMode.Open, FileAccess.ReadWrite, FileShare.None))
                Assert(Run(Select("chrome", true)) == 1, "overlapping run must be rejected");
            string abandoned = Path.Combine(Status, "run-interrupted-fixture");
            Directory.CreateDirectory(abandoned);
            File.WriteAllText(Path.Combine(abandoned, "chrome.running"), "Interrupted fixture");
            SaveSummary(new List<string> { "task\tstate\tlog", "chrome\tpending\t" + Path.Combine(abandoned, "chrome.running") });
            Assert(Retry() == 0, "interrupted pending task must retry");
            Assert(File.Exists(Path.Combine(abandoned, "chrome.failed")) && !File.Exists(Path.Combine(abandoned, "chrome.running")), "interrupted marker must finalize");
        }
        finally { TestInvoke = null; TestStatus = null; }
        Console.WriteLine("Runner self-tests passed. Fixtures: " + directory);
        return 0;
    }
    [STAThread]
    private static int Main(string[] args)
    {
        Console.OutputEncoding = new UTF8Encoding(false);
        using (WindowsIdentity identity = WindowsIdentity.GetCurrent())
        {
            if (!new WindowsPrincipal(identity).IsInRole(WindowsBuiltInRole.Administrator))
            { Console.Error.WriteLine("InstallStreet requires administrator access."); return 1; }
        }
        try
        {
            if (args.Length == 3 && args[0] == "--task") {
                if (args[2] != "Check" && args[2] != "Run") throw new ArgumentException("Invalid task mode.");
                return InvokeInProcess(Find(args[1]), args[2], Console.WriteLine);
            }
            if (args.Length == 0) { Help(); return 0; }
            if (args.Length == 1 && args[0] == "--terminal") return Menu();

            if (args[0] == "--help" && args.Length == 1) { Help(); return 0; }
            if (args[0] == "--check" && args.Length <= 2) return Check(Select(args.Length == 2 ? args[1] : "all", false));
            if (args[0] == "--run" && args.Length == 2) return Run(Select(args[1], true));
            if (args[0] == "--retry" && args.Length == 1) return Retry();
            if (args[0] == "--register-icon" && args.Length == 1) return Run(Select("running-icon", true));
            if (args[0] == "--self-test" && args.Length == 1) return SelfTest();
            Help();
            return 1;
        }
        catch (Exception error) { Console.Error.WriteLine(error.Message); return 1; }
    }
}























