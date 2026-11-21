import SwiftUI

struct LoginView: View {
    @Environment(SessionStore.self) private var session: SessionStore
    @State private var server: String = SharedStore.serverURL ?? ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var error: String?
    @State private var isSubmitting: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://comptes.exemple.fr", text: $server)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Serveur")
                } footer: {
                    Text("L'adresse du site Bank tracking, en HTTPS.")
                }
                Section("Compte") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Mot de passe", text: $password)
                        .textContentType(.password)
                }
                if let message: String = error ?? session.notice {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text("Se connecter").bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSubmitting || server.isEmpty || email.isEmpty || password.isEmpty)
                }
            }
            .navigationTitle("Comptes")
        }
    }

    private func submit() async {
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }
        do {
            try await session.login(server: server, email: email, password: password)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
