using Microsoft.Win32;

namespace CharacterEfficiencyIsland.Windows.Interop;

internal static class StartupManager
{
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";

    public static bool IsEnabled(string appName)
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey, false);
        return key?.GetValue(appName) is string value && !string.IsNullOrWhiteSpace(value);
    }

    public static bool SetEnabled(string appName, bool enabled)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKey, true);
            if (key is null)
            {
                return false;
            }
            if (enabled)
            {
                var executable = Environment.ProcessPath;
                if (string.IsNullOrWhiteSpace(executable))
                {
                    return false;
                }
                key.SetValue(appName, $"\"{executable}\" --startup", RegistryValueKind.String);
            }
            else
            {
                key.DeleteValue(appName, false);
            }
            return IsEnabled(appName) == enabled;
        }
        catch
        {
            return false;
        }
    }
}
