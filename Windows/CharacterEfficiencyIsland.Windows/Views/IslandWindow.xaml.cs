using System.Windows;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Text;
using CharacterEfficiencyIsland.Windows.Core;
using CharacterEfficiencyIsland.Windows.Interop;
using Drawing = System.Drawing;
using Forms = System.Windows.Forms;

namespace CharacterEfficiencyIsland.Windows.Views;

internal partial class IslandWindow : Window, ICharacterSurface
{
    private const double HorizontalWidth = 620;
    private const double HorizontalHeight = 160;
    private const double VerticalWidth = 170;
    private const double VerticalHeight = 560;

    private readonly AppState _state;
    private double _workingScale;
    private DockEdge _dockEdge;
    private Forms.Screen _screen;

    public IslandWindow(AppState state)
    {
        _state = state;
        _workingScale = state.Settings.SurfaceScale;
        _dockEdge = state.Settings.DockEdge;
        _screen = ScreenGeometry.FindScreen(state.Settings.DockScreenDevice);
        InitializeComponent();
        SourceInitialized += (_, _) => DockToSavedPosition();
        Closed += (_, _) => Microsoft.Win32.SystemEvents.DisplaySettingsChanged -= DisplaySettingsChanged;
        Microsoft.Win32.SystemEvents.DisplaySettingsChanged += DisplaySettingsChanged;
        ApplyLayout();
        Refresh(state);
    }

    public void Refresh(AppState state)
    {
        var mode = state.DisplayMode;
        var image = AssetLoader.Image(AssetLoader.IslandAsset(mode));
        HorizontalImage.Source = image;
        VerticalImage.Source = image;
        HorizontalTitle.Text = state.DisplayTitle;
        HorizontalDetail.Text = state.DisplayDetail;
        VerticalTitle.Text = Verticalize(state.DisplayTitle);
        VerticalDetail.Text = state.DisplayDetail;

        var timer = mode == CharacterMode.BreakTime ? state.FormatSeconds(state.BreakRemaining) : "";
        HorizontalTimer.Text = timer;
        HorizontalTimer.Visibility = string.IsNullOrEmpty(timer) ? Visibility.Collapsed : Visibility.Visible;
        VerticalTimer.Text = timer;
        VerticalTimer.Visibility = string.IsNullOrEmpty(timer) ? Visibility.Collapsed : Visibility.Visible;

        if (state.Settings.ShowPersistentSurface)
        {
            ShowSurface();
        }
        else
        {
            HideSurface();
        }
    }

    public void ShowSurface()
    {
        if (!IsVisible)
        {
            Show();
            DockToSavedPosition();
        }
    }

    public void HideSurface()
    {
        if (IsVisible)
        {
            Hide();
        }
    }

    public void ResetScale()
    {
        _workingScale = 1.0;
        _state.SetSurfaceScale(_workingScale);
        ApplyLayout();
        DockToSavedPosition();
    }

    private void IslandBody_OnMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount == 2)
        {
            if (_state.IsOnBreak)
            {
                _state.ToggleBreakPause();
            }
            return;
        }

        try
        {
            DragMove();
            DockAfterDrag();
        }
        catch
        {
            // DragMove can throw if the mouse button is released before capture.
        }
    }

    private void IslandBody_OnMouseEnter(object sender, MouseEventArgs e)
    {
        if (!_state.IsOnBreak)
        {
            Opacity = 0.08;
        }
    }

    private void IslandBody_OnMouseLeave(object sender, MouseEventArgs e) => Opacity = 1.0;

    private void ResizeThumb_OnDragStarted(object sender, DragStartedEventArgs e)
    {
        Opacity = 1.0;
        _workingScale = _state.Settings.SurfaceScale;
    }

    private void ResizeThumb_OnDragDelta(object sender, DragDeltaEventArgs e)
    {
        var basis = _dockEdge == DockEdge.Top ? HorizontalWidth : VerticalHeight;
        _workingScale = Math.Clamp(_workingScale + (e.HorizontalChange + e.VerticalChange) / basis, 0.75, 1.60);
        ApplyLayout();
        DockToSavedPosition();
    }

    private void ResizeThumb_OnDragCompleted(object sender, DragCompletedEventArgs e)
    {
        _state.SetSurfaceScale(_workingScale);
        DockToSavedPosition();
    }

    private void DockAfterDrag()
    {
        var cursor = Forms.Cursor.Position;
        _screen = ScreenGeometry.FromPoint(cursor);
        var area = _screen.WorkingArea;
        var topDistance = Math.Abs(cursor.Y - area.Top);
        var leftDistance = Math.Abs(cursor.X - area.Left);
        var rightDistance = Math.Abs(area.Right - cursor.X);

        if (topDistance <= leftDistance && topDistance <= rightDistance)
        {
            _dockEdge = DockEdge.Top;
        }
        else
        {
            _dockEdge = leftDistance <= rightDistance ? DockEdge.Left : DockEdge.Right;
            ApplyLayout();
            var height = ScreenGeometry.WindowPixelHeight(this, _screen);
            var available = Math.Max(1, area.Height - height);
            _state.Settings.SideOffsetRatio = Math.Clamp((cursor.Y - area.Top - height / 2) / available, 0, 1);
        }

        _state.Settings.DockEdge = _dockEdge;
        _state.Settings.DockScreenDevice = _screen.DeviceName;
        ApplyLayout();
        DockToSavedPosition();
        _state.SaveAll();
    }

    private void ApplyLayout()
    {
        var vertical = _dockEdge is DockEdge.Left or DockEdge.Right;
        HorizontalLayout.Visibility = vertical ? Visibility.Collapsed : Visibility.Visible;
        VerticalLayout.Visibility = vertical ? Visibility.Visible : Visibility.Collapsed;
        Width = (vertical ? VerticalWidth : HorizontalWidth) * _workingScale;
        Height = (vertical ? VerticalHeight : HorizontalHeight) * _workingScale;
        IslandBody.CornerRadius = new CornerRadius(38 * _workingScale);
    }

    private void DockToSavedPosition()
    {
        if (!IsInitialized)
        {
            return;
        }
        _screen = ScreenGeometry.FindScreen(_state.Settings.DockScreenDevice ?? _screen.DeviceName);
        var area = _screen.WorkingArea;
        var width = ScreenGeometry.WindowPixelWidth(this, _screen);
        var height = ScreenGeometry.WindowPixelHeight(this, _screen);
        double x;
        double y;
        if (_dockEdge == DockEdge.Top)
        {
            x = area.Left + (area.Width - width) / 2;
            y = area.Top;
        }
        else
        {
            x = _dockEdge == DockEdge.Left ? area.Left : area.Right - width;
            y = area.Top + Math.Max(0, area.Height - height) * _state.Settings.SideOffsetRatio;
        }
        ScreenGeometry.SetPosition(this, x, y, _screen);
    }

    private void DisplaySettingsChanged(object? sender, EventArgs e) => Dispatcher.Invoke(DockToSavedPosition);

    private static string Verticalize(string value) => string.Join(Environment.NewLine, value.EnumerateRunes());
}
