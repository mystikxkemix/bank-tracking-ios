import SwiftUI

@main
struct BankTrackingApp: App {
    @State private var session: SessionStore = SessionStore()
    @State private var lock: AppLock = AppLock()
    @Environment(\.scenePhase) private var scenePhase: ScenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(lock)
                .overlay {
                    if lock.isLocked {
                        LockScreen(lock: lock)
                    }
                }
                .task { await lock.unlock() }
        }
        .onChange(of: scenePhase) { (_: ScenePhase, phase: ScenePhase) in
            switch phase {
            case .background:
                lock.lockIfEnabled()
            case .active:
                Task { await lock.unlock() }
            default:
                break
            }
        }
    }
}

struct RootView: View {
    @Environment(SessionStore.self) private var session: SessionStore

    var body: some View {
        Group {
            switch session.phase {
            case .starting:
                ProgressView()
            case .signedOut:
                LoginView()
            case .signedIn:
                if DebugLaunch.widgetPreview {
                    WidgetPreviewScreen()
                } else {
                    MainTabView()
                }
            }
        }
        .task {
            if let debug: DebugLaunch.Login = DebugLaunch.login {
                try? await session.login(server: debug.server, email: debug.email, password: debug.password)
                if session.phase == .starting { await session.start() }
            } else {
                await session.start()
            }
        }
    }
}

struct MainTabView: View {
    enum Tab: String {
        case dashboard, transactions, budgets, split, settings
    }

    @State private var tab: Tab = Tab(rawValue: DebugLaunch.tab ?? "") ?? .dashboard

    var body: some View {
        TabView(selection: $tab) {
            DashboardView()
                .tabItem { Label("Accueil", systemImage: "house") }
                .tag(Tab.dashboard)
            TransactionsView()
                .tabItem { Label("Transactions", systemImage: "list.bullet") }
                .tag(Tab.transactions)
            BudgetsGoalsView()
                .tabItem { Label("Budgets", systemImage: "chart.bar") }
                .tag(Tab.budgets)
            SplitView()
                .tabItem { Label("Répartition", systemImage: "circle.lefthalf.filled") }
                .tag(Tab.split)
            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
    }
}

/// Toolbar menu to switch space, shown on every data screen when the user has several spaces.
struct SpaceMenuButton: View {
    @Environment(SessionStore.self) private var session: SessionStore

    var body: some View {
        if session.spaces.count > 1 {
            Menu {
                ForEach(session.spaces) { (space: Space) in
                    Button {
                        Task { await session.selectSpace(space.id) }
                    } label: {
                        if space.id == session.selectedSpaceId {
                            Label(space.name, systemImage: "checkmark")
                        } else {
                            Text(space.name)
                        }
                    }
                }
            } label: {
                Label(session.selectedSpace?.name ?? "Espace", systemImage: "person.2")
                    .labelStyle(.titleAndIcon)
            }
            .accessibilityLabel("Changer d'espace")
        }
    }
}
