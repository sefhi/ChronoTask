import SwiftUI

struct TaskSelector: View {
    let tasks: [ClickUpTask]
    @Binding var selectedTask: ClickUpTask?
    @State private var searchText = ""
    @State private var isExpanded = false
    @State private var focusedIndex: Int?

    private var filteredTasks: [ClickUpTask] {
        if searchText.isEmpty {
            return tasks
        }
        let query = searchText.lowercased()
        return tasks.filter {
            $0.name.lowercased().contains(query) ||
            ($0.list?.name?.lowercased().contains(query) == true)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed: shows selected task or placeholder
            Button(action: { withAnimation(Theme.defaultAnimation) { isExpanded.toggle() } }) {
                HStack(spacing: 0) {
                    if let task = selectedTask {
                        Circle()
                            .fill(statusColor(for: task))
                            .frame(width: 6, height: 6)
                            .padding(.leading, 12)

                        Text(task.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                            .padding(.leading, 8)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.leading, 12)

                        Text("Select Task...")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textMuted)
                            .padding(.leading, 8)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .padding(.trailing, 12)
                }
                .frame(height: 36)
                .background(Theme.background)
                .cornerRadius(Theme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .stroke(
                            selectedTask != nil ? Theme.primary.opacity(0.5) : Theme.border,
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)

            // Expanded: search + list
            if isExpanded {
                VStack(spacing: 0) {
                    // Search field
                    HStack(spacing: 0) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                            .frame(width: 30)

                        TextField("Search tasks...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textPrimary)
                            .onSubmit {
                                if let idx = focusedIndex, idx < filteredTasks.count {
                                    selectTask(filteredTasks[idx])
                                } else if let first = filteredTasks.first {
                                    selectTask(first)
                                }
                            }
                    }
                    .frame(height: 30)
                    .padding(.horizontal, 4)

                    Rectangle().fill(Theme.border.opacity(0.5)).frame(height: 0.5)

                    // Task list
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(filteredTasks.enumerated()), id: \.element.id) { index, task in
                                    let isSelected = selectedTask?.id == task.id
                                    let isFocused = focusedIndex == index

                                    Button(action: { selectTask(task) }) {
                                        HStack(spacing: 8) {
                                            RoundedRectangle(cornerRadius: 1.5)
                                                .fill(isSelected ? Theme.primary : Color.clear)
                                                .frame(width: 3, height: 24)

                                            Circle()
                                                .fill(statusColor(for: task))
                                                .frame(width: 6, height: 6)

                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(task.name)
                                                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                                    .foregroundColor(Theme.textPrimary)
                                                    .lineLimit(1)
                                                if let listName = task.list?.name {
                                                    Text(listName)
                                                        .font(.system(size: 9))
                                                        .foregroundColor(Theme.textSecondary)
                                                        .lineLimit(1)
                                                }
                                            }

                                            Spacer()

                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(Theme.primary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 6)
                                        .background(
                                            isSelected
                                                ? Theme.primary.opacity(0.15)
                                                : isFocused
                                                    ? Theme.border.opacity(0.4)
                                                    : Color.clear
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .id(task.id)

                                    if task.id != filteredTasks.last?.id {
                                        Rectangle()
                                            .fill(Theme.border.opacity(0.3))
                                            .frame(height: 0.5)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                        .onChange(of: focusedIndex) { newIndex in
                            if let idx = newIndex, idx < filteredTasks.count {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    proxy.scrollTo(filteredTasks[idx].id, anchor: .center)
                                }
                            }
                        }
                    }
                }
                .background(Theme.surfaceLight)
                .cornerRadius(Theme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .padding(.top, 4)
                .onArrowKeys { direction in
                    handleArrowKey(direction)
                }
            }
        }
        .onChange(of: searchText) { _ in
            focusedIndex = nil
        }
    }

    private func selectTask(_ task: ClickUpTask) {
        selectedTask = task
        searchText = ""
        focusedIndex = nil
        withAnimation(Theme.defaultAnimation) {
            isExpanded = false
        }
    }

    private func handleArrowKey(_ direction: ArrowDirection) {
        let count = filteredTasks.count
        guard count > 0 else { return }

        switch direction {
        case .down:
            if let current = focusedIndex {
                focusedIndex = min(current + 1, count - 1)
            } else {
                focusedIndex = 0
            }
        case .up:
            if let current = focusedIndex {
                focusedIndex = max(current - 1, 0)
            } else {
                focusedIndex = count - 1
            }
        case .enter:
            if let idx = focusedIndex, idx < count {
                selectTask(filteredTasks[idx])
            }
        }
    }

    private func statusColor(for task: ClickUpTask) -> Color {
        guard let hex = task.status?.color else { return Theme.textSecondary }
        return Color(hex: hex)
    }
}

// MARK: - Arrow Key Handling

enum ArrowDirection {
    case up, down, enter
}

private struct ArrowKeyModifier: ViewModifier {
    let handler: (ArrowDirection) -> Void

    func body(content: Content) -> some View {
        content.background(ArrowKeyReceiver(handler: handler))
    }
}

extension View {
    func onArrowKeys(_ handler: @escaping (ArrowDirection) -> Void) -> some View {
        modifier(ArrowKeyModifier(handler: handler))
    }
}

private struct ArrowKeyReceiver: NSViewRepresentable {
    let handler: (ArrowDirection) -> Void

    func makeNSView(context: Context) -> ArrowKeyNSView {
        let view = ArrowKeyNSView()
        view.handler = handler
        return view
    }

    func updateNSView(_ nsView: ArrowKeyNSView, context: Context) {
        nsView.handler = handler
    }
}

class ArrowKeyNSView: NSView {
    var handler: ((ArrowDirection) -> Void)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self else { return event }
                switch event.keyCode {
                case 125: // down arrow
                    self.handler?(.down)
                    return nil
                case 126: // up arrow
                    self.handler?(.up)
                    return nil
                case 36: // return/enter
                    self.handler?(.enter)
                    return nil
                case 48: // tab
                    self.handler?(.down)
                    return nil
                default:
                    return event
                }
            }
        }
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if superview == nil, let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
