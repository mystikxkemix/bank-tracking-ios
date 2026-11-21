import Foundation
import Security

/// Data shared between the app and its widget through a shared Keychain access group:
/// server address, selected space, session token and the last widget figures.
/// A Keychain group (not an App Group) because it works with the team's wildcard development profile,
/// and the session token is better kept in the Keychain than in a plain file.
enum SharedStore {
    /// "<TeamID>.io.github.mystikxkemix.banktracking.shared", from Info.plist (`$(AppIdentifierPrefix)` expanded at build).
    private static let accessGroup: String? = Bundle.main.object(forInfoDictionaryKey: "SharedKeychainGroup") as? String
    private static let service: String = "io.github.mystikxkemix.banktracking"

    private enum Key: String {
        case server, space, session, snapshot
    }

    static var serverURL: String? {
        get { string(.server) }
        set { setString(newValue, for: .server) }
    }

    static var selectedSpaceId: String? {
        get { string(.space) }
        set { setString(newValue, for: .space) }
    }

    /// Value of the `bt_session` cookie, copied by the app after login so the widget can call the API.
    static var sessionToken: String? {
        get { string(.session) }
        set { setString(newValue, for: .session) }
    }

    /// Last figures the widget showed, used when the server cannot be reached.
    static var snapshot: WidgetSnapshot? {
        get { read(.snapshot).flatMap { (data: Data) -> WidgetSnapshot? in try? JSONDecoder().decode(WidgetSnapshot.self, from: data) } }
        set { write(newValue.flatMap { (value: WidgetSnapshot) -> Data? in try? JSONEncoder().encode(value) }, for: .snapshot) }
    }

    /// Called on logout or expired session: the widget must stop showing figures.
    static func clearSession() {
        sessionToken = nil
        snapshot = nil
    }

    // MARK: Keychain

    private static func string(_ key: Key) -> String? {
        read(key).flatMap { (data: Data) -> String? in String(data: data, encoding: .utf8) }
    }

    private static func setString(_ value: String?, for key: Key) {
        write(value.map { (text: String) -> Data in Data(text.utf8) }, for: key)
    }

    private static func baseQuery(_ key: Key) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        if let group: String = accessGroup, !group.hasPrefix("$(") {
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }

    private static func read(_ key: Key) -> Data? {
        var query: [String: Any] = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func write(_ data: Data?, for key: Key) {
        let query: [String: Any] = baseQuery(key)
        SecItemDelete(query as CFDictionary)
        guard let data: Data = data else { return }
        var attributes: [String: Any] = query
        attributes[kSecValueData as String] = data
        // The widget refreshes in the background, after the first unlock since boot.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }
}

/// What the widget shows: the savings of the month and what is left of the budgets.
struct WidgetSnapshot: Codable, Equatable {
    /// "YYYY-MM".
    let month: String
    let spaceName: String
    /// netCents of the month (income - expenses).
    let savingsCents: Int
    /// Sum of limits - sum spent over all budgets; nil when the space has no budget.
    let budgetLeftCents: Int?
    let updatedAt: Date

    init(month: String, spaceName: String, savingsCents: Int, budgetLeftCents: Int?, updatedAt: Date) {
        self.month = month
        self.spaceName = spaceName
        self.savingsCents = savingsCents
        self.budgetLeftCents = budgetLeftCents
        self.updatedAt = updatedAt
    }

    init(summary: MonthSummary, spaceName: String, now: Date = Date()) {
        var limit: Int = 0
        var spent: Int = 0
        for budget in summary.budgets {
            limit += budget.monthlyLimitCents
            spent += budget.spentCents
        }
        self.init(
            month: summary.month,
            spaceName: spaceName,
            savingsCents: summary.netCents,
            budgetLeftCents: summary.budgets.isEmpty ? nil : limit - spent,
            updatedAt: now)
    }
}

/// Loads the widget figures with the shared session token. Used by the widget timeline and the app's debug preview.
enum WidgetLoader {
    enum Outcome: Equatable {
        case fresh(WidgetSnapshot)
        /// Server unreachable: last known figures.
        case cached(WidgetSnapshot)
        case signedOut
        case failed(String)
    }

    static func load(now: Date = Date()) async -> Outcome {
        guard let server: String = SharedStore.serverURL, let url: URL = URL(string: server),
              let space: String = SharedStore.selectedSpaceId, let token: String = SharedStore.sessionToken else {
            return .signedOut
        }
        let client: APIClient = APIClient(baseURL: url, sessionToken: token)
        do {
            async let summary: MonthSummary = client.monthSummary(space: space, month: MonthKey.current(now: now))
            async let spaces: [Space] = client.spaces()
            let name: String = try await spaces.first { (item: Space) -> Bool in item.id == space }?.name ?? ""
            let snapshot: WidgetSnapshot = WidgetSnapshot(summary: try await summary, spaceName: name, now: now)
            SharedStore.snapshot = snapshot
            return .fresh(snapshot)
        } catch APIError.unauthorized {
            SharedStore.clearSession()
            return .signedOut
        } catch {
            if let cached: WidgetSnapshot = SharedStore.snapshot {
                return .cached(cached)
            }
            return .failed(error.localizedDescription)
        }
    }
}
