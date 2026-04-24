import SwiftUI
import SwiftData

struct RecordView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var theme: ThemeEngine
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @State private var showingEditor = false
    @State private var selectedEntry: Entry?

    var body: some View {
        NavigationStack {
            ZStack {
                theme.theme.background.ignoresSafeArea()

                if entries.isEmpty {
                    emptyState
                } else {
                    entryList
                }
            }
            .navigationTitle("Hamlet")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(theme.theme.primary)
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                EntryEditorView()
            }
            .sheet(item: $selectedEntry) { entry in
                EntryDetailView(entry: entry)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 48))
                .foregroundStyle(theme.theme.textTertiary)
            Text("记录今天发生的事情")
                .font(.body)
                .foregroundStyle(theme.theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("开始记录") {
                showingEditor = true
            }
            .buttonStyle(.bordered)
            .tint(theme.theme.primary)
        }
        .padding(40)
    }

    private var entryList: some View {
        List {
            ForEach(entries) { entry in
                EntryRowView(entry: entry)
                    .listRowBackground(theme.theme.background)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .onTapGesture {
                        selectedEntry = entry
                    }
            }
            .onDelete(perform: deleteEntries)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
    }
}

// MARK: - Entry Row

struct EntryRowView: View {
    @EnvironmentObject private var theme: ThemeEngine
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(theme.theme.textTertiary)
                Spacer()
                if entry.aiProcessed {
                    signalBadges
                } else if !entry.content.isEmpty {
                    processingIndicator
                }
            }

            Text(entry.content)
                .font(.body)
                .foregroundStyle(theme.theme.textPrimary)
                .lineLimit(4)
        }
        .padding(16)
        .background(theme.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.theme.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var signalBadges: some View {
        if !entry.signals.isEmpty {
            HStack(spacing: 4) {
                ForEach(entry.signals.prefix(3), id: \.dimensionId) { signal in
                    if let dim = HamletFramework.shared.dimension(for: signal.dimensionId) {
                        Circle()
                            .fill(Color(hex: dim.color))
                            .frame(width: 8, height: 8)
                    }
                }
                if entry.signals.count > 3 {
                    Text("+\(entry.signals.count - 3)")
                        .font(.caption2)
                        .foregroundStyle(theme.theme.textTertiary)
                }
            }
        }
    }

    private var processingIndicator: some View {
        Text("analyzing…")
            .font(.caption2)
            .foregroundStyle(theme.theme.textTertiary)
    }
}

// MARK: - Entry Detail View

struct EntryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeEngine
    @EnvironmentObject private var languageManager: LanguageManager
    let entry: Entry
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // Date & input type
                        HStack {
                            Text(entry.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(theme.theme.textTertiary)
                            Text("·")
                                .foregroundStyle(theme.theme.textTertiary)
                            Text(entry.inputType)
                                .font(.caption)
                                .foregroundStyle(theme.theme.textTertiary)
                            Spacer()
                        }

                        // Content
                        Text(entry.content)
                            .font(.body)
                            .foregroundStyle(theme.theme.textPrimary)

                        // Attached URLs
                        if !entry.attachedURLs.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("链接")
                                    .font(.caption)
                                    .foregroundStyle(theme.theme.textTertiary)
                                ForEach(entry.attachedURLs, id: \.self) { url in
                                    Link(url, destination: URL(string: url) ?? URL(string: "https://")!)
                                        .font(.caption)
                                        .foregroundStyle(theme.theme.primary)
                                        .lineLimit(1)
                                }
                            }
                        }

                        Divider().background(theme.theme.border)

                        // AI signals
                        if entry.aiProcessed && !entry.signals.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("能力信号")
                                    .font(.headline)
                                    .foregroundStyle(theme.theme.textPrimary)

                                ForEach(entry.signals, id: \.dimensionId) { signal in
                                    if let dim = HamletFramework.shared.dimension(for: signal.dimensionId) {
                                        HStack(alignment: .top, spacing: 10) {
                                            Circle()
                                                .fill(Color(hex: dim.color))
                                                .frame(width: 10, height: 10)
                                                .padding(.top, 5)
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack {
                                                    Text(dim.localizedName())
                                                        .font(.subheadline)
                                                        .fontWeight(.medium)
                                                        .foregroundStyle(theme.theme.textPrimary)
                                                    Spacer()
                                                    Text(String(format: "%.0f%%", signal.strength * 100))
                                                        .font(.caption)
                                                        .foregroundStyle(theme.theme.textTertiary)
                                                }
                                                Text("\u{201C}\(signal.evidence)\u{201D}")
                                                    .font(.caption)
                                                    .foregroundStyle(theme.theme.textSecondary)
                                                    .italic()
                                            }
                                        }
                                        .padding(12)
                                        .background(theme.theme.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color(hex: dim.color).opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        } else if !entry.aiProcessed {
                            Text("AI 分析中…")
                                .font(.caption)
                                .foregroundStyle(theme.theme.textTertiary)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("记录详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(theme.theme.textSecondary)
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .confirmationDialog("删除这条记录？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    modelContext.delete(entry)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }
}
