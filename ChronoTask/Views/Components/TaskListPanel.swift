import SwiftUI

/// Inline task picker.
///
/// Replaces the old full-screen overlay: this is an ordinary block in the panel's
/// flow, with no backdrop and no keyboard handling of its own. Its height is driven
/// by the parent so the window can grow with it.
struct TaskListPanel: View {
    let tasks: [ClickUpTask]
    /// "INICIAR", or "+ INICIAR" when the pick joins tasks already running.
    let goLabel: String
    let focusedIndex: Int?
    let emptyMessage: String
    /// Already-worded "Actualizado hace…" line; nil draws nothing. See `SyncLabel`.
    let syncedLabel: String?
    let isSyncing: Bool
    @Binding var query: String
    var searchFocus: FocusState<Bool>.Binding
    let onSelect: (ClickUpTask) -> Void
    let onHoverRow: (Int?) -> Void
    let onRefresh: () -> Void

    @State private var hoveredIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            searchField
            rows
            syncedLine
        }
        .frame(maxWidth: .infinity)
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Theme.searchIconSize, weight: .medium))
                .foregroundColor(Theme.inkQuaternary)

            TextField("Buscar tarea para iniciar…", text: $query)
                .textFieldStyle(.plain)
                .font(Theme.searchFont)
                .foregroundColor(Theme.ink)
                .focused(searchFocus)

            RefreshButton(isSyncing: isSyncing, action: onRefresh)

            Text("↑↓ ⏎")
                .font(Theme.hintFont)
                .foregroundColor(Theme.inkQuaternary)

            Text("ESC")
                .font(Theme.labelFont)
                .tracking(Theme.trackingEsc)
                .foregroundColor(Theme.inkSecondary)
                .opacity(0.5)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .insetSurface(radius: Theme.radiusField)
        .padding(.top, 10)
    }

    @ViewBuilder
    private var syncedLine: some View {
        if let syncedLabel {
            Text(syncedLabel)
                .font(Theme.syncedFont)
                .foregroundColor(Theme.ink)
                .opacity(0.45)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 11)
                .padding(.top, 6)
                .padding(.bottom, 2)
                // The text swaps between "Sincronizando…" and a minute count, and a
                // width change mid-crossfade reads as a stutter.
                .animation(nil, value: syncedLabel)
        }
    }

    @ViewBuilder
    private var rows: some View {
        if tasks.isEmpty {
            Text(emptyMessage)
                .font(Theme.emptyFont)
                .foregroundColor(Theme.inkSecondary)
                .opacity(0.5)
                .frame(maxWidth: .infinity)
                .padding(10)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                            row(task, index: index)
                                .id(task.id)
                        }
                    }
                }
                // Explicit height: a ScrollView has no intrinsic size, which would
                // otherwise collapse the content-driven window height to zero.
                .frame(maxHeight: Theme.listScrollMax)
                .padding(.top, 6)
                .onChange(of: focusedIndex) { newValue in
                    guard let newValue, tasks.indices.contains(newValue) else { return }
                    withAnimation(Theme.scrollAnimation) {
                        proxy.scrollTo(tasks[newValue].id, anchor: .center)
                    }
                }
            }
        }
    }

    private func row(_ task: ClickUpTask, index: Int) -> some View {
        let isFocused = index == focusedIndex
        let isActive = isFocused || hoveredIndex == index

        return Button { onSelect(task) } label: {
            HStack(spacing: 8) {
                TaskIcon(task: task)

                Text(task.strippedName)
                    .font(Theme.rowFont)
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                // Picking a row starts it, so the row says so where the pointer or
                // the keyboard is. Elsewhere, ⌘1…⌘9 on the first nine rows: the same
                // thing in one keystroke.
                if isActive {
                    Text(goLabel)
                        .font(Theme.goFont)
                        .tracking(0.3)
                        .foregroundColor(Theme.accent)
                } else if index < 9 {
                    Text("⌘\(index + 1)")
                        .font(Theme.hintFont)
                        .foregroundColor(Theme.inkQuaternary)
                        .opacity(0.5)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.radiusRow, style: .continuous)
                    .fill(rowBackground(isFocused: isFocused, isHovered: hoveredIndex == index))
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredIndex = hovering ? index : (hoveredIndex == index ? nil : hoveredIndex)
            onHoverRow(hovering ? index : nil)
        }
    }

    /// Keyboard focus outranks pointer hover — the two must stay visually distinct.
    private func rowBackground(isFocused: Bool, isHovered: Bool) -> Color {
        if isFocused { return Theme.rowFocused }
        if isHovered { return Theme.rowHover }
        return .clear
    }
}
