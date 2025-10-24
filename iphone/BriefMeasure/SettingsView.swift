import SwiftUI

struct SettingsView: View {
    @ObservedObject var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) var dismiss
    var onResetQuestionnaire: (() -> Void)?
    @AppStorage("apiKeyEndpoint") private var apiKeyEndpoint: String = "https://localhost:3000/api/v1/keys"
    @State private var apiKeyEndpointText: String = ""
    @State private var isFetchingApiKey = false
    @State private var apiKeyStatus: String?
    @State private var isApiKeyStatusError = false
    @State private var storedApiKeySummary: String?
    @State private var didLoadInitialValues = false
    private let apiKeyService = ApiKeyService()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Daily Notifications")) {
                    Toggle("Enable Daily Reminder", isOn: $notificationManager.notificationsEnabled)

                    if notificationManager.notificationsEnabled {
                        DatePicker("Notification Time",
                                 selection: $notificationManager.notificationTime,
                                 displayedComponents: .hourAndMinute)
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
                    TextField("API Key Endpoint", text: Binding(
                        get: { apiKeyEndpointText },
                        set: { newValue in
                            apiKeyEndpointText = newValue
                            apiKeyEndpoint = newValue
                        }
                    ))
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
                    .disabled(isFetchingApiKey)

                    if let status = apiKeyStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(isApiKeyStatusError ? .red : .secondary)
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
                    apiKeyEndpointText = apiKeyEndpoint
                    refreshStoredKeySummary()
                    didLoadInitialValues = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func fetchApiKey() {
        let trimmedEndpoint = apiKeyEndpointText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let endpointURL = URL(string: trimmedEndpoint) else {
            apiKeyStatus = ApiKeyServiceError.invalidEndpoint.localizedDescription
            isApiKeyStatusError = true
            return
        }

        apiKeyEndpoint = trimmedEndpoint
        isFetchingApiKey = true
        apiKeyStatus = "Requesting a new API key…"
        isApiKeyStatusError = false

        Task {
            do {
                let apiKey = try await apiKeyService.fetchApiKey(from: endpointURL)
                try apiKeyService.storeApiKey(apiKey)
                await MainActor.run {
                    storedApiKeySummary = summarizedKey(apiKey)
                    apiKeyStatus = "API key saved to the Keychain."
                    isApiKeyStatusError = false
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
                    apiKeyStatus = description
                    isApiKeyStatusError = true
                    isFetchingApiKey = false
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
}

#Preview {
    SettingsView()
}
