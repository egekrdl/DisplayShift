import SwiftUI

struct UpdatesPanel: View {
    @ObservedObject var updates: PrivateUpdates
    @State private var token = ""

    var body: some View {
        Form {
            Section("Private GitHub Releases") {
                Text("Create a fine-grained GitHub token for the DisplayShift repository with Contents: Read-only. DisplayShift keeps it in your Mac’s Keychain.")
                    .foregroundStyle(.secondary)
                Link("Manage fine-grained tokens", destination: URL(string: "https://github.com/settings/personal-access-tokens")!)
                SecureField("GitHub access token", text: $token)
                    .onSubmit(save)
                HStack {
                    Button("Save Access", action: save).disabled(token.isEmpty || updates.checking)
                    Button("Remove Access") { updates.removeToken() }.disabled(!updates.hasToken || updates.checking)
                }
            }
            Section("Software Updates") {
                Button("Check for Updates…") { updates.check() }
                    .disabled(updates.checking)
                if updates.checking { ProgressView().controlSize(.small) }
                if let message = updates.message { Text(message).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
    }

    private func save() {
        guard !updates.checking, !token.isEmpty else { return }
        updates.saveToken(token)
        token = ""
    }
}
