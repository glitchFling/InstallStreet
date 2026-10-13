using System;
using System.Reflection;
public static class ReactTask
{
    public static int Execute(string root, string mode, Action<string> output)
    {
        return ScriptTaskRuntime.Execute(Assembly.GetExecutingAssembly(), root, "react", mode, output);
    }
}
