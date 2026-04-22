import SwiftUI

struct SetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var tokenInput = ""
    @State private var isValidating = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                switch appState.authState {
                case .needsAuth, .loading:
                    tokenEntryView
                case .needsWorkspace:
                    workspacePickerView
                default:
                    EmptyView()
                }
            }
        }
        .preferredColorScheme(.light)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contextMenu {
            Button("Quit ChronoTask") { NSApplication.shared.terminate(nil) }
        }
    }

    // MARK: - Token Entry

    private var tokenEntryView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 32)

            VStack(spacing: 18) {
                // ClickUp logo mark — kept as small gradient tile
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [Theme.clickUpFrom, Theme.clickUpTo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "chevron.up")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    )

                Text("Connect ClickUp")
                    .font(Theme.setupTitleFont)
                    .foregroundColor(Theme.ink)

                Text("Enter your personal API token to start tracking time directly to your tasks.")
                    .font(Theme.bodyFont)
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("API TOKEN")
                        .font(Theme.labelFont)
                        .tracking(1.8)
                        .foregroundColor(Theme.muted)

                    HStack(spacing: 0) {
                        SecureField("pk_...", text: $tokenInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Theme.ink)
                            .padding(.leading, 12)

                        Image(systemName: "key.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.muted)
                            .padding(.trailing, 12)
                    }
                    .frame(height: 38)
                    .background(Theme.background)
                    .overlay(
                        Rectangle()
                            .stroke(Theme.hairline, lineWidth: 1)
                    )

                    if let error = appState.errorMessage {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.error)
                            .lineLimit(2)
                    }

                    Button(action: validateToken) {
                        HStack(spacing: 10) {
                            if isValidating {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                                    .tint(Theme.background)
                            }
                            Text(isValidating ? "CONNECTING" : "CONNECT ACCOUNT")
                                .font(Theme.buttonFont)
                                .tracking(2.5)
                        }
                        .foregroundColor(Theme.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(tokenInput.isEmpty ? Theme.muted : Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(tokenInput.isEmpty || isValidating)
                }

                Text("Where can I find my API token?")
                    .font(Theme.labelFont)
                    .tracking(1.4)
                    .foregroundColor(Theme.muted)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 28)

            Spacer()
        }
    }

    // MARK: - Workspace Picker

    private var workspacePickerView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 32)

            Image(systemName: "building.2")
                .font(.system(size: 26))
                .foregroundColor(Theme.accent)

            Text("Select Workspace")
                .font(Theme.setupTitleFont)
                .foregroundColor(Theme.ink)

            if case .needsWorkspace = appState.authState {
                WorkspaceList(appState: appState)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Actions

    private func validateToken() {
        isValidating = true
        Task {
            await appState.authenticate(token: tokenInput)
            isValidating = false
        }
    }
}

private struct WorkspaceList: View {
    @ObservedObject var appState: AppState
    @State private var teams: [ClickUpTeam] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(Theme.ink)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(teams) { team in
                            Button(action: { appState.selectTeam(team) }) {
                                HStack {
                                    Text(team.name)
                                        .font(Theme.bodyFont)
                                        .foregroundColor(Theme.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Theme.muted)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .frame(maxWidth: .infinity)
                                .overlay(
                                    Rectangle()
                                        .stroke(Theme.hairline, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .task {
            do {
                teams = try await ClickUpAPI.shared.getTeams()
            } catch {}
            isLoading = false
        }
    }
}
