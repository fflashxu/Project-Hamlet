import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var theme: ThemeEngine
    @EnvironmentObject private var aiManager: AIProviderManager
    @EnvironmentObject private var languageManager: LanguageManager

    @State private var claudeKey = APIKeyStore.shared.get(for: .claude) ?? ""
    @State private var qwenKey = APIKeyStore.shared.get(for: .qwen) ?? ""
    @State private var showClaudeKey = false
    @State private var showQwenKey = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.theme.background.ignoresSafeArea()

                List {
                    // AI Provider
                    Section {
                        ForEach(AIProviderType.allCases) { provider in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(provider.displayName)
                                        .foregroundStyle(theme.theme.textPrimary)
                                    Text(provider.defaultModel)
                                        .font(.caption)
                                        .foregroundStyle(theme.theme.textTertiary)
                                }
                                Spacer()
                                if aiManager.selectedProvider == provider {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.theme.primary)
                                        .fontWeight(.semibold)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { aiManager.select(provider) }
                        }
                    } header: {
                        Text("AI Provider")
                            .foregroundStyle(theme.theme.textSecondary)
                    }

                    // API Keys
                    Section {
                        apiKeyRow(
                            label: "Claude API Key",
                            key: $claudeKey,
                            show: $showClaudeKey,
                            provider: .claude
                        )
                        apiKeyRow(
                            label: "Qwen API Key",
                            key: $qwenKey,
                            show: $showQwenKey,
                            provider: .qwen
                        )
                    } header: {
                        Text("API Keys")
                            .foregroundStyle(theme.theme.textSecondary)
                    } footer: {
                        Text("Keys are stored locally on your device only.")
                            .foregroundStyle(theme.theme.textTertiary)
                    }

                    // Theme
                    Section {
                        ForEach(ThemeType.allCases, id: \.rawValue) { themeType in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(themeType.displayName)
                                        .foregroundStyle(
                                            theme.unlockedThemes.contains(themeType)
                                            ? theme.theme.textPrimary
                                            : theme.theme.textTertiary
                                        )
                                    Text(themeType.unlockDescription)
                                        .font(.caption)
                                        .foregroundStyle(theme.theme.textTertiary)
                                }
                                Spacer()
                                if theme.current == themeType {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.theme.primary)
                                        .fontWeight(.semibold)
                                } else if !theme.unlockedThemes.contains(themeType) {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(theme.theme.textTertiary)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if theme.unlockedThemes.contains(themeType) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        theme.apply(themeType)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Theme")
                            .foregroundStyle(theme.theme.textSecondary)
                    }

                    // Language
                    Section {
                        ForEach(AppLanguage.allCases) { lang in
                            HStack {
                                Text(lang.displayName)
                                    .foregroundStyle(theme.theme.textPrimary)
                                Spacer()
                                if languageManager.current == lang {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.theme.primary)
                                        .fontWeight(.semibold)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { languageManager.set(lang) }
                        }
                    } header: {
                        Text("语言 / Language")
                            .foregroundStyle(theme.theme.textSecondary)
                    }

                    // About
                    Section {
                        HStack {
                            Text("Version")
                                .foregroundStyle(theme.theme.textPrimary)
                            Spacer()
                            Text("0.1.0")
                                .foregroundStyle(theme.theme.textTertiary)
                        }
                        HStack {
                            Text("Framework")
                                .foregroundStyle(theme.theme.textPrimary)
                            Spacer()
                            Text("Hamlet v1.0")
                                .foregroundStyle(theme.theme.textTertiary)
                        }
                    } header: {
                        Text("About")
                            .foregroundStyle(theme.theme.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private func apiKeyRow(
        label: String,
        key: Binding<String>,
        show: Binding<Bool>,
        provider: AIProviderType
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(theme.theme.textPrimary)
            HStack {
                if show.wrappedValue {
                    TextField("sk-...", text: key)
                        .font(.caption)
                        .foregroundStyle(theme.theme.textPrimary)
                } else {
                    SecureField("sk-...", text: key)
                        .font(.caption)
                        .foregroundStyle(theme.theme.textPrimary)
                }
                Button {
                    show.wrappedValue.toggle()
                } label: {
                    Image(systemName: show.wrappedValue ? "eye.slash" : "eye")
                        .foregroundStyle(theme.theme.textTertiary)
                }
                Button("Save") {
                    APIKeyStore.shared.save(key: key.wrappedValue, for: provider)
                }
                .font(.caption)
                .foregroundStyle(theme.theme.primary)
            }
        }
        .padding(.vertical, 4)
    }
}
