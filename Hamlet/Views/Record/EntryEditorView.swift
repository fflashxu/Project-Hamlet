import SwiftUI
import SwiftData
import Speech
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

struct EntryEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeEngine
    @EnvironmentObject private var aiManager: AIProviderManager

    // Text
    @State private var text = ""

    // Voice
    @State private var isRecording = false
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()

    // Image
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var attachedImageData: Data?

    // Video
    @State private var showVideoPicker = false
    @State private var attachedVideoURL: URL?

    // File
    @State private var showFilePicker = false
    @State private var attachedFileURL: URL?
    @State private var attachedFileName: String?

    // URL input
    @State private var showURLInput = false
    @State private var urlInputText = ""
    @State private var attachedURLs: [String] = []
    @State private var isFetchingURL = false

    // Processing
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                theme.theme.background.ignoresSafeArea()

                VStack(spacing: 0) {

                    // Main text editor
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $text)
                            .font(.body)
                            .foregroundStyle(theme.theme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .padding(16)

                        if text.isEmpty {
                            Text("记录今天发生了什么——你做的一件事、面对的挑战，或让你印象深刻的时刻……")
                                .font(.body)
                                .foregroundStyle(theme.theme.textTertiary)
                                .padding(22)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Attachments preview
                    attachmentsPreview

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 4)
                    }

                    Divider().background(theme.theme.border)

                    // URL input bar (inline, shown when URL mode active)
                    if showURLInput {
                        urlInputBar
                    }

                    // Bottom toolbar
                    bottomToolbar
                }
            }
            .navigationTitle("新记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(theme.theme.textSecondary)
                }
            }
            .sheet(isPresented: $showVideoPicker) {
                VideoPicker(selectedVideoURL: $attachedVideoURL)
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf, .plainText, .rtf, .data],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    attachedFileURL = url
                    attachedFileName = url.lastPathComponent
                }
            }
        }
    }

    // MARK: - Attachments Preview

    @ViewBuilder
    private var attachmentsPreview: some View {
        let hasAttachments = attachedImageData != nil || attachedVideoURL != nil
            || attachedFileURL != nil || !attachedURLs.isEmpty

        if hasAttachments {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {

                    // Image
                    if let imageData = attachedImageData, let uiImage = UIImage(data: imageData) {
                        attachmentChip {
                            attachedImageData = nil
                        } content: {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    // Video
                    if let videoURL = attachedVideoURL {
                        attachmentChip {
                            attachedVideoURL = nil
                        } content: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.theme.surfaceSecondary)
                                    .frame(width: 56, height: 56)
                                VStack(spacing: 2) {
                                    Image(systemName: "video.fill")
                                        .foregroundStyle(theme.theme.primary)
                                    Text(videoURL.lastPathComponent)
                                        .font(.system(size: 8))
                                        .foregroundStyle(theme.theme.textTertiary)
                                        .lineLimit(1)
                                        .frame(width: 48)
                                }
                            }
                        }
                    }

                    // File
                    if let fileName = attachedFileName {
                        attachmentChip {
                            attachedFileURL = nil
                            attachedFileName = nil
                        } content: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.theme.surfaceSecondary)
                                    .frame(width: 56, height: 56)
                                VStack(spacing: 2) {
                                    Image(systemName: "doc.fill")
                                        .foregroundStyle(theme.theme.primary)
                                    Text(fileName)
                                        .font(.system(size: 8))
                                        .foregroundStyle(theme.theme.textTertiary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 48)
                                }
                            }
                        }
                    }

                    // URLs
                    ForEach(attachedURLs, id: \.self) { url in
                        attachmentChip {
                            attachedURLs.removeAll { $0 == url }
                        } content: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.theme.surfaceSecondary)
                                    .frame(width: 56, height: 56)
                                VStack(spacing: 2) {
                                    Image(systemName: "link")
                                        .foregroundStyle(theme.theme.primary)
                                    Text(url)
                                        .font(.system(size: 8))
                                        .foregroundStyle(theme.theme.textTertiary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 48)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }

    @ViewBuilder
    private func attachmentChip<Content: View>(
        onRemove: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            content()
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .offset(x: 6, y: -6)
        }
    }

    // MARK: - URL Input Bar

    private var urlInputBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .foregroundStyle(theme.theme.textTertiary)
                .font(.footnote)

            TextField("粘贴网址…", text: $urlInputText)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.footnote)
                .foregroundStyle(theme.theme.textPrimary)
                .onSubmit { addURL() }

            if isFetchingURL {
                ProgressView().scaleEffect(0.75)
            } else {
                Button("添加") { addURL() }
                    .font(.footnote)
                    .tint(theme.theme.primary)
                    .disabled(urlInputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Button {
                showURLInput = false
                urlInputText = ""
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote)
                    .foregroundStyle(theme.theme.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.theme.surfaceSecondary)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 16) {
            // Voice
            Button {
                toggleRecording()
            } label: {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle")
                    .font(.title2)
                    .foregroundStyle(isRecording ? .red : theme.theme.textSecondary)
            }

            // Photo
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(theme.theme.textSecondary)
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        attachedImageData = data
                    }
                }
            }

            // Video
            Button {
                showVideoPicker = true
            } label: {
                Image(systemName: "video.circle")
                    .font(.title2)
                    .foregroundStyle(attachedVideoURL != nil ? theme.theme.primary : theme.theme.textSecondary)
            }

            // File
            Button {
                showFilePicker = true
            } label: {
                Image(systemName: "doc.circle")
                    .font(.title2)
                    .foregroundStyle(attachedFileURL != nil ? theme.theme.primary : theme.theme.textSecondary)
            }

            // URL
            Button {
                showURLInput.toggle()
            } label: {
                Image(systemName: "link.circle")
                    .font(.title2)
                    .foregroundStyle(!attachedURLs.isEmpty ? theme.theme.primary : theme.theme.textSecondary)
            }

            Spacer()

            if isProcessing {
                ProgressView().tint(theme.theme.primary)
            } else {
                Button("保存") {
                    Task { await save() }
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.theme.primary)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachedURLs.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Add URL

    private func addURL() {
        let raw = urlInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        let urlStr = raw.hasPrefix("http") ? raw : "https://\(raw)"
        guard URL(string: urlStr) != nil else {
            errorMessage = "网址格式不正确"
            return
        }
        attachedURLs.append(urlStr)
        urlInputText = ""
        showURLInput = false
        errorMessage = nil
    }

    // MARK: - Save & AI Processing

    private func save() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasContent = !trimmed.isEmpty || !attachedURLs.isEmpty
        guard hasContent else { return }

        isProcessing = true
        errorMessage = nil

        // Determine inputType
        let inputType: String
        if attachedVideoURL != nil { inputType = "video" }
        else if attachedFileURL != nil { inputType = "file" }
        else if !attachedURLs.isEmpty && trimmed.isEmpty { inputType = "url" }
        else if isRecording { inputType = "voice" }
        else if attachedImageData != nil { inputType = "image" }
        else { inputType = "text" }

        let entry = Entry(content: trimmed.isEmpty ? attachedURLs.joined(separator: "\n") : trimmed,
                          inputType: inputType)
        entry.attachedURLs = attachedURLs

        // Fetch URL content (multimodal: text + image/video/audio URLs)
        var urlContext = ""
        var fetchedURLContents: [String] = []
        for urlStr in attachedURLs {
            if let page = try? await URLFetcher.shared.fetch(from: urlStr) {
                let context = page.aiContext
                fetchedURLContents.append(context)
                urlContext += "\n\n\(context)"
            } else {
                fetchedURLContents.append("")
            }
        }
        entry.urlContents = fetchedURLContents

        // Extract file text if attached
        var fileContext = ""
        if let fileURL = attachedFileURL {
            _ = fileURL.startAccessingSecurityScopedResource()
            if let fileText = try? String(contentsOf: fileURL, encoding: .utf8) {
                fileContext = "\n\n[File: \(fileURL.lastPathComponent)]\n\(String(fileText.prefix(3000)))"
            }
            fileURL.stopAccessingSecurityScopedResource()
        }

        modelContext.insert(entry)
        try? MarkdownStore.shared.save(entry)

        let additionalContext = (urlContext + fileContext).trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let provider = aiManager.currentProvider()
            let signals: [SignalData]
            if additionalContext.isEmpty {
                signals = try await provider.extractSignals(from: entry.content)
            } else {
                signals = try await provider.extractSignals(from: entry.content, additionalContext: additionalContext)
            }

            entry.signals = signals
            entry.aiProcessed = true

            for signal in signals {
                updateDimensionState(dimensionId: signal.dimensionId, strength: signal.strength)
            }
            try? MarkdownStore.shared.save(entry)
        } catch AIError.missingAPIKey {
            errorMessage = "请在设置中添加 API Key 以启用 AI 分析"
            entry.aiProcessed = false
        } catch {
            entry.aiProcessed = false
        }

        isProcessing = false
        dismiss()
    }

    private func updateDimensionState(dimensionId: String, strength: Double) {
        let descriptor = FetchDescriptor<DimensionState>(
            predicate: #Predicate { $0.dimensionId == dimensionId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.addStrength(strength)
        } else {
            let state = DimensionState(dimensionId: dimensionId)
            state.addStrength(strength)
            modelContext.insert(state)
        }
    }

    // MARK: - Voice Recording

    private func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }
            DispatchQueue.main.async { self.beginAudioSession() }
        }
    }

    private func beginAudioSession() {
        let request = SFSpeechAudioBufferRecognitionRequest()
        let node = audioEngine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        try? audioEngine.start()
        isRecording = true
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, _ in
            if let result = result {
                DispatchQueue.main.async { self.text = result.bestTranscription.formattedString }
            }
        }
    }

    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        isRecording = false
    }
}

// MARK: - Video Picker

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var selectedVideoURL: URL?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.mediaTypes = ["public.movie"]
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: VideoPicker
        init(_ parent: VideoPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let url = info[.mediaURL] as? URL {
                parent.selectedVideoURL = url
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
