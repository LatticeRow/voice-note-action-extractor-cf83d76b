import SwiftData
import SwiftUI

struct InboxView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Query(sort: \VoiceMemo.createdAt, order: .reverse) private var memos: [VoiceMemo]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if memos.isEmpty {
                    OnboardingView {
                        appEnvironment.router.openCapture()
                    }
                } else {
                    VStack(spacing: 14) {
                        ForEach(memos) { memo in
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
}
