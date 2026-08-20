import SwiftUI

struct SettingsPage: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    @State private var authService = AuthService.shared
    @State private var userProfile = UserProfileService.shared
    @ObservedObject private var config = PrototypeConfig.shared
    @ObservedObject private var merchantService = RemoteMerchantService.shared
    @State private var customHandlesText: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                authSection
                merchantSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .disabled(merchantService.isLoading)
                }
            }
            .overlay {
                if merchantService.isLoading {
                    loadingOverlay
                }
            }
            .onChange(of: config.merchantSource) { _, _ in
                Task { await merchantService.loadMerchants(force: true) }
            }
        }
        .interactiveDismissDisabled(merchantService.isLoading)
        .purlInjectable()
    }

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Reloading merchants…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Fetching brand assets and products for \(config.merchantLimit) merchants")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(PurlTune.value("Pages/SettingsPage.swift:padding:_:52:18", default: 32))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(PurlTune.value("Pages/SettingsPage.swift:opacity:_:55:41", default: 0.1)))
        .allowsHitTesting(true)
    }

    // MARK: - Auth Section

    @ViewBuilder
    private var authSection: some View {
        Section {
            if authService.hasSession {
                // Current state: Shop Account
                HStack(spacing: 12) {
                    if let url = userProfile.avatarURL {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.purple.opacity(PurlTune.value("Pages/SettingsPage.swift:opacity:_:71:64", default: 0.2)))
                                .overlay(Text(userProfile.initial).font(.headline).foregroundStyle(.purple))
                        }
                        .frame(width: PurlTune.value("Pages/SettingsPage.swift:frame:width:74:39", default: 44), height: PurlTune.value("Pages/SettingsPage.swift:frame:height:74:122", default: 44))
                        .clipShape(Circle())
                    } else {
                        Image("luke-avatar")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(userProfile.displayName)
                            .font(.headline)
                        if let email = authService.userEmail {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Shop Account · ~90 day session")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, PurlTune.value("Pages/SettingsPage.swift:padding:_:95:37", default: 4))

                Button("Sign Out", role: .destructive) {
                    authService.signOut()
                    ShopPostService.shared.reset()
                    userProfile.applyFallbackProfile()
                    merchantService.loadFallbackData()
                }
            } else {
                // Current state: Sample Data
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Using Sample Data")
                            .font(.headline)
                        Text("Bundled JSON snapshot · no expiry")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "tray.full.fill")
                        .foregroundStyle(.orange)
                }

                Button("Sign in with Shop account") {
                    Task {
                        await authService.signIn()
                        if authService.hasSession {
                            await UserProfileService.shared.fetch()
                            await merchantService.loadMerchants(force: true)
                            await ShopPostService.shared.loadLukePosts(force: true)
                        }
                    }
                }
            }
        } header: {
            Text("Authentication")
        } footer: {
            if authService.hasSession {
                Text("Signed in via Shop Server OAuth. Access token refreshes automatically. Session lasts ~90 days.")
            } else {
                Text("Using bundled merchant snapshot. No network required.")
            }
        }
    }

    // MARK: - Merchant Section

    @ViewBuilder
    private var merchantSection: some View {
        Section {
            if authService.hasSession {
                Picker("Source", selection: $config.merchantSource) {
                    ForEach(MerchantSource.allCases, id: \.self) { source in
                        Text(source.rawValue).tag(source)
                    }
                }

                if config.merchantSource == .custom {
                    TextField("Handles (comma-separated)", text: $customHandlesText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { applyCustomHandles() }
                        .onAppear { customHandlesText = config.merchantHandles.joined(separator: ", ") }
                }
            } else {
                Text("Sign in with Shop account to choose merchant source.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Stepper("Merchant limit: \(config.merchantLimit)", value: $config.merchantLimit, in: 1...50)
            Stepper("Products per merchant: \(config.productsPerMerchant)", value: $config.productsPerMerchant, in: 1...50)
        } header: {
            Text("Merchants")
        } footer: {
            switch config.merchantSource {
            case .followed:
                Text("Loads merchants you follow on Shop. Requires Shop account sign-in.")
            case .discovery:
                Text("Loads top merchants from shopWebMerchantDiscovery.")
            case .custom:
                Text("Loads specific merchants by handle (e.g. allbirds, gymshark).")
            }
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section {
            Button {
                Task { await merchantService.loadMerchants(force: true) }
            } label: {
                HStack {
                    Label("Reload Merchants", systemImage: "arrow.clockwise")
                    if merchantService.isLoading {
                        Spacer()
                        ProgressView().scaleEffect(0.8)
                    }
                }
            }
            .disabled(merchantService.isLoading)

            if !merchantService.merchants.isEmpty {
                HStack {
                    Text("Loaded merchants")
                    Spacer()
                    Text("\(merchantService.merchants.count)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Total products")
                    Spacer()
                    Text("\(merchantService.merchants.reduce(0) { $0 + $1.products.count })")
                        .foregroundStyle(.secondary)
                }
            }

            if let error = merchantService.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Data")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Auth method")
                Spacer()
                Text(authService.hasSession ? "Shop OAuth" : "Sample JSON")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Token expiry")
                Spacer()
                Text(authService.hasSession ? "~90 days (auto-refresh)" : "Never")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Helpers

    private func applyCustomHandles() {
        config.merchantHandles = customHandlesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

#Preview {
    SettingsPage()
        .environment(NavigationCoordinator())
}
