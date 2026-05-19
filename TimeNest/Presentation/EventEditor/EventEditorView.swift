import SwiftUI

enum EventEditorMode {
    case create(initialDate: Date)
    case edit(eventID: UUID, initialTitle: String, initialDate: Date, initialIsAllDay: Bool)
}

struct EventEditorView: View {
    @Binding var isPresented: Bool
    let mode: EventEditorMode
    var onSave: (String, Date, Bool) async throws -> Void

    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var isAllDay: Bool = false
    @State private var saving: Bool = false
    @State private var errorMessage: String?

    init(
        isPresented: Binding<Bool>,
        mode: EventEditorMode,
        onSave: @escaping (String, Date, Bool) async throws -> Void
    ) {
        _isPresented = isPresented
        self.mode = mode
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section {
                TextField("标题", text: $title)
            } header: {
                Text("基本信息")
            }

            Section {
                DatePicker("日期", selection: $date)
                Toggle("全天", isOn: $isAllDay)
            } header: {
                Text("时间")
            }

            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                } header: {
                    Text("错误")
                }
            }

            Section {
                Button("保存") {
                    Task {
                        await save()
                    }
                }
                .disabled(title.isEmpty || saving)
            }

            Section {
                Button("取消", role: .cancel) {
                    isPresented = false
                }
            }
        }
        .navigationTitle(isEditing ? "編集予定" : "新建予定")
        .disabled(saving)
        .onAppear {
            setupInitialState()
        }
    }

    private var isEditing: Bool {
        switch mode {
        case .create:
            return false
        case .edit:
            return true
        }
    }

    private func setupInitialState() {
        switch mode {
        case .create(let initialDate):
            title = ""
            date = initialDate
            isAllDay = false
        case .edit(_, let initialTitle, let initialDate, let initialIsAllDay):
            title = initialTitle
            date = initialDate
            isAllDay = initialIsAllDay
        }
    }

    private func save() async {
        saving = true
        errorMessage = nil

        do {
            try await onSave(title, date, isAllDay)
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
        }

        saving = false
    }
}

