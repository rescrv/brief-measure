import Foundation
import Security

enum ApiKeyServiceError: LocalizedError {
    case invalidEndpoint
    case invalidResponseStatus(Int)
    case decodingFailed
    case invalidApiKey
    case keychainSaveFailed(OSStatus)
    case missingApiKey

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "The API endpoint URL is invalid."
        case .invalidResponseStatus(let code):
            return "Unexpected response status: \(code)."
        case .decodingFailed:
            return "Could not decode the API response."
        case .invalidApiKey:
            return "Received an invalid API key."
        case .keychainSaveFailed(let status):
            return "Failed to store the API key (status \(status))."
        case .missingApiKey:
            return "No API key is stored."
        }
    }
}

struct ApiEndpoints {
    let base: URL
    let keys: URL
    let observations: URL
    let forgetMe: URL
}

private struct ApiKeyResponseDTO: Decodable {
    let api_key: String
}

private struct EmptyRequest: Encodable {}

struct ApiKeyService {
    private static let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
    private let urlSession: URLSession

    init(urlSession: URLSession = URLSession(configuration: .default)) {
        self.urlSession = urlSession
    }

    static func deriveEndpoints(from input: String) throws -> ApiEndpoints {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ApiKeyServiceError.invalidEndpoint
        }

        guard var url = URL(string: trimmed) else {
            throw ApiKeyServiceError.invalidEndpoint
        }

        if url.lastPathComponent.isEmpty, url.path != "/" {
            url = url.deletingLastPathComponent()
        }

        let lastComponent = url.lastPathComponent.lowercased()
        if ["keys", "observations", "forget-me-now"].contains(lastComponent) {
            url = url.deletingLastPathComponent()
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil

        guard let sanitized = components?.url else {
            throw ApiKeyServiceError.invalidEndpoint
        }

        var baseString = sanitized.absoluteString
        if !baseString.hasSuffix("/") {
            baseString.append("/")
        }

        guard let baseURL = URL(string: baseString) else {
            throw ApiKeyServiceError.invalidEndpoint
        }

        let keysURL = baseURL.appendingPathComponent("keys")
        let observationsURL = baseURL.appendingPathComponent("observations")
        let forgetMeURL = baseURL.appendingPathComponent("forget-me-now")

        return ApiEndpoints(base: baseURL, keys: keysURL, observations: observationsURL, forgetMe: forgetMeURL)
    }

    func fetchApiKey(at endpoint: URL) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(EmptyRequest())

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiKeyServiceError.invalidResponseStatus(-1)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ApiKeyServiceError.invalidResponseStatus(httpResponse.statusCode)
        }

        guard let apiKey = try? JSONDecoder().decode(ApiKeyResponseDTO.self, from: data).api_key else {
            throw ApiKeyServiceError.decodingFailed
        }

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidApiKey(trimmedKey) else {
            throw ApiKeyServiceError.invalidApiKey
        }

        return trimmedKey.lowercased()
    }

    func forgetMe(at endpoint: URL, apiKey: String) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiKeyServiceError.invalidResponseStatus(-1)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ApiKeyServiceError.invalidResponseStatus(httpResponse.statusCode)
        }
    }

    func storeApiKey(_ apiKey: String, label: String = "API_KEY") throws {
        let data = Data(apiKey.utf8)

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: label,
            kSecAttrService as String: "BriefMeasure",
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let status = SecItemCopyMatching(baseQuery as CFDictionary, nil)
        if status == errSecSuccess {
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw ApiKeyServiceError.keychainSaveFailed(updateStatus)
            }
        } else if status == errSecItemNotFound {
            var addQuery = baseQuery
            attributes.forEach { key, value in addQuery[key] = value }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw ApiKeyServiceError.keychainSaveFailed(addStatus)
            }
        } else {
            throw ApiKeyServiceError.keychainSaveFailed(status)
        }
    }

    func deleteApiKey(label: String = "API_KEY") throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: label,
            kSecAttrService as String: "BriefMeasure",
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw ApiKeyServiceError.keychainSaveFailed(status)
        }
    }

    func loadApiKey(label: String = "API_KEY") -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: label,
            kSecAttrService as String: "BriefMeasure",
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let apiKey = String(data: data, encoding: .utf8),
              Self.isValidApiKey(apiKey) else {
            return nil
        }

        return apiKey
    }

    private static func isValidApiKey(_ value: String) -> Bool {
        guard value.count == 64 else {
            return false
        }
        return value.unicodeScalars.allSatisfy { hexCharacterSet.contains($0) }
    }
}
