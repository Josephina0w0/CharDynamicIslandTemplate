import SwiftData
import SwiftUI

struct TrackerPhaseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrackerProject.updatedAt, order: .reverse) private var projects: [TrackerProject]
    @Query(sort: \DailyFocusItem.slot) private var focusItems: [DailyFocusItem]
    @StateObject private var systemReader = TrackerSystemReader()
    @State private var searchText = ""
    @State private var filter: TrackerProjectFilter = .all
    @State private var sort: TrackerProjectSort = .updated
    @State private var editorTarget: ProjectEditorTarget?
    @State private var pendingDeletion: TrackerProject?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    DailyTopThreeCard(items: todaysFocusItems)
                    projectSection
                    SystemScheduleSection(reader: systemReader)
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 12)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tracker")
            .searchable(text: $searchText, prompt: "搜索项目、下一步或备注")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorTarget = ProjectEditorTarget(project: nil)
                    } label: {
                        Label("新增项目", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editorTarget) { target in
                ProjectEditorView(project: target.project) { draft in
                    saveProject(draft, editing: target.project)
                }
            }
            .confirmationDialog(
                "删除这个项目？",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("删除项目", role: .destructive) {
                    if let pendingDeletion {
                        modelContext.delete(pendingDeletion)
                        try? modelContext.save()
                    }
                    pendingDeletion = nil
                }
                Button("取消", role: .cancel) { pendingDeletion = nil }
            } message: {
                Text("项目和它的历史记录会从本机删除，此操作不会影响系统日历或提醒事项。")
            }
            .onAppear(perform: ensureDailyTopThree)
            .task { await systemReader.reload() }
        }
    }

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("项目", systemImage: "square.stack.3d.up")
                    .font(.headline)
                Spacer()
                Text("\(filteredProjects.count) 项")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Menu {
                    Picker("筛选", selection: $filter) {
                        ForEach(TrackerProjectFilter.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                } label: {
                    Label(filter.rawValue, systemImage: "line.3.horizontal.decrease.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Menu {
                    Picker("排序", selection: $sort) {
                        ForEach(TrackerProjectSort.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                } label: {
                    Label(sort.rawValue, systemImage: "arrow.up.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if filteredProjects.isEmpty {
                ContentUnavailableView {
                    Label(searchText.isEmpty ? "还没有符合条件的项目" : "没有搜索结果", systemImage: "folder")
                } description: {
                    Text(searchText.isEmpty ? "点击右上角加号建立第一个项目。" : "换一个关键词或筛选条件试试。")
                } actions: {
                    if searchText.isEmpty {
                        Button("新增项目") { editorTarget = ProjectEditorTarget(project: nil) }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            } else {
                ForEach(filteredProjects) { project in
                    ProjectCard(
                        project: project,
                        edit: { editorTarget = ProjectEditorTarget(project: project) },
                        complete: { setStatus(.completed, for: project) },
                        reactivate: { setStatus(.active, for: project) },
                        archive: { setStatus(.archived, for: project) },
                        delete: { pendingDeletion = project }
                    )
                }
            }
        }
        .trackerCard()
    }

    private var todaysFocusItems: [DailyFocusItem] {
        let key = TrackerDateKey.make(for: Date())
        return focusItems.filter { $0.dayKey == key }.sorted { $0.slot < $1.slot }
    }

    private var filteredProjects: [TrackerProject] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = projects.filter { project in
            let statusMatches: Bool
            switch filter {
            case .all: statusMatches = true
            case .active: statusMatches = project.status == .active
            case .completed: statusMatches = project.status == .completed
            case .archived: statusMatches = project.status == .archived
            }
            guard statusMatches else { return false }
            guard !query.isEmpty else { return true }
            return [project.name, project.nextAction, project.notes, project.stage.rawValue]
                .joined(separator: " ")
                .lowercased()
                .contains(query)
        }

        return filtered.sorted { lhs, rhs in
            switch sort {
            case .updated:
                return lhs.updatedAt > rhs.updatedAt
            case .deadline:
                return compareOptionalDates(lhs.deadline, rhs.deadline, fallback: lhs.name < rhs.name)
            case .followUp:
                return compareOptionalDates(lhs.followUpDate, rhs.followUpDate, fallback: lhs.name < rhs.name)
            case .name:
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private func compareOptionalDates(_ lhs: Date?, _ rhs: Date?, fallback: Bool) -> Bool {
        switch (lhs, rhs) {
        case let (left?, right?): return left == right ? fallback : left < right
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return fallback
        }
    }

    private func ensureDailyTopThree() {
        let key = TrackerDateKey.make(for: Date())
        let existingSlots = Set(focusItems.filter { $0.dayKey == key }.map(\.slot))
        let defaults = ["今天最重要的一件事", "需要推进的一次协作", "一个清晰的下一步"]
        for slot in 0..<3 where !existingSlots.contains(slot) {
            modelContext.insert(DailyFocusItem(dayKey: key, slot: slot, text: defaults[slot]))
        }
        try? modelContext.save()
    }

    private func saveProject(_ draft: ProjectDraft, editing project: TrackerProject?) {
        let now = Date()
        if let project {
            let changes = draft.changeSummary(comparedWith: project)
            project.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            project.stage = draft.stage
            project.status = draft.status
            project.deadline = draft.hasDeadline ? draft.deadline : nil
            project.nextAction = draft.nextAction.trimmingCharacters(in: .whitespacesAndNewlines)
            project.followUpDate = draft.hasFollowUp ? draft.followUpDate : nil
            project.notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            project.updatedAt = now
            project.history.append(TrackerHistoryEntry(date: now, title: "更新项目", detail: changes))
        } else {
            let newProject = TrackerProject(
                name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                stage: draft.stage,
                status: draft.status,
                deadline: draft.hasDeadline ? draft.deadline : nil,
                nextAction: draft.nextAction.trimmingCharacters(in: .whitespacesAndNewlines),
                followUpDate: draft.hasFollowUp ? draft.followUpDate : nil,
                notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
                history: [TrackerHistoryEntry(date: now, title: "创建项目")]
            )
            modelContext.insert(newProject)
        }
        try? modelContext.save()
    }

    private func setStatus(_ status: TrackerProjectStatus, for project: TrackerProject) {
        guard project.status != status else { return }
        let oldStatus = project.status
        project.status = status
        project.updatedAt = Date()
        if status == .completed { project.stage = .done }
        project.history.append(TrackerHistoryEntry(
            title: "状态变更",
            detail: "\(oldStatus.rawValue) → \(status.rawValue)"
        ))
        try? modelContext.save()
    }
}

private struct DailyTopThreeCard: View {
    let items: [DailyFocusItem]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Label("Daily Top 3", systemImage: "target")
                    .font(.headline)
                if items.isEmpty {
                    Spacer()
                    ProgressView().frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    Spacer(minLength: 8)
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        DailyFocusRow(item: item)
                        if index < items.count - 1 {
                            Spacer(minLength: 4)
                        }
                    }
                }
            }
            .frame(height: 158)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(CompanionProfile.current.trackerImage)
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 158)
                .accessibilityHidden(true)
        }
        .trackerCard()
    }
}

private struct DailyFocusRow: View {
    @Bindable var item: DailyFocusItem
    @FocusState private var isEditing: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button {
                item.isDone.toggle()
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "标记为未完成" : "标记为已完成")

            ZStack(alignment: .leading) {
                TextField("写下今天的重点", text: $item.text)
                    .textFieldStyle(.plain)
                    .focused($isEditing)
                    .submitLabel(.done)
                    .opacity(isEditing ? 1 : 0)
                    .allowsHitTesting(isEditing)
                    .onSubmit { isEditing = false }

                if !isEditing {
                    Text(item.text.isEmpty ? "写下今天的重点" : item.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(item.text.isEmpty ? .tertiary : (item.isDone ? .secondary : .primary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { isEditing = true }
            .strikethrough(item.isDone)
            .foregroundStyle(item.isDone ? .secondary : .primary)
        }
        .padding(.vertical, 5)
    }
}

private struct ProjectCard: View {
    let project: TrackerProject
    let edit: () -> Void
    let complete: () -> Void
    let reactivate: () -> Void
    let archive: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.name)
                        .font(.headline)
                        .lineLimit(2)
                    Text("\(project.stage.rawValue) · \(project.status.rawValue)")
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
                Spacer()
                Menu {
                    Button("编辑", systemImage: "pencil", action: edit)
                    if project.status == .completed {
                        Button("重新开始", systemImage: "arrow.counterclockwise", action: reactivate)
                    } else {
                        Button("标记完成", systemImage: "checkmark", action: complete)
                    }
                    Button("归档", systemImage: "archivebox", action: archive)
                    Divider()
                    Button("删除", systemImage: "trash", role: .destructive, action: delete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .accessibilityLabel("项目操作")
            }

            if !project.nextAction.isEmpty {
                Label(project.nextAction, systemImage: "arrow.forward.circle")
                    .font(.subheadline)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                if let deadline = project.deadline {
                    Label(deadline.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar.badge.exclamationmark")
                }
                if let followUp = project.followUpDate {
                    Label(followUp.formatted(date: .abbreviated, time: .omitted), systemImage: "bell")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: edit)
        .accessibilityElement(children: .combine)
        .accessibilityHint("轻点编辑项目")
    }

    private var statusColor: Color {
        switch project.status {
        case .active: return Color(hex: CompanionProfile.current.palette.primaryHex)
        case .completed: return .green
        case .archived: return .secondary
        }
    }
}

private struct ProjectEditorTarget: Identifiable {
    let id = UUID()
    var project: TrackerProject?
}

private struct ProjectDraft {
    var name: String
    var stage: TrackerProjectStage
    var status: TrackerProjectStatus
    var hasDeadline: Bool
    var deadline: Date
    var nextAction: String
    var hasFollowUp: Bool
    var followUpDate: Date
    var notes: String

    init(project: TrackerProject?) {
        name = project?.name ?? ""
        stage = project?.stage ?? .planning
        status = project?.status ?? .active
        hasDeadline = project?.deadline != nil
        deadline = project?.deadline ?? Date()
        nextAction = project?.nextAction ?? ""
        hasFollowUp = project?.followUpDate != nil
        followUpDate = project?.followUpDate ?? Date()
        notes = project?.notes ?? ""
    }

    func changeSummary(comparedWith project: TrackerProject) -> String {
        var parts: [String] = []
        if name != project.name { parts.append("名称") }
        if stage != project.stage { parts.append("阶段") }
        if status != project.status { parts.append("状态") }
        if (hasDeadline ? deadline : nil) != project.deadline { parts.append("截止日期") }
        if nextAction != project.nextAction { parts.append("下一步") }
        if (hasFollowUp ? followUpDate : nil) != project.followUpDate { parts.append("跟进日期") }
        if notes != project.notes { parts.append("备注") }
        return parts.isEmpty ? "保存但没有字段变化" : "修改：" + parts.joined(separator: "、")
    }
}

private struct ProjectEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let project: TrackerProject?
    let save: (ProjectDraft) -> Void
    @State private var draft: ProjectDraft

    init(project: TrackerProject?, save: @escaping (ProjectDraft) -> Void) {
        self.project = project
        self.save = save
        _draft = State(initialValue: ProjectDraft(project: project))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("项目名称", text: $draft.name)
                    Picker("项目阶段", selection: $draft.stage) {
                        ForEach(TrackerProjectStage.allCases) { stage in
                            Text(stage.rawValue).tag(stage)
                        }
                    }
                    Picker("状态", selection: $draft.status) {
                        ForEach(TrackerProjectStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                }

                Section("行动与日期") {
                    TextField("下一步行动", text: $draft.nextAction, axis: .vertical)
                        .lineLimit(2...4)
                    Toggle("设置截止日期", isOn: $draft.hasDeadline)
                    if draft.hasDeadline {
                        DatePicker("截止日期", selection: $draft.deadline, displayedComponents: .date)
                    }
                    Toggle("设置跟进日期", isOn: $draft.hasFollowUp)
                    if draft.hasFollowUp {
                        DatePicker("跟进日期", selection: $draft.followUpDate, displayedComponents: .date)
                    }
                }

                Section("备注") {
                    TextField("补充信息、协作者或风险", text: $draft.notes, axis: .vertical)
                        .lineLimit(4...8)
                }

                if let project, !project.history.isEmpty {
                    Section("项目历史") {
                        ForEach(project.history.sorted { $0.date > $1.date }) { entry in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.title).font(.subheadline.weight(.semibold))
                                if !entry.detail.isEmpty {
                                    Text(entry.detail).font(.caption).foregroundStyle(.secondary)
                                }
                                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(project == nil ? "新增项目" : "编辑项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text("取消").frame(minWidth: 52)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save(draft)
                        dismiss()
                    } label: {
                        Text("保存").frame(minWidth: 52)
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct SystemScheduleSection: View {
    @ObservedObject var reader: TrackerSystemReader
    @State private var isSelectingLists = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("系统日历与提醒事项", systemImage: "calendar.badge.clock")
                    .font(.headline)
                Spacer()
                HStack(spacing: 6) {
                    accessBadge("只读")
                    Button {
                        isSelectingLists = true
                    } label: {
                        accessBadge("选择")
                    }
                    .buttonStyle(.plain)
                    .disabled(!reader.canReadCalendars && !reader.canReadReminders)
                }
            }

            if reader.calendarAuthorization == .notDetermined || reader.reminderAuthorization == .notDetermined {
                Text("系统要求完全访问，但本 App 只读取并展示，不会创建、修改或删除任何系统内容。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Label(reader.permissionSummary, systemImage: permissionSymbol)
                .font(.subheadline)

            if reader.calendarAuthorization == .notDetermined || reader.reminderAuthorization == .notDetermined {
                Button("允许只读展示") {
                    Task { await reader.requestReadAccess() }
                }
                .buttonStyle(.borderedProminent)
            } else if reader.hasAnyDeniedAccess {
                Button("打开系统设置", action: reader.openSystemSettings)
                    .buttonStyle(.bordered)
            }

            if reader.isLoading {
                ProgressView("正在读取系统内容")
                    .frame(maxWidth: .infinity)
            } else {
                if reader.canReadCalendars {
                    systemEvents
                }
                if reader.canReadReminders {
                    systemReminders
                }
            }

            if let error = reader.lastError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
        .trackerCard()
        .sheet(isPresented: $isSelectingLists) {
            SystemListSelectionView(reader: reader)
        }
    }

    private func accessBadge(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.14), in: Capsule())
            .foregroundStyle(.blue)
    }

    private var systemEvents: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("未来 14 天日程", systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
            if reader.calendarItems.isEmpty {
                Text("没有读取到未来日程。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(reader.calendarItems.prefix(8)) { item in
                    SystemItemRow(
                        symbol: "calendar",
                        color: .blue,
                        title: item.title,
                        detail: calendarDetail(item)
                    )
                }
            }
        }
    }

    private var systemReminders: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("未完成提醒事项", systemImage: "checklist")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            if reader.reminderItems.isEmpty {
                Text("没有读取到未完成提醒事项。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(reader.reminderItems.prefix(8)) { item in
                    SystemItemRow(
                        symbol: "circle",
                        color: .orange,
                        title: item.title,
                        detail: reminderDetail(item)
                    )
                }
            }
        }
    }

    private var permissionSymbol: String {
        if reader.canReadCalendars && reader.canReadReminders { return "checkmark.shield" }
        if reader.hasAnyDeniedAccess { return "exclamationmark.shield" }
        return "lock.shield"
    }

    private func calendarDetail(_ item: SystemCalendarItem) -> String {
        let time = item.isAllDay
            ? item.startDate.formatted(date: .abbreviated, time: .omitted) + " · 全天"
            : item.startDate.formatted(date: .abbreviated, time: .shortened)
        return "\(time) · \(item.calendarName)"
    }

    private func reminderDetail(_ item: SystemReminderItem) -> String {
        let due = item.dueDate?.formatted(date: .abbreviated, time: .shortened) ?? "无截止时间"
        return "\(due) · \(item.listName)"
    }
}

private struct SystemListSelectionView: View {
    @ObservedObject var reader: TrackerSystemReader
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if reader.canReadCalendars {
                    Section("日历列表") {
                        if reader.calendarLists.isEmpty {
                            Text("没有可选择的日历列表").foregroundStyle(.secondary)
                        } else {
                            ForEach(reader.calendarLists) { list in
                                sourceToggle(list, isReminder: false)
                            }
                        }
                    }
                }

                if reader.canReadReminders {
                    Section("提醒事项列表") {
                        if reader.reminderLists.isEmpty {
                            Text("没有可选择的提醒事项列表").foregroundStyle(.secondary)
                        } else {
                            ForEach(reader.reminderLists) { list in
                                sourceToggle(list, isReminder: true)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择显示内容")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Text("完成").frame(minWidth: 52)
                    }
                }
            }
        }
    }

    private func sourceToggle(_ list: TrackerSystemListOption, isReminder: Bool) -> some View {
        Toggle(isOn: Binding(
            get: {
                isReminder
                    ? reader.isReminderListSelected(list.id)
                    : reader.isCalendarSelected(list.id)
            },
            set: { selected in
                Task {
                    if isReminder {
                        await reader.setReminderListSelected(list.id, selected: selected)
                    } else {
                        await reader.setCalendarSelected(list.id, selected: selected)
                    }
                }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(list.title)
                if !list.sourceTitle.isEmpty && list.sourceTitle != list.title {
                    Text(list.sourceTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct SystemItemRow: View {
    let symbol: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).lineLimit(2)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

private extension View {
    func trackerCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
