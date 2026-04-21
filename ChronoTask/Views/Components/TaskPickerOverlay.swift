import SwiftUI
import AppKit

struct TaskPickerOverlay: View {
    let tasks: [ClickUpTask]
    @Binding var selectedTask: ClickUpTask?
    @Binding var isOpen: Bool

    @State private var query: String = ""
    @State private var focusedIndex: Int?

    private var filtered: [ClickUpTask] {
        if query.isEmpty { return tasks }
        let q = query.lowercased()
        return tasks.filter {
            $0.name.lowercased().contains(q) ||
            ($0.list?.name?.lowercased().contains(q) == true)
        }
    }

    var body: some View {
        ZStack {
            // Backdrop
            Rectangle()
                .fill(Color(hex: "141411").opacity(0.22))
                .background(.ultraThinMaterial)
                .contentShape(Rectangle())
                .onTapGesture { close() }

            // Panel
            VStack(spacing: 0) {
                searchHeader
                Rectangle().fill(Theme.hairline).frame(height: 1)
                taskList
            }
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
            .padding(10)
        }
        .ignoresSafeArea()
        .background(PickerKeyHandler(
            onEscape: close,
            onArrow: handleArrow,
            onEnter: commitFocused
        ))
        .onChange(of: query) { _ in focusedIndex = filtered.isEmpty ? nil : 0 }
        .onAppear { focusedIndex = filtered.firstIndex(where: { $0.id == selectedTask?.id }) ?? (filtered.isEmpty ? nil : 0) }
    }

    // MARK: - Search header

    private var searchHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Theme.searchIconSize))
                .foregroundColor(Theme.muted)

            TextField("Search tasks…", text: $query)
                .textFieldStyle(.plain)
                .font(Theme.pickerInputFont)
                .foregroundColor(Theme.ink)

            Text("ESC")
                .font(Theme.labelFont)
                .tracking(0.8)
                .foregroundColor(Theme.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Task list

    private var taskList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, task in
                        row(for: task, index: index)
                            .id(task.id)
                    }
                    if filtered.isEmpty {
                        Text("No matches")
                            .font(Theme.pickerRowFont)
                            .foregroundColor(Theme.muted)
                            .padding(.vertical, 14)
                    }
                }
            }
            .onChange(of: focusedIndex) { newIndex in
                if let idx = newIndex, idx < filtered.count {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        proxy.scrollTo(filtered[idx].id, anchor: .center)
                    }
                }
            }
        }
    }

    private func row(for task: ClickUpTask, index: Int) -> some View {
        let isSelected = selectedTask?.id == task.id
        let isFocused  = focusedIndex == index
        let (emoji, strippedName) = splitLeadingEmoji(from: task.name)

        return Button(action: { commit(task) }) {
            HStack(spacing: 8) {
                if let emoji = emoji {
                    Text(emoji)
                        .font(.system(size: 11))
                        .frame(width: 14)
                } else {
                    Circle()
                        .fill(statusColor(for: task))
                        .frame(width: 5, height: 5)
                        .frame(width: 14)
                }

                Text(strippedName)
                    .font(Theme.pickerRowFont)
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isFocused
                    ? Theme.rowHighlight
                    : (isSelected ? Theme.rowHighlight.opacity(0.6) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func commit(_ task: ClickUpTask) {
        selectedTask = task
        close()
    }

    private func commitFocused() {
        if let idx = focusedIndex, idx < filtered.count {
            commit(filtered[idx])
        } else if let first = filtered.first {
            commit(first)
        }
    }

    private func close() {
        withAnimation(Theme.pickerAnimation) { isOpen = false }
    }

    private func handleArrow(_ direction: ArrowDirection) {
        let count = filtered.count
        guard count > 0 else { return }
        switch direction {
        case .down:
            focusedIndex = focusedIndex.map { min($0 + 1, count - 1) } ?? 0
        case .up:
            focusedIndex = focusedIndex.map { max($0 - 1, 0) } ?? (count - 1)
        }
    }

    // MARK: - Helpers

    private func splitLeadingEmoji(from name: String) -> (String?, String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.unicodeScalars.first,
              first.properties.isEmojiPresentation ||
              (first.properties.isEmoji && first.value > 0x238C) else {
            return (nil, trimmed)
        }
        let firstChar = String(trimmed.prefix(1))
        let rest = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        return (firstChar, rest.isEmpty ? trimmed : rest)
    }

    private func statusColor(for task: ClickUpTask) -> Color {
        if let hex = task.status?.color { return Color(hex: hex) }
        return Theme.muted
    }
}

// MARK: - Keyboard handling (ESC + arrows + enter)

enum ArrowDirection {
    case up, down
}

private struct PickerKeyHandler: NSViewRepresentable {
    let onEscape: () -> Void
    let onArrow: (ArrowDirection) -> Void
    let onEnter: () -> Void

    func makeNSView(context: Context) -> PickerKeyNSView {
        let view = PickerKeyNSView()
        view.onEscape = onEscape
        view.onArrow = onArrow
        view.onEnter = onEnter
        return view
    }

    func updateNSView(_ nsView: PickerKeyNSView, context: Context) {
        nsView.onEscape = onEscape
        nsView.onArrow = onArrow
        nsView.onEnter = onEnter
    }
}

final class PickerKeyNSView: NSView {
    var onEscape: (() -> Void)?
    var onArrow: ((ArrowDirection) -> Void)?
    var onEnter: (() -> Void)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self else { return event }
                switch event.keyCode {
                case 53: // ESC
                    self.onEscape?()
                    return nil
                case 125: // down
                    self.onArrow?(.down)
                    return nil
                case 126: // up
                    self.onArrow?(.up)
                    return nil
                case 36: // return/enter
                    self.onEnter?()
                    return nil
                default:
                    return event
                }
            }
        } else if window == nil, let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    deinit {
        if let monitor = monitor { NSEvent.removeMonitor(monitor) }
    }
}
