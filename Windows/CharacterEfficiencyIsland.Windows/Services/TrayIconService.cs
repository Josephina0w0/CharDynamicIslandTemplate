using CharacterEfficiencyIsland.Windows.Core;
using Drawing = System.Drawing;
using Forms = System.Windows.Forms;

namespace CharacterEfficiencyIsland.Windows.Services;

internal sealed class TrayIconService : IDisposable
{
    private readonly Forms.NotifyIcon _notifyIcon;
    private readonly Drawing.Icon _icon;

    public TrayIconService(
        AppProfile profile,
        Action<Drawing.Point> togglePanel,
        Action? openTracker,
        Action quit)
    {
        _icon = AssetLoader.TrayIcon();
        _notifyIcon = new Forms.NotifyIcon
        {
            Icon = _icon,
            Text = profile.AppName.Length <= 63 ? profile.AppName : profile.AppName[..63],
            Visible = true
        };

        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("打开控制面板", null, (_, _) => togglePanel(Forms.Cursor.Position));
        if (openTracker is not null)
        {
            menu.Items.Add("打开 Tracker", null, (_, _) => openTracker());
        }
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("退出", null, (_, _) => quit());
        _notifyIcon.ContextMenuStrip = menu;
        _notifyIcon.MouseClick += (_, args) =>
        {
            if (args.Button == Forms.MouseButtons.Left)
            {
                togglePanel(Forms.Cursor.Position);
            }
        };
        _notifyIcon.DoubleClick += (_, _) => togglePanel(Forms.Cursor.Position);
    }

    public void Notify(string title, string detail)
    {
        _notifyIcon.BalloonTipTitle = title;
        _notifyIcon.BalloonTipText = detail;
        _notifyIcon.ShowBalloonTip(3500);
    }

    public void Dispose()
    {
        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
        _icon.Dispose();
    }
}
