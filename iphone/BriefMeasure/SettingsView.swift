import SwiftUI

struct SettingsView: View {
    @ObservedObject var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) var dismiss
    var onResetQuestionnaire: (() -> Void)?

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

                Section(header: Text("About")) {
                    Text("Get a daily reminder to complete your questionnaire.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
