import SwiftData
import SwiftUI

struct RecordImportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var statusMessage = "Choose a source."
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Capture")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(Color.white)

                Text("Add a note.")
                    .foregroundStyle(AurelinePalette.secondaryText)

                VStack(alignment: .leading, spacing: 14) {
                    Label("Stored on this iPhone", systemImage: "lock.shield.fill")
                        .font(.headline)
                        .foregroundStyle(Color.white)

                    Text(statusMessage)
                        .foregroundStyle(AurelinePalette.secondaryText)
                }
                .aurelineCard()

                Button("Add Recording") {
                    createDemoMemo(source: .recorded)
                }
                .buttonStyle(AurelinePrimaryButtonStyle())
                .accessibilityIdentifier("capture.recordDraft")

                Button("Import File") {
                    createDemoMemo(source: .imported)
                }
                .buttonStyle(AurelineSecondaryButtonStyle())
                .accessibilityIdentifier("capture.importDraft")

                VStack(alignment: .leading, spacing: 10) {
                    Text("Permissions")
                        .font(.headline)
                        .foregroundStyle(Color.white)

                    Text("Access stays off until you use it.")
                        .foregroundStyle(AurelinePalette.secondaryText)
                }
                .aurelineCard()
            }
            .padding(20)
        }
        .screenBackground()
        .navigationTitle("Capture")
        .navigationBarTitleDisplayMode(.large)
        .alert("Couldn’t save note", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Try again.")
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private func createDemoMemo(source: MemoSource) {
        do {
            let memo = try VoiceMemoRepository(modelContext: modelContext).createDemoMemo(source: source)
            statusMessage = "Saved “\(memo.title)”."
        } catch {
            errorMessage = "Aureline couldn’t save the note. Try again."
        }
    }
}
