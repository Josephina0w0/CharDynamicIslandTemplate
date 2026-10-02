using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Controls;
using CharacterEfficiencyIsland.Windows.Core;

namespace CharacterEfficiencyIsland.Windows.Views;

public partial class ProjectPipelineWindow : Window
{
    private readonly TrackerStore _store;
    private readonly ObservableCollection<TrackerProject> _projects;

    internal ProjectPipelineWindow(TrackerStore store)
    {
        _store = store;
        _projects = new ObservableCollection<TrackerProject>(_store.State.Projects);
        InitializeComponent();
        ProjectsGrid.ItemsSource = _projects;
        FocusActionEditor.Text = _store.State.FocusNextAction;
    }

    public void ShowProjects(Window owner)
    {
        Owner = owner;
        if (!IsVisible) Show();
        Activate();
    }

    private void AddProject_OnClick(object sender, RoutedEventArgs e)
    {
        var project = new TrackerProject();
        _projects.Add(project);
        ProjectsGrid.SelectedItem = project;
        Save();
    }

    private void DeleteProjects_OnClick(object sender, RoutedEventArgs e)
    {
        foreach (var item in ProjectsGrid.SelectedItems.OfType<TrackerProject>().ToList())
        {
            _projects.Remove(item);
        }
        Save();
    }

    private void ProjectsGrid_OnCellEditEnding(object sender, DataGridCellEditEndingEventArgs e) =>
        Dispatcher.BeginInvoke(Save);

    private void Focus_OnChanged(object sender, RoutedEventArgs e) => Save();

    private void Save()
    {
        _store.State.Projects = _projects.ToList();
        _store.State.FocusNextAction = FocusActionEditor.Text;
        _store.Save();
    }

    private void Done_OnClick(object sender, RoutedEventArgs e)
    {
        Save();
        Close();
    }
}
