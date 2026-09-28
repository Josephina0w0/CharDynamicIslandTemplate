using CharacterEfficiencyIsland.Windows.Core;

namespace CharacterEfficiencyIsland.Windows.Views;

public interface ICharacterSurface
{
    void Refresh(AppState state);
    void ShowSurface();
    void HideSurface();
    void ResetScale();
}
