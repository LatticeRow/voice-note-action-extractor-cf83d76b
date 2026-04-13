import SwiftData
import XCTest
@testable import Aureline

@MainActor
final class AurelineTests: XCTestCase {
    func testPlaceholderMemoStartsInInboxState() throws {
        let container = ModelContainerProvider.makeDefaultContainer(inMemory: true)
        let repository = VoiceMemoRepository(modelContext: ModelContext(container))

        let memo = repository.createPlaceholderMemo(source: .recorded)

        XCTAssertEqual(memo.source, .recorded)
        XCTAssertEqual(memo.transcriptionStatus, .notStarted)
        XCTAssertEqual(memo.extractionStatus, .notStarted)
        XCTAssertNil(memo.transcriptText)
    }

    func testPlaceholderExtractionBuildsReviewData() throws {
        let container = ModelContainerProvider.makeDefaultContainer(inMemory: true)
        let repository = VoiceMemoRepository(modelContext: ModelContext(container))

        let memo = repository.createPlaceholderMemo(source: .imported)
        repository.addPlaceholderExtraction(to: memo)

        XCTAssertEqual(memo.transcriptionStatus, .completed)
        XCTAssertEqual(memo.extractionStatus, .completed)
        XCTAssertEqual(memo.actionItems.count, 2)
        XCTAssertEqual(memo.mentions.count, 2)
    }
}
