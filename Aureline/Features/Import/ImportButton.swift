import SwiftUI
import UniformTypeIdentifiers

struct ImportButton: View {
    let title: String
    let supportedContentTypes: [UTType]
    let accessibilityIdentifier: String
    let action: ([URL]) -> Void
    let failure: (Error) -> Void

    @State private var isImporterPresented = false

    var body: some View {
        Button(title) {
            isImporterPresented = true
        }
        .accessibilityIdentifier(accessibilityIdentifier)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: supportedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                action(urls)
            case let .failure(error):
                failure(error)
            }
        }
    }
}
