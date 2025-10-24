import Foundation
import Security

enum ApiKeyServiceError: LocalizedError {
    case invalidEndpoint
    case invalidResponseStatus(Int)
    case decodingFailed
    case invalidApiKey
    case keychainSaveFailed(OSStatus)

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
        }
    }
}

private struct ApiKeyResponseDTO: Decodable {
    let api_key: String
}

struct ApiKeyService {
    private static let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func fetchApiKey(from endpoint: URL) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

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
