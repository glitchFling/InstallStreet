using System;
using System.Reflection;
public static class EmscriptenTask
{
    public static int Execute(string root, string mode, Action<string> output)
    {
        return ScriptTaskRuntime.Execute(Assembly.GetExecutingAssembly(), root, "emscripten", mode, output);
    }
}
