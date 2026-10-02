using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Text.Json;

namespace CharacterEfficiencyIsland.Windows.Core;

internal sealed class TrackerStore
{
    private readonly string _folder;
    private readonly string _statePath;
    private readonly JsonSerializerOptions _options = new()
    {
        WriteIndented = true,
        PropertyNameCaseInsensitive = true
    };

    public TrackerStore(AppProfile profile)
    {
        _folder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            profile.StorageId,
            "Tracker");
        _statePath = Path.Combine(_folder, "tracker-state.json");
        State = Load();
    }

    public TrackerState State { get; }
    public string Folder => _folder;

    public ObservableCollection<TrackerTask> TasksFor(DateTime date)
    {
        var key = date.ToString("yyyy-MM-dd");
        if (!State.DailyTasksByDate.TryGetValue(key, out var tasks))
        {
            tasks = new List<TrackerTask>
            {
                new() { Text = "今日重点：完成最重要的一件事" },
                new() { Text = "沟通协作：处理一次必要沟通" },
                new() { Text = "执行推进：推进一个项目下一步" }
            };
            State.DailyTasksByDate[key] = tasks;
        }
        while (tasks.Count < 3) tasks.Add(new TrackerTask());
        if (tasks.Count > 3) tasks.RemoveRange(3, tasks.Count - 3);
        return new ObservableCollection<TrackerTask>(tasks);
    }

    public void SaveTasks(DateTime date, IEnumerable<TrackerTask> tasks)
    {
        State.DailyTasksByDate[date.ToString("yyyy-MM-dd")] = tasks.Take(3).ToList();
        Save();
    }

    public void Save()
    {
        Directory.CreateDirectory(_folder);
        var temporary = _statePath + ".tmp";
        File.WriteAllText(temporary, JsonSerializer.Serialize(State, _options));
        File.Move(temporary, _statePath, true);
    }

    public void OpenFolder()
    {
        Save();
        Directory.CreateDirectory(_folder);
        Process.Start(new ProcessStartInfo("explorer.exe", _folder) { UseShellExecute = true });
    }

    private TrackerState Load()
    {
        try
        {
            if (File.Exists(_statePath))
            {
                return JsonSerializer.Deserialize<TrackerState>(File.ReadAllText(_statePath), _options)
                    ?? new TrackerState();
            }
        }
        catch
        {
            // A damaged optional Tracker file must not prevent the companion from starting.
        }
        return new TrackerState();
    }
}
