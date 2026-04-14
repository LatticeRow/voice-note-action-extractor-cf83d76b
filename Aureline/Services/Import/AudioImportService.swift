import Foundation
import SwiftData
import UniformTypeIdentifiers

enum AudioImportError: LocalizedError, Equatable {
    case invalidSelection
    case unsupportedType
    case missingFile
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .invalidSelection:
            return "Choose one audio file to import."
        case .unsupportedType:
            return "That file type isn’t supported."
        case .missingFile:
            return "The selected file is no longer available."
        case .unreadableFile:
            return "Aureline couldn’t read that file."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidSelection:
            return "Pick a single m4a, mp3, or wav file."
        case .unsupportedType:
            return "Choose an m4a, mp3, or wav file from Files."
        case .missingFile, .unreadableFile:
            return "Try importing the file again from Files."
        }
    }
}

@MainActor
struct AudioImportService {
    static let supportedContentTypes: [UTType] = [
        .mpeg4Audio,
        .mp3,
        .wav,
        .audio,
    ]

    func importAudio(
        from urls: [URL],
        repository: VoiceMemoRepository
    ) throws -> VoiceMemo {
        guard let sourceURL = urls.first else {
            throw AudioImportError.invalidSelection
        }

        let scopedAccessStarted = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if scopedAccessStarted {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw AudioImportError.missingFile
        }

        guard supportsImport(for: sourceURL) else {
            throw AudioImportError.unsupportedType
        }

        do {
            return try repository.createMemo(
                title: suggestedTitle(for: sourceURL),
                source: .imported,
                audioSourceURL: sourceURL,
                localeIdentifier: nil
            )
        } catch {
            throw AudioImportError.unreadableFile
        }
    }

    func supportsImport(for sourceURL: URL) -> Bool {
        if let contentType = try? sourceURL.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return Self.supportedContentTypes.contains { contentType.conforms(to: $0) }
        }

        let fallbackType = UTType(filenameExtension: sourceURL.pathExtension)
        guard let fallbackType else { return false }
        return Self.supportedContentTypes.contains { fallbackType.conforms(to: $0) }
    }

    func suggestedTitle(for sourceURL: URL) -> String {
        let rawName = sourceURL.deletingPathExtension().lastPathComponent
        let normalized = rawName
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.isEmpty {
            return "Imported Note"
        }

        return normalized.prefix(1).capitalized + String(normalized.dropFirst())
    }
}
