import Foundation

private struct ObservationPayload: Codable, Identifiable {
    let id: UUID
    let uuidv7: String
    let observation: String
    let createdAt: Date
}

private struct ObservationRequest: Codable {
    let uuidv7: String
    let observation: String
}

actor ObservationUploader {
    static let shared = ObservationUploader()

    private var queue: [ObservationPayload]
    private var isUploading = false
    private var retryTask: Task<Void, Never>?
    private var currentRetryDelay: TimeInterval
    private var lastErrorMessage: String?

    private let storageURL: URL
    private let apiKeyService = ApiKeyService()
    private let baseRetryDelay: TimeInterval = 60
    private let maxRetryDelay: TimeInterval = 86_400
    private let maxRetention: TimeInterval = 86_400

    private init() {
        let fileManager = FileManager.default
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            storageURL = documentsURL.appendingPathComponent("observation-queue.json")
        } else {
            storageURL = fileManager.temporaryDirectory.appendingPathComponent("observation-queue.json")
        }

        queue = ObservationUploader.loadQueue(from: storageURL)
        currentRetryDelay = baseRetryDelay
        lastErrorMessage = nil

        let initialPending = queue.count
        Task { @MainActor in
            ObservationStatus.shared.update(
                pendingCount: initialPending,
                nextRetry: nil,
                errorMessage: nil
            )
        }
    }

    func recordObservation(responses: [Int: Int]) async {
        guard let observationString = ObservationUploader.observationString(from: responses) else {
            print("Observation upload skipped: invalid response set")
            return
        }

        let payload = ObservationPayload(
            id: UUID(),
            uuidv7: UUID.v7String(),
            observation: observationString,
            createdAt: Date()
        )

        queue.append(payload)
        persistQueue()
        await MainActor.run {
            ObservationStatus.shared.clearLimitMessage()
        }
        await reportStatus(nextRetry: nil, error: nil)
        await uploadPending()
    }

    func retryUpload() async {
        await uploadPending()
    }

    func configurationDidChange() async {
        retryTask?.cancel()
        retryTask = nil
        resetBackoff()
        await uploadPending()
    }

    func clearQueue() async {
        queue.removeAll()
        persistQueue()
        retryTask?.cancel()
        retryTask = nil
        resetBackoff()
        lastErrorMessage = nil
        await MainActor.run {
            ObservationStatus.shared.clearLimitMessage()
        }
        await reportStatus(nextRetry: nil, error: nil)
    }

    private func uploadPending() async {
        guard !queue.isEmpty else {
            await reportStatus(nextRetry: nil, error: lastErrorMessage)
            return
        }
        guard !isUploading else { return }

        isUploading = true
        retryTask?.cancel()
        retryTask = nil
        defer { isUploading = false }

        pruneExpiredEntries()
        await reportStatus(nextRetry: nil, error: lastErrorMessage)

        while let next = queue.first {
            if Date().timeIntervalSince(next.createdAt) > maxRetention {
                queue.removeFirst()
                persistQueue()
                lastErrorMessage = "Dropped an expired upload."
                await reportStatus(nextRetry: nil, error: lastErrorMessage)
                continue
            }

            guard let request = makeRequest(for: next) else {
                lastErrorMessage = "Upload configuration incomplete."
                await reportStatus(nextRetry: nil, error: lastErrorMessage)
                return
            }

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Observation upload failed with unknown response")
                    lastErrorMessage = "Upload failed due to an unknown response."
                    await reportStatus(nextRetry: nil, error: lastErrorMessage)
                    await scheduleRetry()
                    return
                }

                switch httpResponse.statusCode {
                case 200...299:
                    queue.removeFirst()
                    persistQueue()
                    lastErrorMessage = nil
                    await MainActor.run {
                        ObservationStatus.shared.clearLimitMessage()
                    }
                    await reportStatus(nextRetry: nil, error: nil)
                    resetBackoff()
                case 429:
                    print("Observation upload rejected with 429 Too Many Requests")
                    let limitMessage = "You are answering too quickly. Please wait before submitting again."
                    lastErrorMessage = limitMessage
                    queue.removeFirst()
                    persistQueue()
                    resetBackoff()
                    await reportStatus(nextRetry: nil, error: lastErrorMessage)
                    await MainActor.run {
                        ObservationStatus.shared.reportLimitExceeded(message: limitMessage)
                    }
                    return
                default:
                    print("Observation upload failed with status \(httpResponse.statusCode)")
                    lastErrorMessage = "Upload failed with status \(httpResponse.statusCode)."
                    await reportStatus(nextRetry: nil, error: lastErrorMessage)
                    await scheduleRetry()
                    return
                }
            } catch {
                print("Observation upload error: \(error.localizedDescription)")
                lastErrorMessage = "Upload error: \(error.localizedDescription)"
                await reportStatus(nextRetry: nil, error: lastErrorMessage)
                await scheduleRetry()
                return
            }
        }

        resetBackoff()
        await reportStatus(nextRetry: nil, error: lastErrorMessage)
    }

    private func makeRequest(for payload: ObservationPayload) -> URLRequest? {
        let baseString = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "https://localhost:3000/api/v1/"
        guard let baseURL = URL(string: baseString) else {
            return nil
        }

        guard let apiKey = apiKeyService.loadApiKey() else {
            return nil
        }

        let endpoint = baseURL.appendingPathComponent("observations")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = ObservationRequest(uuidv7: payload.uuidv7, observation: payload.observation)
        let encoder = JSONEncoder()
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            print("Failed to encode observation: \(error.localizedDescription)")
            return nil
        }

        return request
    }

    private func persistQueue() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(queue)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            print("Failed to persist observation queue: \(error.localizedDescription)")
        }
    }

    private static func loadQueue(from url: URL) -> [ObservationPayload] {
        guard let data = try? Data(contentsOf: url) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode([ObservationPayload].self, from: data)
        } catch {
            print("Failed to decode observation queue: \(error.localizedDescription)")
            return []
        }
    }

    private static func observationString(from responses: [Int: Int]) -> String? {
        var characters: [Character] = []
        for question in QuestionBank.questions {
            guard let answer = responses[question.id], (1...4).contains(answer) else {
                return nil
            }
            guard let scalar = UnicodeScalar(48 + answer) else {
                return nil
            }
            characters.append(Character(scalar))
        }
        return String(characters)
    }

    private func pruneExpiredEntries() {
        let now = Date()
        let originalCount = queue.count
        queue.removeAll { payload in
            now.timeIntervalSince(payload.createdAt) > maxRetention
        }
        if queue.count != originalCount {
            persistQueue()
            let dropped = originalCount - queue.count
            lastErrorMessage = "Dropped \(dropped) expired upload\(dropped == 1 ? "" : "s")."
        }
    }

    private func scheduleRetry() async {
        let delay = currentRetryDelay
        let nextRetryDate = Date().addingTimeInterval(delay)
        retryTask?.cancel()
        retryTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                return
            }
            guard !Task.isCancelled else {
                return
            }
            await self.retryAfterDelay()
        }
        currentRetryDelay = min(currentRetryDelay * 2, maxRetryDelay)
        await reportStatus(nextRetry: nextRetryDate, error: lastErrorMessage)
    }

    private func retryAfterDelay() async {
        retryTask = nil
        await uploadPending()
    }

    private func resetBackoff() {
        currentRetryDelay = baseRetryDelay
    }

    private func reportStatus(nextRetry: Date?, error: String?) async {
        let pending = queue.count
        await MainActor.run {
            ObservationStatus.shared.update(
                pendingCount: pending,
                nextRetry: nextRetry,
                errorMessage: error
            )
        }
    }
}
