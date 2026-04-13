import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    var body: some View {
        @Bindable var router = appEnvironment.router

        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.inboxPath) {
                InboxView()
                    .navigationDestination(for: AppDestination.self) { destination in
                        switch destination {
                        case let .detail(memoID):
                            MemoDetailScene(memoID: memoID)
                        }
                    }
            }
            .tabItem {
                Label("Inbox", systemImage: "tray.full.fill")
            }
            .tag(AppTab.inbox)

            NavigationStack {
                RecordImportView()
            }
            .tabItem {
                Label("Capture", systemImage: "waveform.badge.mic")
            }
            .tag(AppTab.capture)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "slider.horizontal.3")
            }
            .tag(AppTab.settings)
        }
        .tint(AurelinePalette.accent)
        .background(AurelinePalette.background.ignoresSafeArea())
    }
}

private struct MemoDetailScene: View {
    @Query private var memos: [VoiceMemo]
    let memoID: UUID

    init(memoID: UUID) {
        self.memoID = memoID
        _memos = Query(filter: #Predicate<VoiceMemo> { memo in
            memo.id == memoID
        })
    }

    var body: some View {
        if let memo = memos.first {
            MemoDetailView(memo: memo)
        } else {
            ContentUnavailableView(
                "Memo Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("This note is no longer in your inbox.")
            )
            .screenBackground()
        }
    }
}
