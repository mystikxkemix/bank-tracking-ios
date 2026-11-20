import Foundation
import Observation

/// App-wide session: server address, logged-in user, spaces and the per-space reference data
/// (categories, accounts) that every screen needs to show names instead of ids.
@MainActor
@Observable
final class SessionStore {
    enum Phase: Equatable {
        case starting
        case signedOut
        case signedIn(CurrentUser)
    }

    private(set) var phase: Phase = .starting
    private(set) var client: APIClient?
    private(set) var spaces: [Space] = []
    private(set) var categoriesById: [String: Category] = [:]
    private(set) var accounts: [Account] = []
    /// Shown on the login screen after an automatic sign-out (expired session).
    var notice: String?

    var selectedSpaceId: String? {
        didSet { UserDefaults.standard.set(selectedSpaceId, forKey: Keys.space) }
    }

    var serverURL: String {
        UserDefaults.standard.string(forKey: Keys.server) ?? ""
    }

    var selectedSpace: Space? {
        spaces.first { (space: Space) -> Bool in space.id == selectedSpaceId }
    }

    private enum Keys {
        static let server: String = "serverURL"
        static let space: String = "selectedSpaceId"
    }

    init() {
        selectedSpaceId = UserDefaults.standard.string(forKey: Keys.space)
    }

    /// Restores the previous session from the saved server and the stored cookie.
    func start() async {
        guard let url: URL = SessionStore.parseServer(serverURL) else {
            phase = .signedOut
            return
        }
        let client: APIClient = APIClient(baseURL: url)
        self.client = client
        do {
            let status: AuthStatus = try await client.authStatus()
            if let user: CurrentUser = status.user {
                try await enter(user: user)
            } else {
                phase = .signedOut
            }
        } catch {
            // Offline at launch: stay on the login screen with the reason.
            notice = error.localizedDescription
            phase = .signedOut
        }
    }

    func login(server: String, email: String, password: String) async throws {
        guard let url: URL = SessionStore.parseServer(server) else {
            throw APIError.server(status: 0, message: "Adresse du serveur invalide (ex : https://comptes.exemple.fr).")
        }
        let client: APIClient = APIClient(baseURL: url)
        let status: AuthStatus = try await client.authStatus()
        guard status.configured else {
            throw APIError.server(status: 0, message: "Aucun compte sur ce serveur. Crée le compte administrateur depuis le site.")
        }
        try await client.login(email: email.trimmingCharacters(in: .whitespaces), password: password)
        let after: AuthStatus = try await client.authStatus()
        guard let user: CurrentUser = after.user else {
            throw APIError.unauthorized
        }
        UserDefaults.standard.set(url.absoluteString, forKey: Keys.server)
        self.client = client
        notice = nil
        try await enter(user: user)
    }

    func logout() async {
        try? await client?.logout()
        client?.clearCookies()
        reset()
    }

    func selectSpace(_ id: String) async {
        selectedSpaceId = id
        await loadReferenceData()
    }

    /// Every screen funnels its errors here: an expired session sends the user back to login.
    func handle(_ error: Error) -> String {
        if let apiError: APIError = error as? APIError, apiError == .unauthorized {
            client?.clearCookies()
            reset()
            notice = apiError.localizedDescription
        }
        return error.localizedDescription
    }

    func category(_ id: String?) -> Category? {
        guard let id: String = id else { return nil }
        return categoriesById[id]
    }

    func accountName(_ id: String) -> String {
        accounts.first { (account: Account) -> Bool in account.id == id }?.name ?? "Compte"
    }

    /// Accepts "comptes.exemple.fr" or a full URL; defaults to HTTPS.
    nonisolated static func parseServer(_ text: String) -> URL? {
        let trimmed: String = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme: String = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url: URL = URL(string: withScheme), let scheme: String = url.scheme, ["http", "https"].contains(scheme), url.host != nil else {
            return nil
        }
        return url
    }

    private func enter(user: CurrentUser) async throws {
        guard let client: APIClient = client else { return }
        spaces = try await client.spaces()
        if let name: String = DebugLaunch.spaceName, let match: Space = spaces.first(where: { (space: Space) -> Bool in space.name == name }) {
            selectedSpaceId = match.id
        }
        // Same default as the website: the last used space, else the first one.
        if selectedSpace == nil {
            selectedSpaceId = spaces.first?.id
        }
        await loadReferenceData()
        phase = .signedIn(user)
    }

    private func loadReferenceData() async {
        guard let client: APIClient = client, let space: String = selectedSpaceId else { return }
        do {
            async let categories: [Category] = client.categories(space: space)
            async let accounts: [Account] = client.accounts(space: space)
            var map: [String: Category] = [:]
            for category in try await categories {
                map[category.id] = category
            }
            categoriesById = map
            self.accounts = try await accounts
        } catch {
            _ = handle(error)
        }
    }

    private func reset() {
        phase = .signedOut
        spaces = []
        categoriesById = [:]
        accounts = []
    }
}
