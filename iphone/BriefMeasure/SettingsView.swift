import SwiftUI

struct SettingsView: View {
    @ObservedObject var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) var dismiss
    var onResetQuestionnaire: (() -> Void)?

    @AppStorage("apiBaseURL") private var apiBaseURL: String = "https://localhost:3000/api/v1/"
    @State private var apiEndpointInput: String = ""
    @State private var isFetchingApiKey = false
    @State private var isPerformingForgetMe = false
    @State private var apiStatusMessage: String?
    @State private var apiStatusIsError = false
    @State private var storedApiKeySummary: String?
    @State private var didLoadInitialValues = false

    private let apiKeyService = ApiKeyService()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Daily Notifications")) {
                    Toggle("Enable Daily Reminder", isOn: $notificationManager.notificationsEnabled)

                    if notificationManager.notificationsEnabled {
                        DatePicker(
                            "Notification Time",
                            selection: $notificationManager.notificationTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                }

                Section(header: Text("Questionnaire")) {
                    Button(action: {
                        onResetQuestionnaire?()
                        dismiss()
                    }) {
                        HStack {
                            Text("Reset Daily Questionnaire")
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.blue)
                        }
                    }
                }

                Section(header: Text("API Access")) {
                    TextField("API Base URL or /keys endpoint", text: $apiEndpointInput)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                    Button(action: fetchApiKey) {
                        if isFetchingApiKey {
                            ProgressView()
                        } else {
                            Text("Fetch New API Key")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(isFetchingApiKey || isPerformingForgetMe)

                    Button(role: .destructive, action: forgetMe) {
                        if isPerformingForgetMe {
                            ProgressView()
                        } else {
                            Text("Forget Me")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(isPerformingForgetMe || isFetchingApiKey)

                    if let status = apiStatusMessage {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(apiStatusIsError ? .red : .secondary)
                    }

                    if let summary = storedApiKeySummary {
                        Text("Stored key: \(summary)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Stored key: none")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("About")) {
                    Text("Get a daily reminder to complete your questionnaire.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !didLoadInitialValues {
                    migrateLegacyEndpointIfNeeded()
                    apiEndpointInput = apiBaseURL
                    refreshStoredKeySummary()
                    didLoadInitialValues = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        persistBaseInput()
                        dismiss()
                    }
                }
            }
        }
    }

    private func fetchApiKey() {
        guard !isFetchingApiKey, !isPerformingForgetMe else { return }

        let input = apiEndpointInput.isEmpty ? apiBaseURL : apiEndpointInput
        let endpoints: ApiEndpoints
        do {
            endpoints = try ApiKeyService.deriveEndpoints(from: input)
        } catch {
            apiStatusMessage = ApiKeyServiceError.invalidEndpoint.localizedDescription
            apiStatusIsError = true
            return
        }

        apiEndpointInput = endpoints.base.absoluteString
        apiBaseURL = endpoints.base.absoluteString

        if apiKeyService.loadApiKey() != nil {
            apiStatusMessage = "Please use Forget Me before requesting a new API key."
            apiStatusIsError = true
            return
        }

        Task {
            await ObservationUploader.shared.configurationDidChange()
        }

        isFetchingApiKey = true
        apiStatusMessage = "Requesting a new API key…"
        apiStatusIsError = false

        Task {
            do {
                let apiKey = try await apiKeyService.fetchApiKey(at: endpoints.keys)
                try apiKeyService.storeApiKey(apiKey)
                await ObservationUploader.shared.configurationDidChange()
                await MainActor.run {
                    storedApiKeySummary = summarizedKey(apiKey)
                    apiStatusMessage = "API key saved to the Keychain."
                    apiStatusIsError = false
                    isFetchingApiKey = false
                }
            } catch {
                let description: String
                if let serviceError = error as? ApiKeyServiceError {
                    description = serviceError.localizedDescription
                } else {
                    description = error.localizedDescription
                }
                await MainActor.run {
                    apiStatusMessage = description
                    apiStatusIsError = true
                    isFetchingApiKey = false
                }
            }
        }
    }

    private func forgetMe() {
        guard !isPerformingForgetMe, !isFetchingApiKey else { return }

        let input = apiEndpointInput.isEmpty ? apiBaseURL : apiEndpointInput
        let endpoints: ApiEndpoints
        do {
            endpoints = try ApiKeyService.deriveEndpoints(from: input)
        } catch {
            apiStatusMessage = ApiKeyServiceError.invalidEndpoint.localizedDescription
            apiStatusIsError = true
            return
        }

        guard let apiKey = apiKeyService.loadApiKey() else {
            apiStatusMessage = ApiKeyServiceError.missingApiKey.localizedDescription
            apiStatusIsError = true
            return
        }

        apiEndpointInput = endpoints.base.absoluteString
        apiBaseURL = endpoints.base.absoluteString

        isPerformingForgetMe = true
        apiStatusMessage = "Sending forget-me request…"
        apiStatusIsError = false

        Task {
            do {
                try await apiKeyService.forgetMe(at: endpoints.forgetMe, apiKey: apiKey)
                try apiKeyService.deleteApiKey()
                await ObservationUploader.shared.clearQueue()
                await MainActor.run {
                    storedApiKeySummary = nil
                    apiStatusMessage = "Forget-me completed. Stored data removed."
                    apiStatusIsError = false
                    isPerformingForgetMe = false
                }
            } catch {
                let description: String
                if let serviceError = error as? ApiKeyServiceError {
                    description = serviceError.localizedDescription
                } else {
                    description = error.localizedDescription
                }
                await MainActor.run {
                    apiStatusMessage = description
                    apiStatusIsError = true
                    isPerformingForgetMe = false
                }
            }
        }
    }

    private func refreshStoredKeySummary() {
        if let key = apiKeyService.loadApiKey() {
            storedApiKeySummary = summarizedKey(key)
        } else {
            storedApiKeySummary = nil
        }
    }

    private func summarizedKey(_ key: String) -> String {
        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        return "\(prefix)…\(suffix)"
    }

    private func persistBaseInput() {
        let trimmed = apiEndpointInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let endpoints = try? ApiKeyService.deriveEndpoints(from: trimmed) {
            apiEndpointInput = endpoints.base.absoluteString
            if apiBaseURL != endpoints.base.absoluteString {
                apiBaseURL = endpoints.base.absoluteString
                Task {
                    await ObservationUploader.shared.configurationDidChange()
                }
            }
        }
    }

    private func migrateLegacyEndpointIfNeeded() {
        let defaults = UserDefaults.standard
        guard let legacy = defaults.string(forKey: "apiKeyEndpoint") else { return }

        if let endpoints = try? ApiKeyService.deriveEndpoints(from: legacy) {
            let newBase = endpoints.base.absoluteString
            if apiBaseURL != newBase {
                apiBaseURL = newBase
                Task {
                    await ObservationUploader.shared.configurationDidChange()
                }
            }
        }

        defaults.removeObject(forKey: "apiKeyEndpoint")
    }
}

#Preview {
    SettingsView()
}
