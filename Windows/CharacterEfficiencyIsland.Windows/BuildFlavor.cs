namespace CharacterEfficiencyIsland.Windows;

internal static class BuildFlavor
{
    // The companion branch changes only this default. Both window implementations
    // stay in the shared core so fixes do not have to be copied between products.
    public const string Value = "companion";
}
