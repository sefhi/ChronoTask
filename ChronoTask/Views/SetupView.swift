import SwiftUI

struct SetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var tokenInput = ""
    @State private var isValidating = false

    var body: some View {
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
        // No background of its own: the panel's glass shows through.
        .frame(width: Theme.panelWidth)
        .contextMenu {
            Button("Salir de ChronoTask") { NSApplication.shared.terminate(nil) }
        }
    }

    // MARK: - Token Entry

    private var tokenEntryView: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: Theme.radiusSurface, style: .continuous)
                .fill(LinearGradient(
                    colors: [Theme.clickUpFrom, Theme.clickUpTo],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 52, height: 52)
                .overlay(
                    // SF Symbols must use `.system`; they cannot render in a custom face.
                    Image(systemName: "chevron.up")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                )

            Text("Conecta ClickUp")
                .font(Theme.setupTitleFont)
                .foregroundColor(Theme.ink)

            Text("Introduce tu token personal de API para registrar tiempo directamente en tus tareas.")
                .font(Theme.bodyFont)
                .foregroundColor(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("TOKEN DE API")
                    .font(Theme.labelFont)
                    .tracking(Theme.trackingLabel)
                    .foregroundColor(Theme.inkSecondary)

                HStack(spacing: 0) {
                    SecureField("pk_…", text: $tokenInput)
                        .textFieldStyle(.plain)
                        .font(Theme.tokenFieldFont)
                        .foregroundColor(Theme.ink)
                        .padding(.leading, 12)

                    Image(systemName: "key.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.inkQuaternary)
                        .padding(.trailing, 12)
                }
                .frame(height: 40)
                .insetSurface(radius: Theme.radiusField)

                if let error = appState.errorMessage {
                    Text(error)
                        .font(Theme.errorFont)
                        .foregroundColor(Theme.error)
                        .lineLimit(2)
                }

                Button(action: validateToken) {
                    HStack(spacing: 10) {
                        if isValidating {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                                .tint(Theme.onAccent)
                        }
                        Text(isValidating ? "CONECTANDO" : "CONECTAR CUENTA")
                            .font(Theme.monoLabelFont)
                            .tracking(Theme.trackingCta)
                    }
                    .foregroundColor(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                }
                // The style already dims to 45% when disabled.
                .buttonStyle(.chronoAccent)
                .disabled(tokenInput.isEmpty || isValidating)
            }

            Text("¿Dónde encuentro mi token de API?")
                .font(Theme.labelFont)
                .tracking(1.4)
                .foregroundColor(Theme.inkSecondary)
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
    }

    // MARK: - Workspace Picker

    private var workspacePickerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.2")
                .font(.system(size: 26))
                .foregroundColor(Theme.accent)

            Text("Elige un espacio")
                .font(Theme.setupTitleFont)
                .foregroundColor(Theme.ink)

            if case .needsWorkspace = appState.authState {
                WorkspaceList(appState: appState)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
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
    @State private var loadError: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(Theme.ink)
                    .frame(height: 80)
            } else if let loadError {
                Text(loadError)
                    .font(Theme.errorFont)
                    .foregroundColor(Theme.error)
                    .multilineTextAlignment(.center)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(teams) { team in
                            Button { appState.selectTeam(team) } label: {
                                HStack {
                                    Text(team.name)
                                        .font(Theme.bodyFont)
                                        .foregroundColor(Theme.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Theme.inkQuaternary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.chronoInset(radius: Theme.radiusRow))
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .task {
            do {
                teams = try await ClickUpAPI.shared.getTeams()
            } catch {
                // Previously swallowed silently, leaving an empty list with no reason.
                loadError = error.localizedDescription
            }
            isLoading = false
        }
    }
}
