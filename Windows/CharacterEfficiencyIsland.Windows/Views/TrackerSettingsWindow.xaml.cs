using System.Collections.ObjectModel;
using System.Windows;
using CharacterEfficiencyIsland.Windows.Core;
using CharacterEfficiencyIsland.Windows.Services;

namespace CharacterEfficiencyIsland.Windows.Views;

public partial class TrackerSettingsWindow : Window
{
    private readonly TrackerStore _store;
    private readonly WindowsCalendarReader _reader;
    private readonly Func<Task> _calendarChanged;
    private readonly ObservableCollection<CalendarChoice> _choices = new();
    private bool _refreshing;

    internal TrackerSettingsWindow(TrackerStore store, WindowsCalendarReader reader, Func<Task> calendarChanged)
    {
        _store = store;
        _reader = reader;
        _calendarChanged = calendarChanged;
        InitializeComponent();
        CalendarList.ItemsSource = _choices;
    }

    public async void ShowSettings(Window owner)
    {
        Owner = owner;
        if (!_reader.CanRead) await _reader.RequestAccessAsync();
        ReloadChoices();
        if (!IsVisible) Show();
        Activate();
    }

    private void ReloadChoices()
    {
        _refreshing = true;
        _choices.Clear();
        var selected = _store.State.SelectedCalendarIds is null
            ? null
            : new HashSet<string>(_store.State.SelectedCalendarIds);
        foreach (var source in _reader.AvailableCalendars)
        {
            source.IsSelected = selected is null || selected.Contains(source.Id);
            _choices.Add(source);
        }
        _refreshing = false;
        UpdateStatus();
    }

    private void CalendarSelection_OnChanged(object sender, RoutedEventArgs e)
    {
        if (_refreshing) return;
        SaveSelection();
    }

    private void SaveSelection()
    {
        _store.State.SelectedCalendarIds = _choices.Where(item => item.IsSelected).Select(item => item.Id).ToList();
        _store.Save();
        UpdateStatus();
    }

    private void UpdateStatus()
    {
        SelectionStatus.Text = $"已选 {_choices.Count(item => item.IsSelected)}/{_choices.Count}";
        Explanation.Text = $"{_reader.StatusText}\nTracker 只申请 Windows 日历的只读权限，不会创建、修改或删除日历事项。选择和本地计划只保存在本机。";
    }

    private void SelectAll_OnClick(object sender, RoutedEventArgs e)
    {
        _refreshing = true;
        foreach (var item in _choices) item.IsSelected = true;
        CalendarList.Items.Refresh();
        _refreshing = false;
        SaveSelection();
    }

    private void SelectNone_OnClick(object sender, RoutedEventArgs e)
    {
        _refreshing = true;
        foreach (var item in _choices) item.IsSelected = false;
        CalendarList.Items.Refresh();
        _refreshing = false;
        SaveSelection();
    }

    private async void Refresh_OnClick(object sender, RoutedEventArgs e)
    {
        await _reader.RequestAccessAsync();
        ReloadChoices();
        await _calendarChanged();
    }

    private async void Done_OnClick(object sender, RoutedEventArgs e)
    {
        SaveSelection();
        await _calendarChanged();
        Close();
    }
}
