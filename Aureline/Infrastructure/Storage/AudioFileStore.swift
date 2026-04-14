import AVFoundation
import Foundation

struct StoredAudioFile {
    let relativePath: String
    let originalFilename: String?
    let durationSeconds: Double
}

struct PendingAudioDeletion {
    fileprivate let originalURL: URL
    fileprivate let stagedURL: URL
}

struct AudioFileStore {
    private let fileManager: FileManager
    private let customApplicationSupportDirectory: URL?

    init(fileManager: FileManager = .default, applicationSupportDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.customApplicationSupportDirectory = applicationSupportDirectory
    }

    func importAudio(from sourceURL: URL, memoID: UUID) throws -> StoredAudioFile {
        let destinationURL = try destinationURL(for: sourceURL, memoID: memoID)
        try ensureStorageDirectoriesExist()

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        if sourceURL.standardizedFileURL != destinationURL.standardizedFileURL {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }

        let relativePath = relativeAudioPath(for: destinationURL.lastPathComponent)
        return StoredAudioFile(
            relativePath: relativePath,
            originalFilename: sourceURL.lastPathComponent.isEmpty ? nil : sourceURL.lastPathComponent,
            durationSeconds: durationSeconds(for: destinationURL)
        )
    }

    func fileURL(for relativePath: String) throws -> URL {
        try applicationSupportDirectory().appendingPathComponent(relativePath, isDirectory: false)
    }

    func deleteAudio(atRelativePath relativePath: String) throws {
        guard !relativePath.isEmpty else { return }
        let fileURL = try fileURL(for: relativePath)
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    func prepareForDeletion(atRelativePath relativePath: String) throws -> PendingAudioDeletion? {
        guard !relativePath.isEmpty else { return nil }

        let originalURL = try fileURL(for: relativePath)
        guard fileManager.fileExists(atPath: originalURL.path) else { return nil }

        try ensureStorageDirectoriesExist()
        let stagedURL = try trashDirectory()
            .appendingPathComponent("\(UUID().uuidString)-\(originalURL.lastPathComponent)", isDirectory: false)

        if fileManager.fileExists(atPath: stagedURL.path) {
            try fileManager.removeItem(at: stagedURL)
        }

        try fileManager.moveItem(at: originalURL, to: stagedURL)
        return PendingAudioDeletion(originalURL: originalURL, stagedURL: stagedURL)
    }

    func commitDeletion(_ pendingDeletion: PendingAudioDeletion?) throws {
        guard let pendingDeletion, fileManager.fileExists(atPath: pendingDeletion.stagedURL.path) else { return }
        try fileManager.removeItem(at: pendingDeletion.stagedURL)
    }

    func rollbackDeletion(_ pendingDeletion: PendingAudioDeletion?) throws {
        guard let pendingDeletion, fileManager.fileExists(atPath: pendingDeletion.stagedURL.path) else { return }
        try ensureStorageDirectoriesExist()

        if fileManager.fileExists(atPath: pendingDeletion.originalURL.path) {
            try fileManager.removeItem(at: pendingDeletion.originalURL)
        }

        try fileManager.moveItem(at: pendingDeletion.stagedURL, to: pendingDeletion.originalURL)
    }

    private func destinationURL(for sourceURL: URL, memoID: UUID) throws -> URL {
        let filename = "\(memoID.uuidString.lowercased()).\(sanitizedExtension(from: sourceURL))"
        return try audioDirectory().appendingPathComponent(filename, isDirectory: false)
    }

    private func relativeAudioPath(for filename: String) -> String {
        "Audio/\(filename)"
    }

    private func durationSeconds(for fileURL: URL) -> Double {
        guard let audioFile = try? AVAudioFile(forReading: fileURL) else {
            return 0
        }

        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        guard duration.isFinite, duration > 0 else {
            return 0
        }
        return duration
    }

    private func sanitizedExtension(from sourceURL: URL) -> String {
        let rawExtension = sourceURL.pathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let filtered = rawExtension.filter { $0.isLetter || $0.isNumber }
        return filtered.isEmpty ? "m4a" : filtered
    }

    private func ensureStorageDirectoriesExist() throws {
        let applicationSupportDirectory = try applicationSupportDirectory()
        if !fileManager.fileExists(atPath: applicationSupportDirectory.path) {
            try fileManager.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
        }

        let audioDirectory = try audioDirectory()
        if !fileManager.fileExists(atPath: audioDirectory.path) {
            try fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        }

        let trashDirectory = try trashDirectory()
        if !fileManager.fileExists(atPath: trashDirectory.path) {
            try fileManager.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
        }
    }

    private func applicationSupportDirectory() throws -> URL {
        if let customApplicationSupportDirectory {
            return customApplicationSupportDirectory
        }

        return try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }

    private func audioDirectory() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent("Audio", isDirectory: true)
    }

    private func trashDirectory() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent("AudioTrash", isDirectory: true)
    }
}

enum DemoAudioFileFactory {
    static func makeTemporaryAudioFile(
        source: MemoSource,
        fileManager: FileManager = .default
    ) throws -> URL {
        let directoryURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let filename: String
        switch source {
        case .recorded:
            filename = "Project Follow-up"
        case .imported:
            filename = "Client Estimate"
        }
        let fileURL = directoryURL
            .appendingPathComponent(filename)
            .appendingPathExtension("wav")

        let durationSeconds = source == .recorded ? 18 : 12
        let sampleRate = 16_000
        let samples = durationSeconds * sampleRate
        let bytesPerSample = 2
        let dataSize = samples * bytesPerSample

        var data = Data()
        data.appendASCII("RIFF")
        data.appendLittleEndian(UInt32(36 + dataSize))
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(sampleRate * bytesPerSample))
        data.appendLittleEndian(UInt16(bytesPerSample))
        data.appendLittleEndian(UInt16(16))
        data.appendASCII("data")
        data.appendLittleEndian(UInt32(dataSize))
        data.append(Data(count: dataSize))

        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { bytes in
            append(contentsOf: bytes)
        }
    }
}
