using System;
using System.Reflection;
public static class TailwindTask
{
    public static int Execute(string root, string mode, Action<string> output)
    {
        return ScriptTaskRuntime.Execute(Assembly.GetExecutingAssembly(), root, "tailwind", mode, output);
    }
}
