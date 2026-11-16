import Foundation

/// Saves captured photos into a folder the user picked once in the Files app
/// (e.g. a "Glasses" folder under Google Drive). The Google Drive app then syncs
/// the file to the cloud — no OAuth, no Google Cloud project, no API keys.
///
/// The folder is remembered as a security-scoped bookmark, so the picker is
/// shown only once.
@MainActor
final class DriveFolderStore {

  static let shared = DriveFolderStore()

  private let bookmarkKey = "driveFolderBookmark"

  private init() {}

  /// Display name of the selected folder, or nil if none is selected yet.
  var folderName: String? {
    resolveFolder()?.lastPathComponent
  }

  /// Called with the URL returned by `.fileImporter(allowedContentTypes: [.folder])`.
  func setFolder(_ url: URL) throws {
    guard url.startAccessingSecurityScopedResource() else {
      throw DriveFolderError.accessDenied
    }
    defer { url.stopAccessingSecurityScopedResource() }

    let bookmark = try url.bookmarkData(
      options: [],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
    UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
  }

  /// Writes the JPEG into the selected folder and returns the file name.
  func save(jpeg: Data) throws -> String {
    guard let folder = resolveFolder() else {
      throw DriveFolderError.noFolderSelected
    }
    guard folder.startAccessingSecurityScopedResource() else {
      throw DriveFolderError.accessDenied
    }
    defer { folder.stopAccessingSecurityScopedResource() }

    let fileName = "glasses_\(Self.timestamp()).jpg"
    let target = folder.appendingPathComponent(fileName)

    // NSFileCoordinator is required when writing into a File Provider
    // (Google Drive, iCloud Drive, ...) so the provider picks up the change.
    var coordinatorError: NSError?
    var writeError: Error?
    NSFileCoordinator().coordinate(
      writingItemAt: target, options: .forReplacing, error: &coordinatorError
    ) { url in
      do {
        try jpeg.write(to: url, options: .atomic)
      } catch {
        writeError = error
      }
    }
    if let error = coordinatorError ?? writeError {
      throw error
    }
    return fileName
  }

  private func resolveFolder() -> URL? {
    guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
    var isStale = false
    guard let url = try? URL(
      resolvingBookmarkData: data,
      options: [],
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    ) else { return nil }

    if isStale {
      try? setFolder(url)
    }
    return url
  }

  private static func timestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: Date())
  }
}

enum DriveFolderError: LocalizedError {
  case noFolderSelected
  case accessDenied

  var errorDescription: String? {
    switch self {
    case .noFolderSelected: return "Choose a Google Drive folder first (folder button)."
    case .accessDenied: return "No access to the selected folder. Choose it again."
    }
  }
}
