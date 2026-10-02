using CharacterEfficiencyIsland.Windows.Core;
using Windows.ApplicationModel.Appointments;

namespace CharacterEfficiencyIsland.Windows.Services;

internal sealed class WindowsCalendarReader
{
    private AppointmentStore? _store;
    private readonly List<AppointmentCalendar> _calendars = new();

    public IReadOnlyList<CalendarChoice> AvailableCalendars => _calendars
        .Select(calendar => new CalendarChoice(calendar.LocalId, calendar.DisplayName, "Windows 日历"))
        .ToList();

    public bool CanRead => _store is not null;
    public string StatusText { get; private set; } = "尚未读取 Windows 日历";

    public async Task<bool> RequestAccessAsync()
    {
        try
        {
            _store = await AppointmentManager.RequestStoreAsync(
                AppointmentStoreAccessType.AllCalendarsReadOnly);
            _calendars.Clear();
            if (_store is null)
            {
                StatusText = "Windows 没有授予日历只读访问；Tracker 的本地计划仍可使用";
                return false;
            }

            var calendars = await _store.FindAppointmentCalendarsAsync();
            _calendars.AddRange(calendars);
            StatusText = _calendars.Count == 0
                ? "已取得只读权限，但没有找到可读取的 Windows 日历"
                : $"Windows 日历只读 · {_calendars.Count} 个日历";
            return true;
        }
        catch (Exception error)
        {
            _store = null;
            _calendars.Clear();
            StatusText = $"此 Windows 环境暂时无法读取系统日历（{error.GetType().Name}）；本地计划不受影响";
            return false;
        }
    }

    public async Task<IReadOnlyList<TrackerCalendarItem>> ReadAsync(
        DateTime start,
        DateTime end,
        IReadOnlyCollection<string>? selectedCalendarIds)
    {
        if (_store is null || end <= start) return Array.Empty<TrackerCalendarItem>();

        var allowed = selectedCalendarIds is null ? null : new HashSet<string>(selectedCalendarIds);
        var result = new List<TrackerCalendarItem>();
        foreach (var calendar in _calendars)
        {
            if (allowed is not null && !allowed.Contains(calendar.LocalId)) continue;
            try
            {
                var appointments = await calendar.FindAppointmentsAsync(
                    new DateTimeOffset(start),
                    end - start);
                result.AddRange(appointments.Select(item => new TrackerCalendarItem(
                    item.LocalId,
                    calendar.LocalId,
                    calendar.DisplayName,
                    string.IsNullOrWhiteSpace(item.Subject) ? "（无标题）" : item.Subject,
                    item.StartTime.LocalDateTime,
                    item.StartTime.LocalDateTime + item.Duration,
                    item.AllDay)));
            }
            catch
            {
                // One inaccessible calendar should not hide the remaining readable calendars.
            }
        }

        return result.OrderBy(item => item.Start).ToList();
    }
}
