import LocalAuthentication
import SwiftUI

/// Locks the app when it goes to the background and asks Face ID (or the passcode) on return.
@MainActor
@Observable
final class AppLock {
    private(set) var isLocked: Bool
    private(set) var isAuthenticating: Bool = false

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "lockEnabled") }
    }

    init() {
        let stored: Bool? = UserDefaults.standard.object(forKey: "lockEnabled") as? Bool
        // On by default, but never in a scripted debug launch (screenshots, UI checks).
        let enabled: Bool = DebugLaunch.login == nil && (stored ?? true)
        isEnabled = enabled
        isLocked = enabled
    }

    func lockIfEnabled() {
        if isEnabled { isLocked = true }
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        let context: LAContext = LAContext()
        var error: NSError?
        // No passcode set on the device: nothing to check against, so do not lock the user out.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isLocked = false
            return
        }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            isLocked = !(try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Déverrouille tes comptes"))
        } catch {
            isLocked = true
        }
    }
}

struct LockScreen: View {
    let lock: AppLock

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Comptes verrouillés")
                .font(.title2.bold())
            Button("Déverrouiller") {
                Task { await lock.unlock() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
