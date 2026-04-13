import SwiftData
import SwiftUI

struct RecordImportView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @State private var statusMessage = "Add a note to your inbox from a fresh recording or an imported file."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Capture")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(Color.white)

                Text("Start from a fresh recording or bring in an existing file.")
                    .foregroundStyle(AurelinePalette.secondaryText)

                VStack(alignment: .leading, spacing: 14) {
                    Label("Local-first by design", systemImage: "lock.shield.fill")
                        .font(.headline)
                        .foregroundStyle(Color.white)

                    Text(statusMessage)
                        .foregroundStyle(AurelinePalette.secondaryText)
                }
                .aurelineCard()

                Button("Add Recorded Note") {
                    let memo = VoiceMemoRepository(modelContext: modelContext).createPlaceholderMemo(source: .recorded)
                    statusMessage = "Added “\(memo.title)” to the inbox."
                }
                .buttonStyle(AurelinePrimaryButtonStyle())
                .accessibilityIdentifier("capture.recordDraft")

                Button("Add Imported Note") {
                    let memo = VoiceMemoRepository(modelContext: modelContext).createPlaceholderMemo(source: .imported)
                    statusMessage = "Added “\(memo.title)” to the inbox."
                }
                .buttonStyle(AurelineSecondaryButtonStyle())
                .accessibilityIdentifier("capture.importDraft")

                VStack(alignment: .leading, spacing: 10) {
                    Text("Permissions")
                        .font(.headline)
                        .foregroundStyle(Color.white)

                    Text("Microphone, speech recognition, and reminders remain off until you choose those actions.")
                        .foregroundStyle(AurelinePalette.secondaryText)
                }
                .aurelineCard()
            }
            .padding(20)
        }
        .screenBackground()
        .navigationTitle("Capture")
        .navigationBarTitleDisplayMode(.large)
    }
}
