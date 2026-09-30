using System.Windows;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media;
using CharacterEfficiencyIsland.Windows.Core;
using CharacterEfficiencyIsland.Windows.Interop;
using Microsoft.Win32;
using Drawing = System.Drawing;
using Forms = System.Windows.Forms;

namespace CharacterEfficiencyIsland.Windows.Views;

public partial class CompanionWindow : Window, ICharacterSurface
{
    private const double BaseWidth = 234;
    private const double DesignReduction = 0.9;
    private const double BaseImageWidth = 188 * DesignReduction;
    private const double FooterMargin = 8 * DesignReduction;
    private const double FooterHeight = 34 * DesignReduction;
    private const double ImageFooterGap = 4 * DesignReduction;
    private const double TopMargin = 8 * DesignReduction;
    private const double BaseImageHeight = 270 - FooterMargin - FooterHeight - ImageFooterGap - TopMargin;
    private const double ImageHorizontalAllowance = 30 * DesignReduction;

    private readonly AppState _state;
    private readonly Action _openPanel;
    private double _workingScale;
    private bool _scaleLayoutInitialized;

    public CompanionWindow(AppState state, Action openPanel)
    {
        _state = state;
        _openPanel = openPanel;
        _workingScale = state.Settings.SurfaceScale;
        InitializeComponent();
        ApplyScale();
        _scaleLayoutInitialized = true;
        UpdateMetricsTextColor();
        SourceInitialized += (_, _) => RestorePosition();
        SystemEvents.UserPreferenceChanged += UserPreferenceChanged;
        Closed += (_, _) => SystemEvents.UserPreferenceChanged -= UserPreferenceChanged;
        Refresh(state);
    }

    public void Refresh(AppState state)
    {
        CharacterImage.Source = AssetLoader.Image(
            state.Profile.IslandAsset(state.DisplayMode),
            cropLeft: state.Profile.CompanionLeftCrop(state.DisplayMode),
            cropTop: state.Profile.CompanionTopCrop(state.DisplayMode),
            cropRight: state.Profile.CompanionRightCrop(state.DisplayMode),
            cropBottom: state.Profile.CompanionBottomCrop(state.DisplayMode));
        var epm = state.CurrentApm == 0 ? "--" : state.CurrentEpm.ToString("00");
        var statusText = state.Mode == CharacterMode.BreakTime
            ? state.Profile.CompanionBreakStatusText
            : state.Profile.CompanionStatusText;
        MetricsLabel.Text = $"{statusText} {state.FormatSeconds(state.WorkSeconds)} · EPM {epm}";
        MetricsLabel.ToolTip = MetricsLabel.Text;
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
            RestorePosition();
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
        _workingScale = 1;
        _state.SetSurfaceScale(1);
        ApplyScale();
        ClampAndSavePosition();
    }

    private void Root_OnMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount == 2)
        {
            _openPanel();
            return;
        }
        try
        {
            DragMove();
            ClampAndSavePosition();
        }
        catch
        {
            // DragMove can throw if mouse capture is lost.
        }
    }

    private void ResizeThumb_OnDragStarted(object sender, DragStartedEventArgs e) =>
        _workingScale = _state.Settings.SurfaceScale;

    private void ResizeThumb_OnDragDelta(object sender, DragDeltaEventArgs e)
    {
        var edge = (sender as FrameworkElement)?.Tag?.ToString() ?? "";
        var change = edge switch
        {
            "Left" => -e.HorizontalChange / BaseImageWidth,
            "Right" => e.HorizontalChange / BaseImageWidth,
            "Top" => -e.VerticalChange / BaseImageHeight,
            "Bottom" => e.VerticalChange / BaseImageHeight,
            _ => 0
        };
        _workingScale = Math.Clamp(_workingScale + change, 0.75, 1.60);
        ApplyScale();
    }

    private void ResizeThumb_OnDragCompleted(object sender, DragCompletedEventArgs e)
    {
        _state.SetSurfaceScale(_workingScale);
        ClampAndSavePosition();
    }

    private void ApplyScale()
    {
        var oldWidth = Width;
        var oldHeight = Height;
        var imageWidth = BaseImageWidth * _workingScale;
        var imageHeight = BaseImageHeight * _workingScale;
        CharacterResizeSurface.Width = imageWidth;
        CharacterResizeSurface.Height = imageHeight;
        CharacterImage.Width = imageWidth;
        CharacterImage.Height = double.NaN;
        CharacterImage.MaxHeight = imageHeight;
        Width = Math.Max(BaseWidth, imageWidth + ImageHorizontalAllowance);
        Height = FooterMargin + FooterHeight + ImageFooterGap + imageHeight + TopMargin;
        if (_scaleLayoutInitialized && IsLoaded)
        {
            Left += (oldWidth - Width) / 2;
            Top += oldHeight - Height;
        }
    }

    private void UserPreferenceChanged(object sender, UserPreferenceChangedEventArgs e) =>
        Dispatcher.Invoke(UpdateMetricsTextColor);

    private void UpdateMetricsTextColor() =>
        MetricsLabel.Foreground = IsDarkAppTheme()
            ? System.Windows.Media.Brushes.Black
            : System.Windows.Media.Brushes.White;

    private static bool IsDarkAppTheme()
    {
        using var key = Registry.CurrentUser.OpenSubKey(
            @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
        return key?.GetValue("AppsUseLightTheme") is int appsUseLightTheme && appsUseLightTheme == 0;
    }

    private void RestorePosition()
    {
        var cursor = Forms.Cursor.Position;
        var screen = ScreenGeometry.FromPoint(cursor);
        var area = screen.WorkingArea;
        var width = ScreenGeometry.WindowPixelWidth(this, screen);
        var height = ScreenGeometry.WindowPixelHeight(this, screen);
        var x = _state.Settings.CompanionLeft ?? area.Right - width - 28;
        var y = _state.Settings.CompanionTop ?? area.Bottom - height - 24;
        x = Math.Clamp(x, area.Left, Math.Max(area.Left, area.Right - width));
        y = Math.Clamp(y, area.Top, Math.Max(area.Top, area.Bottom - height));
        ScreenGeometry.SetPosition(this, x, y, screen);
    }

    private void ClampAndSavePosition()
    {
        var topLeft = PointToScreen(new System.Windows.Point(0, 0));
        var point = new Drawing.Point((int)topLeft.X, (int)topLeft.Y);
        var screen = ScreenGeometry.FromPoint(point);
        var area = screen.WorkingArea;
        var width = ScreenGeometry.WindowPixelWidth(this, screen);
        var height = ScreenGeometry.WindowPixelHeight(this, screen);
        var x = Math.Clamp(topLeft.X, area.Left, Math.Max(area.Left, area.Right - width));
        var y = Math.Clamp(topLeft.Y, area.Top, Math.Max(area.Top, area.Bottom - height));
        ScreenGeometry.SetPosition(this, x, y, screen);
        _state.Settings.CompanionLeft = x;
        _state.Settings.CompanionTop = y;
        _state.SaveAll();
    }
}
