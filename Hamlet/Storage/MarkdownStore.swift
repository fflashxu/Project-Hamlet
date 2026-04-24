import Foundation

// Writes and reads entry data as .md files with YAML frontmatter
// Files live in: Documents/HamletEntries/YYYY-MM/entry-id.md

class MarkdownStore {
    static let shared = MarkdownStore()

    private let baseURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        baseURL = docs.appendingPathComponent("HamletEntries")
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    func save(_ entry: Entry) throws {
        let folder = monthFolder(for: entry.date)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let url = folder.appendingPathComponent("\(entry.id).md")
        let content = render(entry)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func delete(id: String, date: Date) {
        let url = monthFolder(for: date).appendingPathComponent("\(id).md")
        try? FileManager.default.removeItem(at: url)
    }

    private func monthFolder(for date: Date) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return baseURL.appendingPathComponent(formatter.string(from: date))
    }

    private func render(_ entry: Entry) -> String {
        var frontmatter = """
        ---
        id: \(entry.id)
        date: \(ISO8601DateFormatter().string(from: entry.date))
        lang: \(entry.lang)
        input_type: \(entry.inputType)
        ai_processed: \(entry.aiProcessed)
        """

        if !entry.signals.isEmpty {
            frontmatter += "\nsignals:"
            for signal in entry.signals {
                frontmatter += """
                \n  - dimension_id: \(signal.dimensionId)
                    strength: \(String(format: "%.2f", signal.strength))
                    evidence: "\(signal.evidence.replacingOccurrences(of: "\"", with: "\\\""))"
                """
            }
        }

        frontmatter += "\n---\n\n"
        return frontmatter + entry.content
    }
}
