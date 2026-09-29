using CharacterEfficiencyIsland.Windows.Core;
using CharacterEfficiencyIsland.Windows.Views;

namespace CharacterEfficiencyIsland.Windows.Services;

internal sealed class TrackerCoordinator
{
    private readonly TrackerStore _store;
    private readonly WindowsCalendarReader _calendarReader;
    private readonly TrackerWindow _trackerWindow;

    public TrackerCoordinator(AppProfile profile)
    {
        _store = new TrackerStore(profile);
        _calendarReader = new WindowsCalendarReader();
        _trackerWindow = new TrackerWindow(_store, _calendarReader, OpenSettings, OpenProjects);
    }

    public void Show() => _trackerWindow.ShowTracker();

    public void CloseForExit() => _trackerWindow.CloseForExit();

    private void OpenSettings()
    {
        var settings = new TrackerSettingsWindow(
            _store,
            _calendarReader,
            () => _trackerWindow.RefreshCalendarAsync(false));
        settings.ShowSettings(_trackerWindow);
    }

    private void OpenProjects()
    {
        var projects = new ProjectPipelineWindow(_store);
        projects.ShowProjects(_trackerWindow);
    }
}
