import SwiftUI

struct SettingsView: View {
    enum Presentation {
        case sheet
        case routerOverlay
    }

    var presentation: Presentation = .sheet

    @Environment(AppEnvironment.self) var environment
    @Environment(AppRouter.self) var router
    @Environment(\.dismiss) var dismiss

    @State var draft = UserProfile.empty()
    @State var weightText = ""
    @State var heightText = ""
    @State var ageText = ""
    @State var proteinText = ""
    @State var limitationNotes = ""
    @State var authEmail = ""
    @State var authPassword = ""
    @State var authError: String?
    @State var saveError: String?
    @State var isSaving = false
    @State var showEquipmentPicker = false
    @State var showLimitations = false
    @State var showMusclePreferences = false
    @State var didLoad = false
    @State var showDeleteDataConfirmation = false
    @State var isDeletingAccount = false
    @State var deleteError: String?
    @State var isExporting = false
    @State var exportError: String?
    @State var showExportShareSheet = false
    @State var exportShareItems: [Any] = []

    let sessionLengths = GenerationConstants.Session.preferredSessionLengthOptions

    var body: some View {
        Group {
            if presentation == .sheet {
                NavigationStack { settingsBody }
            } else {
                settingsBody
            }
        }
    }

    private var settingsBody: some View {
        VStack(spacing: 0) {
            ForgeScreenHeader(
                title: "Settings",
                style: .compact,
                eyebrow: "App",
                subtitle: "Profile, account, and preferences.",
                leading: {
                    if presentation == .routerOverlay {
                        ForgeHeaderBackButton { router.dismissRoute() }
                    }
                },
                trailing: {
                    Button(isSaving ? "Saving…" : "Done") {
                        Task { await finish() }
                    }
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.accent)
                    .disabled(isSaving)
                    .accessibilityIdentifier("settings.done")
                    .accessibilityAddTraits(.isButton)
                }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let saveError {
                        Text(saveError)
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.destructive)
                    }

                    if PersonalUseConfig.shouldShowCloudAccountUI(
                        supabaseConfigured: environment.isSupabaseConfigured
                    ) {
                        accountSection
                        cloudSection
                    }

                    trainingSection
                    sessionStructureSection
                    equipmentLimitsSection
                    musclePreferencesSection
                    scheduleSection
                    bodySection
                    proteinSection
                    limitationsSection
                    integrationsSection
                    appSection
                }
                .padding(.horizontal, ForgeSpacing.s5)
                .padding(.vertical, ForgeSpacing.s5)
            }
        }
        .background(ForgeColors.background)
        .forgeScreenNavigationHidden()
        .sheet(isPresented: $showEquipmentPicker) { equipmentPicker }
        .confirmationDialog(
            deleteConfirmationTitle,
            isPresented: $showDeleteDataConfirmation,
            titleVisibility: .visible
        ) {
            Button(deleteConfirmationActionTitle, role: .destructive) {
                Task { await performDeleteUserData() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteConfirmationMessage)
        }
        .sheet(isPresented: $showExportShareSheet) {
            ShareSheet(items: exportShareItems)
        }
        .onAppear(perform: loadDraft)
        .accessibilityIdentifier("settings.root")
    }
}

#Preview {
    SettingsView()
        .environment(AppEnvironment())
        .environment(AppRouter())
}
