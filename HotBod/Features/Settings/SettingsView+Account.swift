import SwiftUI

extension SettingsView {
    var accountSection: some View {
        SettingsComponents.section(title: "Account", subtitle: "Sign in to sync") {
            if environment.isSignedIn {
                SettingsComponents.valueRow(label: "Signed in", value: environment.authEmail ?? "—")
                SettingsComponents.actionRow(title: "Sync Now") {
                    Task { await environment.syncNow() }
                }
                SettingsComponents.actionRow(title: "Sign Out", destructive: true) {
                    Task { try? await environment.signOut() }
                }
                SettingsComponents.divider
                deleteDataActionRow(title: "Delete Account", identifier: "settings.deleteAccount")
            } else {
                ForgeTextField(label: "Email", text: $authEmail, keyboardType: .emailAddress)
                    .textInputAutocapitalization(.never)
                ForgeTextField(label: "Password", text: $authPassword, isSecure: true)
                SettingsComponents.actionRow(title: "Sign In") { Task { await performSignIn() } }
                SettingsComponents.actionRow(title: "Create Account") { Task { await performSignUp() } }
                SettingsComponents.divider
                deleteDataActionRow(title: "Delete All Data", identifier: "settings.deleteAllData")
            }

            if let deleteError {
                Text(deleteError)
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.destructive)
            }

            if let authError {
                Text(authError)
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.destructive)
            }
            if let syncMessage = environment.syncMessage {
                Text(userFacingSyncMessage(syncMessage))
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.muted)
            }
        }
    }

    var cloudSection: some View {
        SettingsComponents.section(title: "Cloud Backup", subtitle: "Progress photos") {
            SettingsComponents.toggleRow(
                title: "Photo cloud backup",
                isOn: Binding(
                    get: { environment.photoCloudBackupEnabled },
                    set: { enabled in Task { await environment.setPhotoCloudBackup(enabled) } }
                )
            )
            Text("Photos stay local unless you enable backup while signed in.")
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
        }
    }

    private func userFacingSyncMessage(_ message: String) -> String {
        let normalized = message.lowercased()
        if normalized.contains("sync complete") || normalized.contains("data synced") {
            return "You're signed in and up to date."
        }
        if normalized.contains("sign in to sync") {
            return "Sign in to sync your data."
        }
        if normalized.contains("signed out") {
            return "Signed out."
        }
        if normalized.contains("error") || normalized.contains("failed") {
            return "Sync could not complete. Please try again."
        }
        return message
    }

    func performSignIn() async {
        authError = nil
        do {
            try await environment.signIn(email: authEmail, password: authPassword)
        } catch {
            authError = userFacingAuthError(error)
        }
    }

    func performSignUp() async {
        authError = nil
        do {
            try await environment.signUp(email: authEmail, password: authPassword)
        } catch {
            authError = userFacingAuthError(error)
        }
    }

    private func userFacingAuthError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("password") || message.contains("credential") {
            return "Could not sign in. Check your email and password."
        }
        if message.contains("network") || message.contains("internet") || message.contains("offline") {
            return "No connection. Try again when you are back online."
        }
        return "Something went wrong while signing in. Please try again."
    }

    func deleteDataActionRow(title: String, identifier: String) -> some View {
        SettingsComponents.actionRow(title: isDeletingAccount ? "Deleting…" : title, destructive: true) {
            guard !isDeletingAccount else { return }
            deleteError = nil
            showDeleteDataConfirmation = true
        }
        .disabled(isDeletingAccount)
        .accessibilityIdentifier(identifier)
    }

    var deleteConfirmationTitle: String {
        environment.isSignedIn ? "Delete Account?" : "Delete All Data?"
    }

    var deleteConfirmationActionTitle: String {
        environment.isSignedIn ? "Delete Account" : "Delete All Data"
    }

    var deleteConfirmationMessage: String {
        if environment.isSignedIn {
            return "This permanently deletes your cloud account and removes all data from this device. This cannot be undone."
        }
        return "This permanently removes all workouts, progress, and settings from this device. This cannot be undone."
    }

    func performDeleteUserData() async {
        deleteError = nil
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            if environment.isSignedIn {
                try await environment.deleteAccount()
            } else {
                try await environment.wipeAllLocalUserData()
            }
            dismissSettings()
            router.showOnboarding()
        } catch {
            deleteError = userFacingDeleteError(error)
        }
    }

    private func userFacingDeleteError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("network") || message.contains("internet") || message.contains("offline") {
            return "No connection. Try again when you are back online."
        }
        return "Could not delete your data. Please try again."
    }
}
