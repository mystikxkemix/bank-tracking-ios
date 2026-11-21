import Foundation

/// Debug builds only: lets a script log in and open a tab without typing, e.g.
/// `SIMCTL_CHILD_BT_SERVER=http://localhost:8095 SIMCTL_CHILD_BT_EMAIL=... xcrun simctl launch ...`.
/// Release builds ignore it completely.
enum DebugLaunch {
    struct Login {
        let server: String
        let email: String
        let password: String
    }

    static var login: Login? {
        #if DEBUG
        let env: [String: String] = ProcessInfo.processInfo.environment
        guard let server: String = env["BT_SERVER"], let email: String = env["BT_EMAIL"], let password: String = env["BT_PASSWORD"] else {
            return nil
        }
        return Login(server: server, email: email, password: password)
        #else
        return nil
        #endif
    }

    /// Initial tab: dashboard, transactions, budgets, split, settings.
    static var tab: String? {
        #if DEBUG
        return ProcessInfo.processInfo.environment["BT_TAB"]
        #else
        return nil
        #endif
    }

    /// Name of the space to open, e.g. "Foyer".
    static var spaceName: String? {
        #if DEBUG
        return ProcessInfo.processInfo.environment["BT_SPACE"]
        #else
        return nil
        #endif
    }

    /// Month to open, "YYYY-MM".
    static var month: MonthKey? {
        #if DEBUG
        return ProcessInfo.processInfo.environment["BT_MONTH"].flatMap { (key: String) -> MonthKey? in MonthKey(key) }
        #else
        return nil
        #endif
    }

    /// "1" opens a screen that renders the widget with the real loader (to check it without a home screen).
    static var widgetPreview: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["BT_WIDGET"] == "1"
        #else
        return false
        #endif
    }

    /// Initial segment of the budgets tab: "goals" to open the goals list.
    static var segment: String? {
        #if DEBUG
        return ProcessInfo.processInfo.environment["BT_SEGMENT"]
        #else
        return nil
        #endif
    }
}

extension MonthKey {
    /// Month the screens open on: the current one (or a debug override for screenshots).
    static var initial: MonthKey {
        DebugLaunch.month ?? current()
    }
}
