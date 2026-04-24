import Foundation
import SwiftData

@Model
final class DimensionState {
    var dimensionId: String
    var totalStrength: Double
    var level: Int
    var status: String  // "locked" | "signal" | "emerging" | "unlocked"
    var evidenceCount: Int
    var unlockedAt: Date?
    var lastUpdated: Date

    init(dimensionId: String) {
        self.dimensionId = dimensionId
        self.totalStrength = 0.0
        self.level = 0
        self.status = "locked"
        self.evidenceCount = 0
        self.unlockedAt = nil
        self.lastUpdated = Date()
    }

    // Signal glow intensity: 0.0 → 1.0, used for visual effect
    var glowIntensity: Double {
        switch status {
        case "locked": return 0.0
        case "signal": return min(totalStrength / 3.0, 0.6)
        case "emerging": return min(0.6 + (totalStrength - 3.0) / 10.0, 0.9)
        case "unlocked": return 1.0
        default: return 0.0
        }
    }

    func addStrength(_ amount: Double) {
        totalStrength += amount
        evidenceCount += 1
        lastUpdated = Date()
        updateStatus()
    }

    private func updateStatus() {
        let previousStatus = status
        if totalStrength >= 5.0 {
            status = "unlocked"
            if previousStatus != "unlocked" {
                unlockedAt = Date()
            }
        } else if totalStrength >= 2.0 {
            status = "emerging"
        } else if totalStrength >= 0.3 {
            status = "signal"
        }

        // Update level
        if let levelData = HamletFramework.shared.level(for: totalStrength) {
            level = levelData.number
        }
    }
}
