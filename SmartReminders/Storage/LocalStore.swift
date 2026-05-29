import Foundation

struct LocalStore {
    private let fileURL: URL

    init(directory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.fileURL = directory.appendingPathComponent("parse-sessions.json")
    }

    func loadSessions() throws -> [ParseSession] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.smartReminders.decode([ParseSession].self, from: data)
    }

    func save(_ session: ParseSession) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var sessions = try loadSessions()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }

        let data = try JSONEncoder.smartReminders.encode(sessions)
        try data.write(to: fileURL, options: [.atomic])
    }
}
