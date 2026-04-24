import Foundation
import Combine

// MARK: - Framework Models

struct HamletDimension: Codable, Identifiable {
    let id: String
    let nameZh: String
    let nameEn: String
    let nameJa: String
    let questionZh: String
    let questionEn: String
    let questionJa: String
    let color: String
    let icon: String

    enum CodingKeys: String, CodingKey {
        case id
        case nameZh = "name_zh"
        case nameEn = "name_en"
        case nameJa = "name_ja"
        case questionZh = "question_zh"
        case questionEn = "question_en"
        case questionJa = "question_ja"
        case color, icon
    }

    func localizedName() -> String {
        switch LanguageManager.shared.langCode {
        case "zh": return nameZh
        case "ja": return nameJa
        default: return nameEn
        }
    }

    func localizedQuestion() -> String {
        switch LanguageManager.shared.langCode {
        case "zh": return questionZh
        case "ja": return questionJa
        default: return questionEn
        }
    }
}

struct HamletArchetype: Codable, Identifiable {
    let id: String
    let nameZh: String
    let nameEn: String
    let nameJa: String
    let descriptionZh: String
    let primaryDimensions: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case nameZh = "name_zh"
        case nameEn = "name_en"
        case nameJa = "name_ja"
        case descriptionZh = "description_zh"
        case primaryDimensions = "primary_dimensions"
    }
}

struct LevelInfo: Codable {
    let nameZh: String
    let nameEn: String
    let range: [Double]

    enum CodingKeys: String, CodingKey {
        case nameZh = "name_zh"
        case nameEn = "name_en"
        case range
    }
}

struct FrameworkData: Codable {
    let version: String
    let dimensions: [HamletDimension]
    let archetypes: [HamletArchetype]
    let levels: [String: LevelInfo]
}

// MARK: - Framework Engine

class HamletFramework: ObservableObject {
    static let shared = HamletFramework()

    private(set) var dimensions: [HamletDimension] = []
    private(set) var archetypes: [HamletArchetype] = []
    private(set) var levels: [String: LevelInfo] = [:]

    private init() {
        load()
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "framework", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let framework = try? JSONDecoder().decode(FrameworkData.self, from: data)
        else { return }

        dimensions = framework.dimensions
        archetypes = framework.archetypes
        levels = framework.levels
    }

    func dimension(for id: String) -> HamletDimension? {
        dimensions.first { $0.id == id }
    }

    func level(for strength: Double) -> (number: Int, info: LevelInfo)? {
        for num in 1...8 {
            if let info = levels[String(num)],
               strength >= info.range[0] && strength < info.range[1] {
                return (num, info)
            }
        }
        return nil
    }
}
