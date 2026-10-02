using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace CharacterEfficiencyIsland.Windows.Core;

public sealed class TrackerTask : INotifyPropertyChanged
{
    private string _text = "点击这里编辑任务";
    private bool _isDone;

    public string Text { get => _text; set => Set(ref _text, value); }
    public bool IsDone { get => _isDone; set => Set(ref _isDone, value); }

    public event PropertyChangedEventHandler? PropertyChanged;

    private void Set<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}

public sealed class TrackerProject : INotifyPropertyChanged
{
    private string _priority = "B";
    private string _projectName = "新项目";
    private string _workstream = "";
    private string _stage = "计划中";
    private string _ownerCollaborators = "";
    private string _stakeholdersNotes = "";
    private string _lastUpdated = DateTime.Today.ToString("yyyy-MM-dd");
    private string _nextFollowUp = "";
    private string _deadline = "";
    private string _nextAction = "";

    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string Priority { get => _priority; set => Set(ref _priority, value); }
    public string ProjectName { get => _projectName; set => Set(ref _projectName, value); }
    public string Workstream { get => _workstream; set => Set(ref _workstream, value); }
    public string Stage { get => _stage; set => Set(ref _stage, value); }
    public string OwnerCollaborators { get => _ownerCollaborators; set => Set(ref _ownerCollaborators, value); }
    public string StakeholdersNotes { get => _stakeholdersNotes; set => Set(ref _stakeholdersNotes, value); }
    public string LastUpdated { get => _lastUpdated; set => Set(ref _lastUpdated, value); }
    public string NextFollowUp { get => _nextFollowUp; set => Set(ref _nextFollowUp, value); }
    public string Deadline { get => _deadline; set => Set(ref _deadline, value); }
    public string NextAction { get => _nextAction; set => Set(ref _nextAction, value); }

    public event PropertyChangedEventHandler? PropertyChanged;

    private void Set<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}

public sealed class TrackerState
{
    public string TrackerTitle { get; set; } = "日常 Tracker";
    public string DisplayedMonth { get; set; } = DateTime.Today.ToString("yyyy-MM-dd");
    public string SelectedDate { get; set; } = DateTime.Today.ToString("yyyy-MM-dd");
    public List<string>? SelectedCalendarIds { get; set; }
    public Dictionary<string, List<TrackerTask>> DailyTasksByDate { get; set; } = new();
    public List<TrackerProject> Projects { get; set; } = new();
    public string NewProjectPriority { get; set; } = "B";
    public string FocusStatus { get; set; } = "进行中";
    public string FocusNextAction { get; set; } = "写下当前最重要目标的下一步行动";
    public double? WindowLeft { get; set; }
    public double? WindowTop { get; set; }
}

public sealed record CalendarChoice(string Id, string Title, string SourceTitle)
{
    public bool IsSelected { get; set; }
    public string DisplayName => string.IsNullOrWhiteSpace(SourceTitle) ? Title : $"{Title} · {SourceTitle}";
}

public sealed record TrackerCalendarItem(
    string Id,
    string CalendarId,
    string CalendarName,
    string Title,
    DateTime Start,
    DateTime End,
    bool IsAllDay)
{
    public string DateKey => Start.ToString("yyyy-MM-dd");
    public string DisplayText => IsAllDay
        ? $"全天 · {Title}"
        : $"{Start:HH:mm} · {Title}";
    public string UpcomingText => $"{Start:MM-dd}  {Title}";
}
