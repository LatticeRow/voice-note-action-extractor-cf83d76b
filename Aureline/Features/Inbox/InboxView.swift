import SwiftData
import SwiftUI

struct InboxView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Query(sort: \VoiceMemo.createdAt, order: .reverse) private var memos: [VoiceMemo]
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if memos.isEmpty {
                    OnboardingView {
                        appEnvironment.router.openCapture()
                    }
                } else if filteredMemos.isEmpty {
                    AurelineStateView(
                        title: "No matches",
                        message: "Try a different title or clear the search.",
                        systemImage: "magnifyingglass",
                        tint: AurelinePalette.caution
                    )
                    .aurelineCard()
                } else {
                    summaryCard

                    VStack(spacing: 14) {
                        ForEach(filteredMemos) { memo in
                            MemoRowView(memo: memo)
                        }
                    }
                }
            }
            .padding(20)
        }
        .screenBackground()
        .navigationTitle("Inbox")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search notes")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Aureline")
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(Color.white)

            Text("Turn voice notes into next steps.")
                .foregroundStyle(AurelinePalette.secondaryText)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(filteredMemos.count) \(filteredMemos.count == 1 ? "note" : "notes")")
                .font(.headline)
                .foregroundStyle(Color.white)

            HStack(spacing: 10) {
                AurelineBadge(title: "\(count(for: .notStarted)) pending", tint: ProcessingStatus.notStarted.tint)
                AurelineBadge(title: "\(workingCount) working", tint: ProcessingStatus.processing.tint)
                AurelineBadge(title: "\(count(for: .failed)) failed", tint: ProcessingStatus.failed.tint)
            }

            Text("Open any note to add text or review next steps.")
                .foregroundStyle(AurelinePalette.secondaryText)
        }
        .aurelineCard()
    }

    private var filteredMemos: [VoiceMemo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return memos
        }

        return memos.filter { memo in
            memo.title.localizedCaseInsensitiveContains(query)
            || memo.source.title.localizedCaseInsensitiveContains(query)
            || (memo.transcriptText?.localizedCaseInsensitiveContains(query) ?? false)
            || memo.statusSummary.localizedCaseInsensitiveContains(query)
        }
    }

    private var workingCount: Int {
        memos.filter {
            $0.transcriptionStatus == .processing || $0.extractionStatus == .processing
        }.count
    }

    private func count(for status: ProcessingStatus) -> Int {
        memos.filter {
            $0.transcriptionStatus == status || $0.extractionStatus == status
        }.count
    }
}
