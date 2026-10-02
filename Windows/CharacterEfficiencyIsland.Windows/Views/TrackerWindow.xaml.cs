using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shapes;
using CharacterEfficiencyIsland.Windows.Core;
using CharacterEfficiencyIsland.Windows.Services;

namespace CharacterEfficiencyIsland.Windows.Views;

public partial class TrackerWindow : Window
{
    private sealed record CalendarCell(System.Windows.Controls.Button Button, TextBlock Number, Ellipse Dot);

    private readonly TrackerStore _store;
    private readonly WindowsCalendarReader _calendarReader;
    private readonly Action _openSettings;
    private readonly Action _openProjects;
    private readonly List<CalendarCell> _calendarCells = new();
    private ObservableCollection<TrackerTask> _tasks = new();
    private IReadOnlyList<TrackerCalendarItem> _calendarItems = Array.Empty<TrackerCalendarItem>();
    private DateTime _displayedMonth;
    private DateTime _selectedDate;
    private bool _calendarInitialized;
    private bool _allowClose;

    internal TrackerWindow(
        TrackerStore store,
        WindowsCalendarReader calendarReader,
        Action openSettings,
        Action openProjects)
    {
        _store = store;
        _calendarReader = calendarReader;
        _openSettings = openSettings;
        _openProjects = openProjects;
        InitializeComponent();
        Closing += (_, args) =>
        {
            SaveWindowState();
            if (!_allowClose)
            {
                args.Cancel = true;
                Hide();
            }
        };

        TitleEditor.Text = _store.State.TrackerTitle;
        _selectedDate = ParseDate(_store.State.SelectedDate, DateTime.Today);
        _displayedMonth = MonthStart(ParseDate(_store.State.DisplayedMonth, _selectedDate));
        TrackerCharacter.Source = AssetLoader.TrackerCharacter();
        BuildCalendar();
        LoadTasks();
        RefreshAll();
    }

    public async void ShowTracker()
    {
        if (!IsVisible) Show();
        RestoreOrDefaultPosition();
        Activate();
        Topmost = true;
        Topmost = false;
        if (!_calendarInitialized)
        {
            _calendarInitialized = true;
            await RefreshCalendarAsync(true);
        }
        else
        {
            await RefreshCalendarAsync(false);
        }
    }

    public async Task RefreshCalendarAsync(bool requestAccess)
    {
        if (requestAccess || !_calendarReader.CanRead)
        {
            await _calendarReader.RequestAccessAsync();
        }
        var rangeStart = _displayedMonth.AddDays(-21);
        var rangeEnd = _displayedMonth.AddMonths(3).AddDays(21);
        _calendarItems = await _calendarReader.ReadAsync(
            rangeStart,
            rangeEnd,
            _store.State.SelectedCalendarIds);
        CalendarStatus.Text = _calendarReader.CanRead
            ? $"Windows 日历 · 只读 · {_calendarReader.AvailableCalendars.Count} 个"
            : "本地计划 · 日历未授权";
        PopulateCalendar();
        RefreshLists();
    }

    public void CloseForExit()
    {
        _allowClose = true;
        Hide();
        SaveWindowState();
        Close();
    }

    private void BuildCalendar()
    {
        foreach (var name in new[] { "一", "二", "三", "四", "五", "六", "日" })
        {
            CalendarGrid.Children.Add(new TextBlock
            {
                Text = name,
                TextAlignment = TextAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                FontSize = 10.5,
                FontWeight = FontWeights.SemiBold,
                Foreground = (System.Windows.Media.Brush)FindResource("SecondaryText")
            });
        }

        for (var index = 0; index < 42; index++)
        {
            var grid = new Grid();
            var number = new TextBlock
            {
                TextAlignment = TextAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                FontSize = 11.5,
                FontWeight = FontWeights.Medium
            };
            var dot = new Ellipse
            {
                Width = 3.5,
                Height = 3.5,
                Fill = new SolidColorBrush(System.Windows.Media.Color.FromArgb(150, 60, 60, 60)),
                HorizontalAlignment = System.Windows.HorizontalAlignment.Center,
                VerticalAlignment = System.Windows.VerticalAlignment.Bottom,
                Margin = new Thickness(0, 0, 0, 1),
                Visibility = Visibility.Collapsed
            };
            grid.Children.Add(number);
            grid.Children.Add(dot);
            var button = new System.Windows.Controls.Button
            {
                Content = grid,
                Background = System.Windows.Media.Brushes.Transparent,
                BorderThickness = new Thickness(0),
                Margin = new Thickness(0),
                Padding = new Thickness(0),
                MinHeight = 0,
                Focusable = false,
                Visibility = Visibility.Hidden
            };
            button.Click += CalendarDay_OnClick;
            _calendarCells.Add(new CalendarCell(button, number, dot));
            CalendarGrid.Children.Add(button);
        }
    }

    private void PopulateCalendar()
    {
        MonthLabel.Text = $"{_displayedMonth:yyyy 年 M 月}";
        var firstColumn = ((int)_displayedMonth.DayOfWeek + 6) % 7;
        var days = DateTime.DaysInMonth(_displayedMonth.Year, _displayedMonth.Month);
        for (var index = 0; index < _calendarCells.Count; index++)
        {
            var cell = _calendarCells[index];
            var day = index - firstColumn + 1;
            if (day < 1 || day > days)
            {
                cell.Button.Tag = null;
                cell.Button.Visibility = Visibility.Hidden;
                continue;
            }

            var date = new DateTime(_displayedMonth.Year, _displayedMonth.Month, day);
            cell.Button.Tag = date;
            cell.Button.Visibility = Visibility.Visible;
            cell.Number.Text = day.ToString();
            cell.Number.FontWeight = date == DateTime.Today ? FontWeights.SemiBold : FontWeights.Medium;
            cell.Button.Background = date == _selectedDate
                ? new SolidColorBrush(System.Windows.Media.Color.FromArgb(28, 30, 30, 30))
                : date == DateTime.Today
                    ? new SolidColorBrush(System.Windows.Media.Color.FromArgb(18, 30, 30, 30))
                    : System.Windows.Media.Brushes.Transparent;
            cell.Dot.Visibility = _calendarItems.Any(item => item.Start.Date == date)
                ? Visibility.Visible
                : Visibility.Collapsed;
        }
    }

    private void CalendarDay_OnClick(object sender, RoutedEventArgs e)
    {
        if ((sender as System.Windows.Controls.Button)?.Tag is not DateTime date) return;
        SaveTasks();
        _selectedDate = date;
        _store.State.SelectedDate = date.ToString("yyyy-MM-dd");
        _store.Save();
        LoadTasks();
        RefreshAll();
    }

    private void LoadTasks()
    {
        _tasks = _store.TasksFor(_selectedDate);
        TaskList.ItemsSource = _tasks;
    }

    private void SaveTasks() => _store.SaveTasks(_selectedDate, _tasks);

    private void RefreshAll()
    {
        PopulateCalendar();
        SelectedDateTitle.Text = $"{_selectedDate:MM-dd} · 日历与个人计划";
        RefreshLists();
    }

    private void RefreshLists()
    {
        var selected = _calendarItems
            .Where(item => item.Start.Date == _selectedDate.Date)
            .Take(2)
            .Select(item => item.DisplayText)
            .ToList();
        SelectedDateItems.ItemsSource = selected.Count == 0
            ? new[] { "这一天没有日历事项或未完成计划" }
            : selected;

        var upcoming = _calendarItems
            .Where(item => item.Start.Date >= DateTime.Today)
            .OrderBy(item => item.Start)
            .Take(5)
            .Select(item => item.UpcomingText)
            .ToList();
        UpcomingItems.ItemsSource = upcoming.Count == 0
            ? new[] { "暂无未完成的近期关键日期" }
            : upcoming;
    }

    private async void PreviousMonth_OnClick(object sender, RoutedEventArgs e)
    {
        _displayedMonth = _displayedMonth.AddMonths(-1);
        PersistDates();
        RefreshAll();
        await RefreshCalendarAsync(false);
    }

    private async void NextMonth_OnClick(object sender, RoutedEventArgs e)
    {
        _displayedMonth = _displayedMonth.AddMonths(1);
        PersistDates();
        RefreshAll();
        await RefreshCalendarAsync(false);
    }

    private void PersistDates()
    {
        _store.State.DisplayedMonth = _displayedMonth.ToString("yyyy-MM-dd");
        _store.State.SelectedDate = _selectedDate.ToString("yyyy-MM-dd");
        _store.Save();
    }

    private void Task_OnChanged(object sender, RoutedEventArgs e) => SaveTasks();

    private void TitleEditor_OnLostKeyboardFocus(object sender, KeyboardFocusChangedEventArgs e)
    {
        _store.State.TrackerTitle = string.IsNullOrWhiteSpace(TitleEditor.Text)
            ? "Tracker"
            : TitleEditor.Text.Trim();
        TitleEditor.Text = _store.State.TrackerTitle;
        _store.Save();
    }

    private void Root_OnMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed || IsInteractive(e.OriginalSource as DependencyObject)) return;
        try
        {
            DragMove();
            SaveWindowState();
        }
        catch
        {
            // Mouse capture can be lost while crossing monitors.
        }
    }

    private static bool IsInteractive(DependencyObject? source)
    {
        for (var current = source; current is not null; current = VisualTreeHelper.GetParent(current))
        {
            if (current is System.Windows.Controls.Primitives.ButtonBase or
                System.Windows.Controls.Primitives.TextBoxBase) return true;
        }
        return false;
    }

    private void Window_OnKeyDown(object sender, System.Windows.Input.KeyEventArgs e)
    {
        if (e.Key == Key.Escape) Hide();
    }

    private void Settings_OnClick(object sender, RoutedEventArgs e) => _openSettings();
    private void Projects_OnClick(object sender, RoutedEventArgs e) => _openProjects();
    private void OpenRecords_OnClick(object sender, RoutedEventArgs e) => _store.OpenFolder();

    private void ResetPosition_OnClick(object sender, RoutedEventArgs e)
    {
        var area = SystemParameters.WorkArea;
        Left = area.Left + 40;
        Top = area.Top + Math.Max(20, (area.Height - Height) / 2);
        SaveWindowState();
    }

    private void RestoreOrDefaultPosition()
    {
        if (_store.State.WindowLeft is double left && _store.State.WindowTop is double top &&
            left < SystemParameters.VirtualScreenWidth && top < SystemParameters.VirtualScreenHeight &&
            left + Width > SystemParameters.VirtualScreenLeft && top + Height > SystemParameters.VirtualScreenTop)
        {
            Left = left;
            Top = top;
            return;
        }
        ResetPosition_OnClick(this, new RoutedEventArgs());
    }

    private void SaveWindowState()
    {
        if (!IsLoaded) return;
        _store.State.WindowLeft = Left;
        _store.State.WindowTop = Top;
        _store.Save();
    }

    private static DateTime MonthStart(DateTime date) => new(date.Year, date.Month, 1);

    private static DateTime ParseDate(string? value, DateTime fallback) =>
        DateTime.TryParse(value, out var result) ? result.Date : fallback.Date;
}
