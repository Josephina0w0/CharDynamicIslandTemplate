using System.Reflection;
using System.Text.Json;

namespace CharacterEfficiencyIsland.Windows.Core;

internal static class ProfileLoader
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true
    };

    public static AppProfile Load()
    {
        var assembly = Assembly.GetExecutingAssembly();
        var resourceName = assembly.GetManifestResourceNames()
            .FirstOrDefault(name => name.EndsWith("profile.json", StringComparison.OrdinalIgnoreCase));
        if (resourceName is null)
        {
            return new AppProfile();
        }

        using var stream = assembly.GetManifestResourceStream(resourceName);
        if (stream is null)
        {
            return new AppProfile();
        }

        return JsonSerializer.Deserialize<AppProfile>(stream, Options) ?? new AppProfile();
    }
}
