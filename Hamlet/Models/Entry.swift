import Foundation
import SwiftData

@Model
final class Entry {
    var id: String
    var date: Date
    var content: String
    var inputType: String  // "text" | "voice" | "image" | "video" | "file" | "url"
    var lang: String
    var aiProcessed: Bool
    var signals: [SignalData]
    var attachmentPaths: [String]  // local file paths for image/video/file attachments
    var attachedURLs: [String]     // web URLs to fetch and analyze
    var urlContents: [String]      // fetched plaintext from each URL (parallel index)

    init(content: String, inputType: String = "text") {
        self.id = "\(DateFormatter.entryId.string(from: Date()))-\(UUID().uuidString.prefix(6))"
        self.date = Date()
        self.content = content
        self.inputType = inputType
        self.lang = Locale.current.language.languageCode?.identifier ?? "en"
        self.aiProcessed = false
        self.signals = []
        self.attachmentPaths = []
        self.attachedURLs = []
        self.urlContents = []
    }
}

// Stored as JSON string in SwiftData, decoded on access
struct SignalData: Codable {
    let dimensionId: String
    let strength: Double
    let evidence: String

    enum CodingKeys: String, CodingKey {
        case dimensionId = "dimension_id"
        case strength
        case evidence
    }
}

extension DateFormatter {
    static let entryId: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let display: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
