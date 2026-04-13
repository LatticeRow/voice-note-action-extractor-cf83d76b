import SwiftData

enum ModelContainerProvider {
    static func makeDefaultContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)

        do {
            return try ModelContainer(
                for: VoiceMemo.self,
                TranscriptSegment.self,
                ExtractedActionItem.self,
                ExtractedMention.self,
                configurations: configuration
            )
        } catch {
            fatalError("Unable to create the SwiftData container: \(error)")
        }
    }
}
