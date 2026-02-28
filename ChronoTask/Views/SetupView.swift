import SwiftUI

struct SetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var tokenInput = ""
    @State private var isValidating = false
    @State private var teams: [ClickUpTeam] = []

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerBar

                // Content
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
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Image(systemName: "gearshape")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.primary)
                Text("CLICKUP TIMER")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .tracking(1)
            }

            Spacer()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.paddingLarge)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    // MARK: - Token Entry

    private var tokenEntryView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                // ClickUp Logo
                RoundedRectangle(cornerRadius: Theme.cornerRadiusLG)
                    .fill(LinearGradient(
                        colors: [Theme.clickUpFrom, Theme.clickUpTo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "chevron.up")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Theme.primary.opacity(0.2), radius: 8, y: 4)
                    .padding(.bottom, 8)

                // Title
                Text("Connect ClickUp")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                // Description
                Text("Enter your personal API token to start tracking time directly to your tasks.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 8)

                // Form
                VStack(spacing: 12) {
                    // Label
                    VStack(alignment: .leading, spacing: 6) {
                        Text("API TOKEN")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.textMuted)
                            .tracking(1.2)
                            .padding(.leading, 4)

                        HStack(spacing: 0) {
                            SecureField("pk_...", text: $tokenInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(Theme.textPrimary)
                                .padding(.leading, 12)

                            Image(systemName: "key.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                                .padding(.trailing, 12)
                        }
                        .frame(height: 40)
                        .background(Theme.background)
                        .cornerRadius(Theme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                    }

                    if let error = appState.errorMessage {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.error)
                            .lineLimit(2)
                    }

                    // Connect Button
                    Button(action: validateToken) {
                        HStack(spacing: 10) {
                            if isValidating {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                            }
                            Text(isValidating ? "CONNECTING..." : "CONNECT ACCOUNT")
                                .font(.system(size: 14, weight: .bold))
                                .tracking(0.5)
                            if !isValidating {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(tokenInput.isEmpty ? Theme.surfaceLight : Theme.primary)
                        .cornerRadius(Theme.cornerRadius)
                        .shadow(color: Theme.primary.opacity(tokenInput.isEmpty ? 0 : 0.2), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                    .disabled(tokenInput.isEmpty || isValidating)
                }

                // Help link
                Text("Where can I find my API token?")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.textMuted)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Workspace Picker

    private var workspacePickerView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "building.2")
                .font(.system(size: 28))
                .foregroundColor(Theme.primary)

            Text("Select Workspace")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

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
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(teams) { team in
                            Button(action: { appState.selectTeam(team) }) {
                                Text(team.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(Theme.background)
                                    .foregroundColor(Theme.textPrimary)
                                    .cornerRadius(Theme.cornerRadius)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                            .stroke(Theme.border, lineWidth: 1)
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
