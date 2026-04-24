import SwiftUI
import SwiftData

struct DimensionsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var theme: ThemeEngine
    @EnvironmentObject private var languageManager: LanguageManager
    @Query private var dimensionStates: [DimensionState]

    private let framework = HamletFramework.shared

    var body: some View {
        NavigationStack {
            ZStack {
                theme.theme.background.ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(framework.dimensions) { dimension in
                            let state = state(for: dimension.id)
                            NavigationLink {
                                DimensionDetailView(dimension: dimension, state: state)
                            } label: {
                                DimensionCardView(dimension: dimension, state: state)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Dimensions")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func state(for id: String) -> DimensionState? {
        dimensionStates.first { $0.dimensionId == id }
    }
}

// MARK: - Dimension Card

struct DimensionCardView: View {
    @EnvironmentObject private var theme: ThemeEngine
    @EnvironmentObject private var languageManager: LanguageManager
    let dimension: HamletDimension
    let state: DimensionState?

    private var glowIntensity: Double { state?.glowIntensity ?? 0 }
    private var isUnlocked: Bool { state?.status == "unlocked" }
    private var hasSignal: Bool { (state?.totalStrength ?? 0) > 0 }
    private var dimColor: Color { Color(hex: dimension.color) }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Glow effect
                if glowIntensity > 0 {
                    Circle()
                        .fill(dimColor.opacity(glowIntensity * 0.3))
                        .frame(width: 64, height: 64)
                        .blur(radius: 8)
                }

                Circle()
                    .fill(isUnlocked ? dimColor.opacity(0.15) : theme.theme.surfaceSecondary)
                    .frame(width: 48, height: 48)

                Image(systemName: dimension.icon)
                    .font(.title3)
                    .foregroundStyle(isUnlocked ? dimColor : theme.theme.textTertiary)
                    .opacity(isUnlocked ? 1.0 : (hasSignal ? 0.5 : 0.25))
            }

            VStack(spacing: 4) {
                if isUnlocked {
                    Text(dimension.localizedName())
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(theme.theme.textPrimary)
                        .multilineTextAlignment(.center)
                } else if hasSignal {
                    // Blurred placeholder name
                    Text(dimension.localizedName())
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(theme.theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .blur(radius: 4)
                } else {
                    Text("• • •")
                        .font(.subheadline)
                        .foregroundStyle(theme.theme.textTertiary)
                }

                if let state = state, state.totalStrength > 0 {
                    levelIndicator(state: state)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(theme.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isUnlocked ? dimColor.opacity(0.4) : theme.theme.border,
                    lineWidth: isUnlocked ? 1.5 : 1
                )
        )
        .shadow(
            color: isUnlocked ? dimColor.opacity(glowIntensity * 0.2) : .clear,
            radius: 8, x: 0, y: 2
        )
    }

    @ViewBuilder
    private func levelIndicator(state: DimensionState) -> some View {
        HStack(spacing: 3) {
            ForEach(1...8, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i <= state.level ? dimColor : theme.theme.border)
                    .frame(width: 8, height: 3)
            }
        }
    }
}

// MARK: - Dimension Detail

struct DimensionDetailView: View {
    @EnvironmentObject private var theme: ThemeEngine
    @EnvironmentObject private var languageManager: LanguageManager
    @Query private var entries: [Entry]
    let dimension: HamletDimension
    let state: DimensionState?

    private var dimColor: Color { Color(hex: dimension.color) }
    private var isUnlocked: Bool { state?.status == "unlocked" }

    private var relatedEntries: [Entry] {
        entries.filter { entry in
            entry.signals.contains { $0.dimensionId == dimension.id }
        }
        .sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            theme.theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            if isUnlocked {
                                Circle()
                                    .fill(dimColor.opacity(0.2))
                                    .frame(width: 88, height: 88)
                                    .blur(radius: 12)
                            }
                            Circle()
                                .fill(isUnlocked ? dimColor.opacity(0.15) : theme.theme.surfaceSecondary)
                                .frame(width: 72, height: 72)
                            Image(systemName: dimension.icon)
                                .font(.largeTitle)
                                .foregroundStyle(isUnlocked ? dimColor : theme.theme.textTertiary)
                        }

                        if isUnlocked {
                            Text(dimension.localizedName())
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(theme.theme.textPrimary)
                            Text(dimension.localizedQuestion())
                                .font(.body)
                                .foregroundStyle(theme.theme.textSecondary)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Keep recording to reveal this dimension")
                                .font(.body)
                                .foregroundStyle(theme.theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 8)

                    // Level bar
                    if let state = state, state.totalStrength > 0 {
                        levelSection(state: state)
                    }

                    // Evidence entries
                    if !relatedEntries.isEmpty {
                        evidenceSection
                    }
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func levelSection(state: DimensionState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Level")
                .font(.headline)
                .foregroundStyle(theme.theme.textPrimary)

            HStack(spacing: 6) {
                ForEach(1...8, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(i <= state.level ? dimColor : theme.theme.border)
                        .frame(maxWidth: .infinity)
                        .frame(height: 6)
                }
            }

            if let levelInfo = HamletFramework.shared.level(for: state.totalStrength) {
                Text(levelInfo.info.nameEn)
                    .font(.caption)
                    .foregroundStyle(theme.theme.textSecondary)
            }
        }
        .padding(16)
        .background(theme.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.theme.border, lineWidth: 1))
    }

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Evidence")
                .font(.headline)
                .foregroundStyle(theme.theme.textPrimary)

            ForEach(relatedEntries.prefix(10)) { entry in
                if let signal = entry.signals.first(where: { $0.dimensionId == dimension.id }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(theme.theme.textTertiary)
                        Text("\u{201C}\(signal.evidence)\u{201D}")
                            .font(.body)
                            .foregroundStyle(theme.theme.textPrimary)
                            .italic()
                    }
                    .padding(12)
                    .background(theme.theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(dimColor.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
    }
}
