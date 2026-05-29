import Foundation

protocol ParserClient {
    func parse(text: String) async throws -> ParserResponse
}

struct ParserResponse: Codable, Equatable {
    var parserVersion: String
    var reminders: [ParsedReminderDraft]
    var group: ParsedDraftGroup?
    var rawJSON: String?
}

struct ParsedReminderDraft: Codable, Equatable {
    var title: String
    var notes: String?
    var dueDate: String?
    var hasTime: Bool
    var recurrence: String?
    var priority: String
    var targetList: String?
    var labels: [String]
    var confidence: Double
    var ambiguityFlags: [String]
}

struct ParsedDraftGroup: Codable, Equatable {
    var title: String
    var mode: String
}

struct CloudParserClient: ParserClient {
    var endpoint: URL
    var apiKey: String
    var urlSession: URLSession = .shared

    func parse(text: String) async throws -> ParserResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["text": text])

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw ParserClientError.requestFailed
        }

        return try JSONDecoder().decode(ParserResponse.self, from: data)
    }
}

enum ParserClientError: Error {
    case requestFailed
}
