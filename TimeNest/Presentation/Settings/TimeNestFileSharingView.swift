import SwiftUI
import UniformTypeIdentifiers

/// 时间表文件共享视图
/// 提供导出和导入 .timenest 文件的功能
struct TimeNestFileSharingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager

    private let exportUseCase: TimeNestFileExportUseCase
    private let importUseCase: TimeNestFileImportUseCase

    init(
        exportUseCase: TimeNestFileExportUseCase = TimeNestFileExportUseCase(
            eventRepository: InMemoryEventRepository.shared
        ),
        importUseCase: TimeNestFileImportUseCase = TimeNestFileImportUseCase(
            eventRepository: InMemoryEventRepository.shared
        )
    ) {
        self.exportUseCase = exportUseCase
        self.importUseCase = importUseCase
    }

    @State private var isExporting: Bool = false
    @State private var isImporting: Bool = false
    @State private var shareURL: URL?
    @State private var importResult: TimeNestFileImportUseCase.ImportResult?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showFileImporter: Bool = false

    var body: some View {
        Form {
            // MARK: - Export Section
            Section {
                Button(action: {
                    Task {
                        await handleExport()
                    }
                }) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(localization.localized(.fileSharingExport))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isExporting ? Color.gray : Color.blue)
                    .cornerRadius(8)
                }
                .disabled(isExporting)
            } header: {
                Text(localization.localized(.fileSharingExportHeader))
            } footer: {
                Text(localization.localized(.fileSharingExportFooter))
            }

            // MARK: - Import Section
            Section {
                Button(action: {
                    showFileImporter = true
                }) {
                    HStack {
                        if isImporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(localization.localized(.fileSharingImport))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isImporting ? Color.gray : Color.orange)
                    .cornerRadius(8)
                }
                .disabled(isImporting)
            } header: {
                Text(localization.localized(.fileSharingImportHeader))
            } footer: {
                Text(localization.localized(.fileSharingImportFooter))
            }

            // MARK: - Import Result
            if let result = importResult {
                Section {
                    HStack {
                        Text(localization.localized(.fileSharingImportedCount))
                        Spacer()
                        Text("\(result.importedCount)")
                            .foregroundColor(.primary)
                    }

                    if result.skippedCount > 0 {
                        HStack {
                            Text(localization.localized(.fileSharingSkippedCount))
                            Spacer()
                            Text("\(result.skippedCount)")
                                .foregroundColor(.orange)
                        }
                    }
                } header: {
                    Text(localization.localized(.fileSharingImportResult))
                }
            }

            // MARK: - Info Section
            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text(localization.localized(.fileSharingInfo))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(localization.localized(.fileSharingTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                ModalHeaderCloseButton {
                    dismiss()
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.timenest],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await handleImportResult(result)
            }
        }
        .alert(localization.localized(.editorError), isPresented: $showError) {
            Button(localization.localized(.ok), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func handleExport() async {
        isExporting = true
        defer {
            isExporting = false
        }

        do {
            let url = try await exportUseCase.exportAllEvents(title: localization.localized(.fileSharingExportTitle))
            await MainActor.run {
                shareURL = url
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) async {
        isImporting = true
        defer {
            isImporting = false
        }

        do {
            let urls = try result.get()
            guard let url = urls.first else {
                throw URLError(.cancelled)
            }
            let importResult = try await importUseCase.importEvents(from: url)
            await MainActor.run {
                self.importResult = importResult
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - UTType Extension

extension UTType {
    static var timenest: UTType {
        UTType(filenameExtension: "timenest") ?? .data
    }
}
