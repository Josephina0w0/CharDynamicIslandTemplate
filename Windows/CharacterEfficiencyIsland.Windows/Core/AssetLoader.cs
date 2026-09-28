using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Drawing = System.Drawing;

namespace CharacterEfficiencyIsland.Windows.Core;

internal static class AssetLoader
{
    private static readonly Dictionary<string, ImageSource> Cache = new(StringComparer.OrdinalIgnoreCase);

    public static ImageSource Image(string assetName)
    {
        if (Cache.TryGetValue(assetName, out var cached))
        {
            return cached;
        }

        var uri = new Uri($"pack://application:,,,/Assets/{assetName}.png", UriKind.Absolute);
        var image = new BitmapImage();
        image.BeginInit();
        image.UriSource = uri;
        image.CacheOption = BitmapCacheOption.OnLoad;
        image.EndInit();
        image.Freeze();
        Cache[assetName] = image;
        return image;
    }

    public static Drawing.Icon TrayIcon()
    {
        var resource = System.Windows.Application.GetResourceStream(
            new Uri("pack://application:,,,/Assets/statusIcon.png", UriKind.Absolute));
        if (resource is null)
        {
            return (Drawing.Icon)Drawing.SystemIcons.Application.Clone();
        }

        using var bitmap = new Drawing.Bitmap(resource.Stream);
        var handle = bitmap.GetHicon();
        try
        {
            using var icon = Drawing.Icon.FromHandle(handle);
            return (Drawing.Icon)icon.Clone();
        }
        finally
        {
            DestroyIcon(handle);
        }
    }

    public static string IslandAsset(CharacterMode mode) => mode switch
    {
        CharacterMode.BreakTime => "break",
        CharacterMode.Idle => "idle",
        CharacterMode.Ai => "ai",
        CharacterMode.Water => "water",
        CharacterMode.ReminderFirst => "reminder-first",
        CharacterMode.ReminderSecond => "reminder-second",
        CharacterMode.ReminderThird => "reminder-third",
        CharacterMode.ReminderFourth => "reminder-fourth",
        CharacterMode.Alert => "alert",
        _ => "working"
    };

    public static string PanelAsset(CharacterMode mode) => mode switch
    {
        CharacterMode.BreakTime => "panel-break",
        CharacterMode.Idle => "panel-idle",
        CharacterMode.Ai => "panel-ai",
        CharacterMode.Water => "panel-water",
        CharacterMode.ReminderFirst => "panel-water",
        CharacterMode.ReminderSecond => "panel-reminder-second",
        CharacterMode.ReminderThird => "panel-reminder-third",
        CharacterMode.ReminderFourth => "panel-reminder-fourth",
        CharacterMode.Alert => "panel-ai",
        _ => "panel-working"
    };

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool DestroyIcon(IntPtr handle);
}
