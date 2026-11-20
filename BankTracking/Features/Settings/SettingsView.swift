import SwiftUI

struct SettingsView: View {
    @Environment(SessionStore.self) private var session: SessionStore
    @Environment(AppLock.self) private var lock: AppLock
    @State private var serverVersion: String?

    var body: some View {
        @Bindable var lock: AppLock = lock
        NavigationStack {
            List {
                if case .signedIn(let user) = session.phase {
                    Section("Compte") {
                        LabeledContent("Nom", value: user.name)
                        LabeledContent("Email", value: user.email)
                    }
                }
                if session.spaces.count > 1 {
                    Section("Espace") {
                        Picker("Espace affiché", selection: Binding(
                            get: { session.selectedSpaceId ?? "" },
                            set: { (id: String) in Task { await session.selectSpace(id) } }
                        )) {
                            ForEach(session.spaces) { (space: Space) in
                                Text(space.name).tag(space.id)
                            }
                        }
                    }
                }
                Section {
                    Toggle("Verrouiller avec Face ID", isOn: $lock.isEnabled)
                } footer: {
                    Text("L'app se verrouille quand tu la quittes.")
                }
                Section("Serveur") {
                    LabeledContent("Adresse", value: session.serverURL)
                    LabeledContent("Version du serveur", value: serverVersion ?? "...")
                    LabeledContent("Version de l'app", value: appVersion)
                }
                Section {
                    Button("Se déconnecter", role: .destructive) {
                        Task { await session.logout() }
                    }
                }
            }
            .navigationTitle("Réglages")
            .task {
                serverVersion = (try? await session.client?.health())?.version ?? "inconnue"
            }
        }
    }

    private var appVersion: String {
        let info: [String: Any] = Bundle.main.infoDictionary ?? [:]
        let version: String = info["CFBundleShortVersionString"] as? String ?? "?"
        let build: String = info["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
