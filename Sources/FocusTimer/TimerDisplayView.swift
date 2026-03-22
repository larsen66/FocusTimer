import SwiftUI

struct TimerDisplayView: View {
    var engine: TimerEngine
    @ObservedObject var store: SessionStore

    @State private var focusSetupInProgress = false

    // Note → Task picker state
    @State private var allNotes: [NoteItem] = []
    @State private var noteTasks: [String] = []
    @State private var pendingNote: NoteItem? = nil   // note selected, now picking task
    @State private var isLoading = false
    @State private var showNotePicker = false
    @State private var showTaskPicker = false

    var body: some View {
        ZStack {
            meshBg

            VStack(spacing: 0) {
                taskRow
                    .padding(.top, 20)
                    .padding(.horizontal, 18)

                Spacer()

                timerRing
                    .frame(width: 164, height: 164)

                Spacer()

                controlRow
                    .padding(.horizontal, 18)

                focusModeToggle
                    .padding(.top, 10)

                statsBar
                    .padding(.top, 8)
                    .padding(.bottom, 20)
            }
        }
        // Step 1: pick a note
        .sheet(isPresented: $showNotePicker) {
            NotePickerView(notes: allNotes) { note in
                pendingNote = note
                showNotePicker = false
                Task { await loadTasks(from: note) }
            }
        }
        // Step 2: pick a task from that note
        .sheet(isPresented: $showTaskPicker) {
            TaskPickerView(
                note: pendingNote,
                tasks: noteTasks,
                sessionCount: store.sessions.count
            ) { task, isNew in
                if let note = pendingNote { engine.selectedNote = note }
                engine.currentTask = task
                showTaskPicker = false
                if isNew {
                    Task {
                        if let note = pendingNote {
                            await NotesIntegration.addTaskToNote(task, to: note)
                        }
                        engine.start()
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var meshBg: some View {
        ZStack {
            Color.ink
            RadialGradient(colors: [Color.meshOrange.opacity(0.20), .clear],
                           center: UnitPoint(x: 0.88, y: 0.08), startRadius: 0, endRadius: 190)
            RadialGradient(colors: [Color.meshOrangeDim.opacity(0.11), .clear],
                           center: UnitPoint(x: 0.12, y: 0.92), startRadius: 0, endRadius: 150)
        }
        .ignoresSafeArea()
    }

    private var taskRow: some View {
        HStack(spacing: 8) {
            TextField("WHAT ARE YOU WORKING ON?", text: Binding(
                get: { engine.currentTask },
                set: { engine.currentTask = $0 }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color.bright)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.inkMid)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.18), lineWidth: 0.5))
            )

            Button {
                Task { await openNotePicker() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView().scaleEffect(0.55)
                    } else {
                        Image(systemName: engine.selectedNote != nil ? "note.text.badge.plus" : "note.text")
                            .font(.system(size: 12))
                    }
                }
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(engine.selectedNote != nil ? Color.meshOrange.opacity(0.22) : Color.inkMid)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                            engine.selectedNote != nil ? Color.meshOrange.opacity(0.45) : Color(white: 0.18),
                            lineWidth: 0.5))
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(engine.selectedNote != nil ? Color.meshOrangeHi : Color.muted)
            .help("Pick task from Apple Notes")
        }
    }

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(Color(white: 0.13), lineWidth: 9)

            Circle()
                .trim(from: 0, to: engine.progress)
                .stroke(
                    engine.hasStarted
                        ? AnyShapeStyle(orangeGradient)
                        : AnyShapeStyle(Color(white: 0.18)),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: engine.progress)

            VStack(spacing: 5) {
                Text(engine.formattedTime)
                    .font(.system(size: 38, weight: .thin, design: .monospaced))
                    .foregroundStyle(Color.bright)

                if engine.hasStarted || engine.completedToday > 0 || engine.selectedNote != nil {
                    HStack(spacing: 5) {
                        if engine.hasStarted || engine.completedToday > 0 {
                            Text("S\(store.sessions.count + (engine.hasStarted ? 1 : 0))")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Capsule().fill(orangeGradient)
                                    .overlay(GrainOverlay(opacity: 0.08).clipShape(Capsule())))
                                .foregroundStyle(Color(white: 0.88))
                        }
                        if let note = engine.selectedNote {
                            Text(note.title)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(Color.meshOrangeHi.opacity(0.9))
                                .lineLimit(1)
                                .frame(maxWidth: 108)
                        }
                    }
                }
            }
        }
    }

    private var controlRow: some View {
        HStack(spacing: 10) {
            if engine.hasStarted {
                Button("STOP") { engine.stop() }
                    .buttonStyle(GhostBtn())
                Button(engine.isRunning ? "PAUSE" : "RESUME") {
                    engine.isRunning ? engine.pause() : engine.resume()
                }
                .buttonStyle(PrimaryBtn())
                .keyboardShortcut(.space, modifiers: [])
            } else {
                Button("START") { engine.start() }
                    .buttonStyle(PrimaryBtn(wide: true))
                    .keyboardShortcut(.space, modifiers: [])
            }
        }
    }

    private var focusModeToggle: some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { engine.focusModeEnabled },
                set: { newVal in
                    engine.focusModeEnabled = newVal
                    if newVal { Task { await triggerFocusSetupIfNeeded() } }
                }
            )) {
                HStack(spacing: 5) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 9))
                    Text("FOCUS MODE")
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(0.5)
                }
                .foregroundStyle(engine.focusModeEnabled ? Color.meshOrangeHi : Color.dim)
            }
            .toggleStyle(.checkbox)
            .tint(Color.meshOrange)
            .controlSize(.mini)

            if focusSetupInProgress {
                Text("→ Accept in Shortcuts")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.meshOrangeHi.opacity(0.65))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: focusSetupInProgress)
    }

    private func triggerFocusSetupIfNeeded() async {
        let ready = await Task.detached { FocusMode.shortcutsExist() }.value
        guard !ready else { return }
        focusSetupInProgress = true
        await Task.detached { FocusMode.setupShortcuts() }.value
        // Message stays until user actually accepts; auto-hide after 15s
        try? await Task.sleep(nanoseconds: 15_000_000_000)
        focusSetupInProgress = false
    }

    private var statsBar: some View {
        let stats = store.dailyStats()
        return HStack(spacing: 14) {
            Label("\(stats.totalSessions) DONE", systemImage: "checkmark")
            Label("\(stats.totalMinutes) MIN", systemImage: "clock")
        }
        .font(.system(size: 9, design: .monospaced))
        .foregroundStyle(Color.dim)
    }

    // MARK: - Note/Task loading

    private func openNotePicker() async {
        isLoading = true
        allNotes = await NotesIntegration.fetchAllNotes()
        isLoading = false
        showNotePicker = true
    }

    private func loadTasks(from note: NoteItem) async {
        isLoading = true
        noteTasks = await NotesIntegration.fetchNoteTasks(from: note)
        isLoading = false
        showTaskPicker = true
    }
}

// MARK: - Step 1: Note Picker (with Create New Note)

struct NotePickerView: View {
    let notes: [NoteItem]
    let onSelect: (NoteItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var showCreate = false
    @State private var newNoteTitle = ""
    @State private var isCreating = false
    @FocusState private var createFocused: Bool

    private var filtered: [NoteItem] {
        search.isEmpty ? notes : notes.filter {
            $0.title.localizedCaseInsensitiveContains(search) ||
            $0.folder.localizedCaseInsensitiveContains(search)
        }
    }

    private var grouped: [(folder: String, items: [NoteItem])] {
        Dictionary(grouping: filtered, by: \.folder)
            .sorted { $0.key < $1.key }
            .map { (folder: $0.key, items: $0.value) }
    }

    var body: some View {
        VStack(spacing: 0) {
            PickerHeader(title: "SELECT NOTE") { dismiss() }

            // Create new note row
            createRow

            Divider().background(Color(white: 0.18))

            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.dim)
                TextField("SEARCH...", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.bright)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color(white: 0.12))
            .padding(.horizontal, 12).padding(.vertical, 5)

            Divider().background(Color(white: 0.18))

            if filtered.isEmpty {
                EmptyPickerState(
                    icon: "note.text",
                    title: notes.isEmpty ? "No Notes Found" : "No Results",
                    subtitle: notes.isEmpty ? "Grant Notes access when prompted" : "Try a different search"
                )
            } else {
                List {
                    ForEach(grouped, id: \.folder) { group in
                        Section {
                            ForEach(group.items) { note in
                                Button { onSelect(note) } label: {
                                    Text(note.title)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Color.bright)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 3)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text(group.folder.uppercased())
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.dim)
                                .tracking(1.2)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(width: 280, height: 380)
        .background(Color(white: 0.09))
        .preferredColorScheme(.dark)
    }

    // Inline "create new note" panel
    private var createRow: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showCreate.toggle() }
                if showCreate { createFocused = true }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: showCreate ? "minus" : "plus")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(showCreate ? AnyShapeStyle(Color.inkLight) : AnyShapeStyle(orangeGradient)))
                        .foregroundStyle(showCreate ? Color.dim : Color(white: 0.85))
                    Text("NEW NOTE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(showCreate ? Color.dim : Color.meshOrangeHi)
                        .tracking(0.5)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)

            if showCreate {
                HStack(spacing: 8) {
                    TextField("Note title...", text: $newNoteTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.bright)
                        .focused($createFocused)
                        .onSubmit { Task { await createNote() } }

                    Button {
                        Task { await createNote() }
                    } label: {
                        Group {
                            if isCreating {
                                ProgressView().scaleEffect(0.55)
                            } else {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                        }
                        .frame(width: 24, height: 24)
                        .background(
                            Circle().fill(newNoteTitle.isEmpty ? AnyShapeStyle(Color.inkLight) : AnyShapeStyle(orangeGradient))
                        )
                        .foregroundStyle(Color(white: 0.85))
                    }
                    .buttonStyle(.plain)
                    .disabled(newNoteTitle.isEmpty || isCreating)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider().background(Color(white: 0.18))
        }
    }

    private func createNote() async {
        let title = newNoteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        isCreating = true
        if let note = await NotesIntegration.createNote(title: title) {
            onSelect(note)
        }
        isCreating = false
    }
}

// MARK: - Step 2: Task Picker

struct TaskPickerView: View {
    let note: NoteItem?
    let tasks: [String]
    let sessionCount: Int
    let onSelect: (String, Bool) -> Void   // (task, isNew)
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @FocusState private var searchFocused: Bool

    private var filtered: [String] {
        search.isEmpty ? tasks : tasks.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    private var showAddRow: Bool {
        let t = search.trimmingCharacters(in: .whitespaces)
        guard t.count > 1 else { return false }
        return !tasks.contains { $0.lowercased() == t.lowercased() }
    }

    var body: some View {
        VStack(spacing: 0) {
            PickerHeader(title: note.map { "/ \($0.title)" } ?? "TASKS") { dismiss() }

            // Search doubles as new-task input
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.dim)
                TextField("SEARCH OR TYPE NEW TASK...", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.bright)
                    .focused($searchFocused)
                    .onSubmit {
                        let t = search.trimmingCharacters(in: .whitespaces)
                        guard !t.isEmpty else { return }
                        onSelect(t, !tasks.contains { $0.lowercased() == t.lowercased() })
                    }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color(white: 0.12))
            .padding(.horizontal, 12).padding(.top, 5).padding(.bottom, 2)

            // "Add + start" action row
            if showAddRow {
                let trimmed = search.trimmingCharacters(in: .whitespaces)
                Button { onSelect(trimmed, true) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.meshOrangeHi)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("ADD TO NOTE + START TIMER")
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.dim)
                                .tracking(0.4)
                            Text(trimmed)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.bright)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.meshOrangeHi)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.meshOrange.opacity(0.13))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider().background(Color(white: 0.18))

            if tasks.isEmpty {
                EmptyPickerState(icon: "checklist", title: "Note is empty",
                                 subtitle: "Type a task above and press ↵")
            } else if filtered.isEmpty {
                EmptyPickerState(icon: "magnifyingglass", title: "No results",
                                 subtitle: "Press ↵ to add as new task")
            } else {
                List {
                    ForEach(Array(filtered.enumerated()), id: \.offset) { _, task in
                        Button { onSelect(task, false) } label: {
                            HStack(spacing: 10) {
                                Text("S\(sessionCount + 1)")
                                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                    .padding(.horizontal, 4).padding(.vertical, 2)
                                    .background(Capsule().fill(Color.meshOrange.opacity(0.22)))
                                    .foregroundStyle(Color.meshOrangeHi)
                                Text(task)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Color.bright)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 3)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 280, height: 370)
        .background(Color(white: 0.09))
        .preferredColorScheme(.dark)
        .onAppear { searchFocused = true }
        .animation(.easeInOut(duration: 0.14), value: showAddRow)
    }
}

// MARK: - Shared picker components

struct PickerHeader: View {
    let title: String
    let onDismiss: () -> Void
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.soft)
                .tracking(0.5)
            Spacer()
            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.dim)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.inkLight))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

struct EmptyPickerState: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 26)).foregroundStyle(Color.dim)
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.muted)
            Text(subtitle)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.dim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
