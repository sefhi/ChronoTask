import Foundation

enum AuthState {
    case loading
    case needsAuth
    case needsWorkspace(user: ClickUpUser)
    case authenticated(user: ClickUpUser, team: ClickUpTeam)
}

final class AppState: ObservableObject {
    @Published var authState: AuthState = .loading
    @Published var errorMessage: String?

    private let api = ClickUpAPI.shared

    init() {
        loadSavedToken()
    }

    private func loadSavedToken() {
        guard let token = KeychainService.loadToken() else {
            authState = .needsAuth
            return
        }
        api.token = token
        Task { @MainActor in
            do {
                NSLog("[AppState] Validating saved token...")
                let user = try await api.validateToken(token)
                NSLog("[AppState] Token valid, user: \(user.username) (id: \(user.id))")
                let teams = try await api.getTeams()
                NSLog("[AppState] Got \(teams.count) teams")
                if teams.count == 1 {
                    NSLog("[AppState] Auto-selecting team: \(teams[0].name) (id: \(teams[0].id))")
                    authState = .authenticated(user: user, team: teams[0])
                } else {
                    authState = .needsWorkspace(user: user)
                }
            } catch {
                NSLog("[AppState] Token validation failed: \(error)")
                authState = .needsAuth
            }
        }
    }

    @MainActor
    func authenticate(token: String) async {
        errorMessage = nil
        do {
            NSLog("[AppState] Authenticating with new token...")
            let user = try await api.validateToken(token)
            NSLog("[AppState] Token valid, user: \(user.username) (id: \(user.id))")
            try KeychainService.saveToken(token)
            let teams = try await api.getTeams()
            NSLog("[AppState] Got \(teams.count) teams: \(teams.map { "\($0.name) (id: \($0.id))" })")
            if teams.count == 1 {
                authState = .authenticated(user: user, team: teams[0])
            } else {
                authState = .needsWorkspace(user: user)
            }
        } catch {
            NSLog("[AppState] Authentication error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func selectTeam(_ team: ClickUpTeam) {
        if case .needsWorkspace(let user) = authState {
            authState = .authenticated(user: user, team: team)
        }
    }

    @MainActor
    func logout() {
        KeychainService.deleteToken()
        api.token = ""
        authState = .needsAuth
        errorMessage = nil
    }
}
