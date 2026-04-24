//
//  ContentView.swift
//  Hamlet
//
//  Created by Harry Xu on 2026/4/24.
//

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject private var theme: ThemeEngine

    var body: some View {
        TabView {
            RecordView()
                .tabItem {
                    Label("Record", systemImage: "square.and.pencil")
                }

            DimensionsView()
                .tabItem {
                    Label("Dimensions", systemImage: "sparkles")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(theme.theme.primary)
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeEngine.shared)
        .environmentObject(AIProviderManager.shared)
        .environmentObject(LanguageManager.shared)
}
